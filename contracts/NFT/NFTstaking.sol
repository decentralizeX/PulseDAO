// SPDX-License-Identifier: NONE

pragma solidity 0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.0/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/utils/ERC721Holder.sol";

import "../interface/IMasterChef.sol";
import "../interface/IDTX.sol";
import "../interface/IGovernor.sol";
import "../interface/IVoting.sol";
import "../interface/IacPool.sol";

interface INFTallocation {
    function getAllocation(address _tokenAddress, uint256 _tokenID, address _allocationContract) external view returns (uint256);
}

/**
 * DTX NFT staking contract
 * !!! Warning: !!! Licensed under Business Source License 1.1 (BSL 1.1)
 */
contract DTXnftStaking is ReentrancyGuard, ERC721Holder {
    using SafeERC20 for IERC20;

    struct UserInfo {
        address tokenAddress;
        uint256 tokenID;
        uint256 debt; // user debt
        uint256 allocation; //the allocation for the NFT 
		address allocContract; //contract that contains allocation details
    }
    struct UserSettings {
        address pool; //which pool to payout in
        uint256 harvestThreshold;
        uint256 feeToPay;
    }
    struct PoolPayout {
        uint256 amount;
        uint256 minServe;
    }

    IERC20 public immutable token; // DTX token
	
    IERC20 public immutable dummyToken; 

    IMasterChef public masterchef;  

    mapping(address => UserInfo[]) public userInfo;
    mapping(address => UserSettings) public userSettings; 
    mapping(address => PoolPayout) public poolPayout; //determines the percentage received depending on withdrawal option
 
	uint256 public poolID; 
    uint256 public totalAllocation = 10000;
    uint256 public accDtxPerShare;
    address public admin; //admin = governing contract!
    address public treasury; //penalties
    address public allocationContract; // PROXY CONTRACT for looking up allocations

    uint256 public tokenDebt; //sum of allocations of all deposited NFTs

    //if user settings not set, use default
    address public defaultHarvest; //pool address to harvest into
    uint256 public defaultHarvestThreshold = 1000000;
    uint256 public defaultFeeToPay = 250; //fee for calling 2.5% default

    uint256 public defaultDirectPayout = 500; //5% if withdrawn into wallet

    event Deposit(address indexed tokenAddress, uint256 indexed tokenID, address indexed depositor, uint256 shares, uint256 nftAllocation, address allocContract);
    event Withdraw(address indexed sender, uint256 stakeID, address indexed token, uint256 indexed tokenID, uint256 shares, uint256 harvestAmount);
    event UserSettingUpdate(address indexed user, address poolAddress, uint256 threshold, uint256 feeToPay);

    event AddVotingCredit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 _stakeID, address indexed token, uint256 tokenID);
    event Harvest(address indexed harvester, address indexed benficiary, address harvestInto, uint256 harvestAmount, uint256 penalty, uint256 callFee); //harvestAmount contains the callFee
    event SelfHarvest(address indexed user, address harvestInto, uint256 harvestAmount, uint256 penalty);

    /**
     * @notice Constructor
     * @param _token: DTX token contract
     * @param _dummyToken: Dummy token contract
     * @param _masterchef: MasterChef contract
     * @param _admin: address of the admin
     * @param _treasury: address of the treasury (collects fees)
     */
    constructor(
        IERC20 _token,
        IERC20 _dummyToken,
        IMasterChef _masterchef,
        address _admin,
        address _treasury,
        uint256 _poolID,
        address _allocationContract,
		address _longestPool
    ) {
        token = _token;
        dummyToken = _dummyToken;
        masterchef = _masterchef;
        admin = _admin;
        treasury = _treasury;
        poolID = _poolID;
        allocationContract = _allocationContract;
		defaultHarvest = _longestPool;

		
        IERC20(_dummyToken).safeApprove(address(_masterchef), type(uint256).max);
		set pool payouts at launch
		/*
		poolPayout[].amount = 750;
        poolPayout[].minServe = 864000;

        poolPayout[].amount = 1500;
        poolPayout[].minServe = 2592000;

        poolPayout[].amount = 2500;
        poolPayout[].minServe = 5184000;

        poolPayout[].amount = 5000;
        poolPayout[].minServe = 8640000;

        poolPayout[].amount = 7000;
        poolPayout[].minServe = 20736000;

        poolPayout[].amount = 10000;
        poolPayout[].minServe = 31536000; 
		*/
    }
    
    /**
     * @notice Checks if the msg.sender is the admin
     */
    modifier adminOnly() {
        require(msg.sender == admin, "admin: wut?");
        _;
    }
	
    /**
     * Creates a NEW stake
     * allocationContract is the proxy
     * _allocationContract input is the actual contract containing the allocation data
     */
    function deposit(address _tokenAddress, uint256 _tokenID, address _allocationContract) external nonReentrant {
    	uint256 _allocationAmount = INFTallocation(allocationContract).getAllocation(_tokenAddress, _tokenID, _allocationContract);
        require(_allocationAmount > 0, "Invalid NFT, no allocation");
        harvest();
        IERC721(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenID);
		
		uint256 _debt = _allocationAmount * accDtxPerShare / 1e12;
        
        totalAllocation+= _allocationAmount;
        
        userInfo[msg.sender].push(
                UserInfo(_tokenAddress, _tokenID, _debt, _allocationAmount, _allocationContract)
            );

        emit Deposit(_tokenAddress, _tokenID, msg.sender, _debt, _allocationAmount, _allocationContract);
    }

	
    /**
     * Harvests into pool
     */
    function harvest() public {
		uint256 _pending = IMasterChef(masterchef).pendingDtx(poolID, address(this));
        IMasterChef(masterchef).withdraw(poolID, 0);
		accDtxPerShare+= _pending * 1e12  / totalAllocation;
    }
  
    /**
    *
    */
    function setAdmin() external {
        admin = IMasterChef(masterchef).owner();
        treasury = IMasterChef(masterchef).feeAddress();
    }
    
    function updateAllocationContract() external {
        allocationContract = IGovernor(admin).nftAllocationContract();
		poolID = IGovernor(admin).nftStakingPoolID();
    }

    /**
     * @notice Withdraws the NFT and harvests earnings
     */
    function withdraw(uint256 _stakeID, address _harvestInto) public nonReentrant {
        harvest();
        require(_stakeID < userInfo[msg.sender].length, "invalid stake ID");
        UserInfo storage user = userInfo[msg.sender][_stakeID];

		uint256 currentAmount = user.allocation * accDtxPerShare / 1e12 - user.debt;
		
		uint256 _tokenID = user.tokenID;
        address _tokenAddress = user.tokenAddress;
		
		totalAllocation-= user.allocation;
		_removeStake(msg.sender, _stakeID);

        uint256 _toWithdraw;      

        if(_harvestInto == msg.sender) { 
            _toWithdraw = currentAmount * defaultDirectPayout / 10000;
            currentAmount = currentAmount - _toWithdraw;
            token.safeTransfer(msg.sender, _toWithdraw);
         } else {
            require(poolPayout[_harvestInto].amount != 0, "incorrect pool!");
            _toWithdraw = currentAmount * poolPayout[_harvestInto].amount / 10000;
            currentAmount = currentAmount - _toWithdraw;
            IacPool(_harvestInto).giftDeposit(_toWithdraw, msg.sender, poolPayout[_harvestInto].minServe);
        }
        token.safeTransfer(treasury, currentAmount); //penalty goes to governing contract

		emit Withdraw(msg.sender, _stakeID, _tokenAddress, _tokenID, _toWithdraw, currentAmount);

        IERC721(_tokenAddress).safeTransferFrom(address(this), msg.sender, _tokenID); //withdraw NFT
    }  

    function setUserSettings(uint256 _harvestThreshold, uint256 _feeToPay, address _harvestInto) external {
        require(_feeToPay <= 250, "max 2.5%");
        if(_harvestInto != msg.sender) { require(poolPayout[_harvestInto].amount != 0, "incorrect pool!"); }
        UserSettings storage _setting = userSettings[msg.sender];
        _setting.harvestThreshold = _harvestThreshold;
        _setting.feeToPay = _feeToPay;
        _setting.pool = _harvestInto; //default pool to harvest into(or payout directly)
        emit UserSettingUpdate(msg.sender, _harvestInto, _harvestThreshold, _feeToPay);
    }

    //harvest own earnings
    function selfHarvest(address _harvestInto) external nonReentrant {
        UserInfo[] storage user = userInfo[msg.sender];
		require(user.length > 0, "user has no stakes");
        harvest();
        uint256 _totalWithdraw = 0;
        uint256 _toWithdraw = 0;
        uint256 _payout = 0;
 
        for(uint256 i = 0; i<user.length; i++) {
            _toWithdraw = user[i].allocation * accDtxPerShare / 1e12 - user[i].debt;
            user[i].debt = user[i].allocation * accDtxPerShare / 1e12;
            _totalWithdraw+= _toWithdraw;
        }

        if(_harvestInto == msg.sender) {
            _payout = _totalWithdraw * defaultDirectPayout / 10000;
            token.safeTransfer(msg.sender, _payout); 
        } else {
            require(poolPayout[_harvestInto].amount != 0, "incorrect pool!");
            _payout = _totalWithdraw * poolPayout[_harvestInto].amount / 10000;
            IacPool(_harvestInto).giftDeposit(_payout, msg.sender, poolPayout[_harvestInto].minServe);
        }
        uint256 _penalty = _totalWithdraw - _payout;
        token.safeTransfer(treasury, _penalty); //penalty to treasury

        emit SelfHarvest(msg.sender, _harvestInto, _payout, _penalty);
    }


    //harvest earnings of another user(receive fees)
    function proxyHarvest(address _beneficiary) external {
        UserInfo[] storage user = userInfo[_beneficiary];
		require(user.length > 0, "user has no stakes");
        harvest();
        uint256 _totalWithdraw = 0;
        uint256 _toWithdraw = 0;
        uint256 _payout = 0;

        UserSettings storage _userSetting = userSettings[_beneficiary];

        address _harvestInto = _userSetting.pool;
        uint256 _minThreshold = _userSetting.harvestThreshold;
        uint256 _callFee = _userSetting.feeToPay;

        if(_minThreshold == 0) { _minThreshold = defaultHarvestThreshold; }
        if(_callFee == 0) { _callFee = defaultFeeToPay; }

        for(uint256 i = 0; i<user.length; i++) {
            _toWithdraw = user[i].allocation * accDtxPerShare / 1e12 - user[i].debt;
            user[i].debt = user[i].allocation * accDtxPerShare / 1e12;
            _totalWithdraw+= _toWithdraw;
        }

        if(_harvestInto == _beneficiary) {
            //fee paid to harvester
            _payout = _toWithdraw * defaultDirectPayout / 10000;
            _callFee = _payout * _callFee / 10000;
            token.safeTransfer(msg.sender, _callFee); 
            token.safeTransfer(_beneficiary, (_payout - _callFee)); 
        } else {
            if(_harvestInto == address(0)) {
                _harvestInto = defaultHarvest; //default pool
            } //harvest Into is correct(checks if valid when user initiates the setting)
            _payout = _toWithdraw * poolPayout[_harvestInto].amount / 10000;
            require(_payout > _minThreshold, "minimum threshold not met");
            _callFee = _payout * _callFee / 10000;
            token.safeTransfer(msg.sender, _callFee); 
            IacPool(_harvestInto).giftDeposit((_payout - _callFee), _beneficiary, poolPayout[_harvestInto].minServe);
        }
        uint256 _penalty = _toWithdraw - _payout;
        token.safeTransfer(treasury, _penalty); //penalty to treasury

        emit Harvest(msg.sender, _beneficiary, _harvestInto, _payout, _penalty, _callFee);
    }

	//copy+paste of the previous function, can harvest custom stake ID
	//In case user has too many stakes, or if some are not worth harvesting
	function proxyHarvestCustom(address _beneficiary, uint256[] calldata _stakeID) public {
        require(_stakeID.length <= userInfo[_beneficiary].length, "incorrect Stake list");
        UserInfo[] storage user = userInfo[_beneficiary];
        harvest();
        uint256 _totalWithdraw = 0;
        uint256 _toWithdraw = 0;
        uint256 _payout = 0;

        UserSettings storage _userSetting = userSettings[_beneficiary];

        address _harvestInto = _userSetting.pool;
        uint256 _minThreshold = _userSetting.harvestThreshold;
        uint256 _callFee = _userSetting.feeToPay;

        if(_minThreshold == 0) { _minThreshold = defaultHarvestThreshold; }
        if(_callFee == 0) { _callFee = defaultFeeToPay; }

        for(uint256 i = 0; i<_stakeID.length; i++) {
            _toWithdraw = user[_stakeID[i]].allocation * accDtxPerShare / 1e12 - user[_stakeID[i]].debt;
            user[_stakeID[i]].debt = user[_stakeID[i]].allocation * accDtxPerShare / 1e12;
            _totalWithdraw+= _toWithdraw;
        }

        if(_harvestInto == _beneficiary) {
            _payout = _toWithdraw * defaultDirectPayout / 10000;
            _callFee = _payout * _callFee / 10000;
            token.safeTransfer(msg.sender, _callFee); 
            token.safeTransfer(_beneficiary, (_payout - _callFee)); 
        } else {
            if(_harvestInto == address(0)) {
                _harvestInto = defaultHarvest; //default pool
            } 
            _payout = _toWithdraw * poolPayout[_harvestInto].amount / 10000;
            require(_payout > _minThreshold, "minimum threshold not met");
            _callFee = _payout * _callFee / 10000;
            token.safeTransfer(msg.sender, _callFee); 
            IacPool(_harvestInto).giftDeposit((_payout - _callFee), _beneficiary, poolPayout[_harvestInto].minServe);
        }
        uint256 _penalty = _toWithdraw - _payout;
        token.safeTransfer(treasury, _penalty); //penalty to treasury
        
        emit Harvest(msg.sender, _beneficiary, _harvestInto, _payout, _penalty, _callFee);
    }
	
	function massHarvest(address[] calldata beneficiary, uint256[][] calldata stakeID) external {
        for(uint256 i=0; i<beneficiary.length; i++) {
            proxyHarvestCustom(beneficiary[i], stakeID[i]);
        }
    }
	
    function viewStakeEarnings(address _user, uint256 _stakeID) external view returns (uint256) {
		UserInfo storage _stake = userInfo[_user][_stakeID];
        uint256 _pending = _stake.allocation * virtualAccDtxPerShare() / 1e12 - _stake.debt;
        return _pending;
    }

    function viewUserTotalEarnings(address _user) external view returns (uint256) {
        UserInfo[] storage _stake = userInfo[_user];
        uint256 nrOfUserStakes = _stake.length;

		uint256 _totalPending = 0;
		
		for(uint256 i=0; i < nrOfUserStakes; i++) {
			_totalPending+= _stake[i].allocation * virtualAccDtxPerShare() / 1e12 - _stake[i].debt;
		}
		
		return _totalPending;
    }
	//we want user deposit, we want total deposited, we want pending rewards, 
	function multiCall(address _user, uint256 _stakeID) external view returns(uint256, uint256, uint256, address, uint256) {
		UserInfo storage user = userInfo[_user][_stakeID];
		uint256 _pending = user.allocation * virtualAccDtxPerShare() / 1e12 - user.debt;
		return(user.allocation, totalAllocation, _pending, user.tokenAddress, user.tokenID);
	}
	

    // if allocation for the NFT changes, anyone can rebalance
	// if allocation contract is replaced(rare event), an "evil" third party can push the NFT out of the staking
	// responsibility of the owner to re-deposit (or rebalance first)
    function rebalanceNFT(address _staker, uint256 _stakeID, bool isAllocationContractReplaced, address _allocationContract) external {
		require(_stakeID < userInfo[_staker].length, "invalid stake ID");
		harvest();
        UserInfo storage user = userInfo[_staker][_stakeID];
		uint256 _alloc;
		if(isAllocationContractReplaced) {
			require(user.allocContract != _allocationContract, "must set allocation replaced setting as FALSE");
			_alloc = INFTallocation(allocationContract).getAllocation(user.tokenAddress, user.tokenID, _allocationContract);
			require(_alloc != 0, "incorrect _allocationContract");
		} else {
			_alloc = INFTallocation(allocationContract).getAllocation(user.tokenAddress, user.tokenID, user.allocContract);
		}
        if(_alloc == 0) { //no longer valid, anyone can push out and withdraw NFT to the owner (copy+paste withdraw option) 
            uint256 currentAmount = user.allocation * accDtxPerShare / 1e12 - user.debt;
            totalAllocation-= user.allocation;

            uint256 _tokenID = user.tokenID;
			address _tokenAddress = user.tokenAddress;

            emit Withdraw(_staker, _stakeID, user.tokenAddress, _tokenID, user.allocation, currentAmount);
            
            _removeStake(_staker, _stakeID); //delete the stake

            address _harvestInto = userSettings[_staker].pool;
            if(_harvestInto == address(0)) { _harvestInto = defaultHarvest; } 

            uint256 _toWithdraw;      
            if(_harvestInto == _staker) { 
                _toWithdraw = currentAmount * defaultDirectPayout / 10000;
                currentAmount = currentAmount - _toWithdraw;
                token.safeTransfer(_staker, _toWithdraw);
            } else {
                _toWithdraw = currentAmount * poolPayout[_harvestInto].amount / 10000;
				if(_toWithdraw > IacPool(_harvestInto).minimumGift()) {
					currentAmount = currentAmount - _toWithdraw;
					IacPool(_harvestInto).giftDeposit(_toWithdraw, _staker, poolPayout[_harvestInto].minServe);
				}
            }
            token.safeTransfer(treasury, currentAmount); //penalty goes to governing contract

            IERC721(_tokenAddress).safeTransferFrom(address(this), _staker, _tokenID); //withdraw NFT
        } else if(_alloc != user.allocation) { //change allocation
            uint256 _profit = user.allocation * accDtxPerShare / 1e12 - user.debt;
            user.debt = user.debt - _profit; //debt reduces by user earnings(amount available for harvest)
			totalAllocation = totalAllocation - user.allocation + _alloc; // minus previous, plus new
            user.allocation = _alloc;
        }
    }
	
	// Adding virtual harvest for the external viewing
	function virtualAccDtxPerShare() public view returns (uint256) {
		uint256 _pending = IMasterChef(masterchef).pendingDtx(poolID, address(this));
		return (accDtxPerShare + _pending * 1e12  / totalAllocation);
	}
	
	// emergency withdraw, without caring about rewards
	function emergencyWithdraw(uint256 _stakeID) public {
		require(_stakeID < userInfo[msg.sender].length, "invalid stake ID");
		UserInfo storage user = userInfo[msg.sender][_stakeID];
		totalAllocation-= user.allocation;
		address _token = user.tokenAddress;
		uint256 _tokenID = user.tokenID;
		
		_removeStake(msg.sender, _stakeID); //delete the stake
        emit EmergencyWithdraw(msg.sender, _stakeID, _token, _tokenID);
		IERC721(_token).safeTransferFrom(address(this), msg.sender, _tokenID); //withdraw NFT
	}
	// withdraw all without caring about rewards
	// self-harvest to harvest rewards, then emergency withdraw all(easiest to withdraw all+earnings)
	// (non-rentrant in regular withdraw)
	function emergencyWithdrawAll() external {
		uint256 _stakeID = userInfo[msg.sender].length;
		while(_stakeID > 0) {
			_stakeID--;
			emergencyWithdraw(_stakeID);
		}
	}

    //need to set pools before launch or perhaps during contract launch
    //determines the payout depending on the pool. could set a governance process for it(determining amounts for pools)
	//allocation contract contains the decentralized proccess for updating setting, but so does the admin(governor)
    function setPoolPayout(address _poolAddress, uint256 _amount, uint256 _minServe) external {
        require(msg.sender == allocationContract || msg.sender == admin, "must be set by allocation contract or admin");
		if(_poolAddress == address(0)) {
			require(_amount <= 10000, "out of range");
			defaultDirectPayout = _amount;
		} else if (_poolAddress == address(1)) {
			defaultHarvestThreshold = _amount;
		} else if (_poolAddress == address(2)) {
			require(_amount <= 1000, "out of range"); //max 10%
			defaultFeeToPay = _amount;
		} else {
			require(_amount <= 10000, "out of range"); 
			poolPayout[_poolAddress].amount = _amount;
        	poolPayout[_poolAddress].minServe = _minServe; //mandatory lockup(else stake for 5yr, withdraw with 82% penalty and receive 18%)
		}
    }
    
    function updateSettings(address _defaultHarvest, uint256 _threshold, uint256 _defaultFee, uint256 _defaultDirectHarvest) external adminOnly {
        defaultHarvest = _defaultHarvest; //longest pool should be the default
        defaultHarvestThreshold = _threshold;
        defaultFeeToPay = _defaultFee;
        defaultDirectPayout = _defaultDirectHarvest;
    }

    /**
     * Returns number of stakes for a user
     */
    function getNrOfStakes(address _user) public view returns (uint256) {
        return userInfo[_user].length;
    }
	

    /**
     * @return Returns total pending DTX rewards
     */
    function calculateTotalPendingDTXRewards() external view returns (uint256) {
        return(IMasterChef(masterchef).pendingDtx(poolID, address(this)));
    }

	
    /**
     * calculates pending rewards + balance of tokens in this address + artificial token debt(how much each NFT is worth)
	 * we harvest before every action, pending rewards not needed
     */
    function balanceOf() internal view returns (uint256) {
        return token.balanceOf(address(this)) + tokenDebt; 
    }
	//public lookup for UI
    function publicBalanceOf() public view returns (uint256) {
        uint256 amount = IMasterChef(masterchef).pendingDtx(poolID, address(this)); 
        return token.balanceOf(address(this)) + amount + tokenDebt; 
    }
	
	/*
	 * Unlikely, but Masterchef can be changed if needed to be used without changing pools
	 * masterchef = IMasterChef(token.owner());
	 * Must stop earning first(withdraw tokens from old chef)
	*/
	function setMasterChefAddress(IMasterChef _masterchef, uint256 _newPoolID) external adminOnly {
		masterchef = _masterchef;
		poolID = _newPoolID; //in case pool ID changes
		
		uint256 _dummyAllowance = IERC20(dummyToken).allowance(address(this), address(masterchef));
		if(_dummyAllowance == 0) {
			IERC20(dummyToken).safeApprove(address(_masterchef), type(uint256).max);
		}
	}
	
    /**
     * When contract is launched, dummyToken shall be deposited to start earning rewards
     */
    function startEarning() external adminOnly {
		IMasterChef(masterchef).deposit(poolID, dummyToken.balanceOf(address(this)));
    }
	
    /**
     * Dummy token can be withdrawn if ever needed(allows for flexibility)
     */
	function stopEarning(uint256 _withdrawAmount) external adminOnly {
		if(_withdrawAmount == 0) { 
			IMasterChef(masterchef).withdraw(poolID, dummyToken.balanceOf(address(masterchef)));
		} else {
			IMasterChef(masterchef).withdraw(poolID, _withdrawAmount);
		}
	}
	
    /**
     * Withdraws dummyToken to owner(who can burn it if needed)
     */
    function withdrawDummy(uint256 _amount) external adminOnly {	
        if(_amount == 0) { 
			dummyToken.safeTransfer(admin, dummyToken.balanceOf(address(this)));
		} else {
			dummyToken.safeTransfer(admin, _amount);
		}
    }
	
	
	/**
	 * option to withdraw wrongfully sent tokens(but requires change of the governing contract to do so)
	 * If you send wrong tokens to the contract address, consider them lost. Though there is possibility of recovery
	 */
	function withdrawStuckTokens(address _tokenAddress) external adminOnly {
		require(_tokenAddress != address(token), "wrong token");
		require(_tokenAddress != address(dummyToken), "wrong token");
		
		IERC20(_tokenAddress).safeTransfer(IGovernor(admin).treasuryWallet(), IERC20(_tokenAddress).balanceOf(address(this)));
	}

    
    /**
     * removes the stake
     */
    function _removeStake(address _staker, uint256 _stakeID) private {
        UserInfo[] storage stakes = userInfo[_staker];
        uint256 lastStakeID = stakes.length - 1;
        
        if(_stakeID != lastStakeID) {
            stakes[_stakeID] = stakes[lastStakeID];
        }
        
        stakes.pop();
    }
}
