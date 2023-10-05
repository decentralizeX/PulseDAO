// SPDX-License-Identifier: NONE

pragma solidity 0.8.20;

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
 * XPD NFT Mining contract
 */
contract XPDnftMining is ReentrancyGuard, ERC721Holder {
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

    IERC20 public immutable token; // XPD token

    IMasterChef public masterchef;  

    mapping(address => UserInfo[]) public userInfo;
    mapping(address => PoolPayout) public poolPayout; //determines the percentage received depending on withdrawal option
 
	uint256 public poolID = 11; 
    uint256 public totalAllocation = 10000;
    uint256 public accDtxPerShare;
    address public admin; //admin = governing contract!
    address public treasury; //penalties
    address public allocationContract; // PROXY CONTRACT for looking up allocations

    uint256 public tokenDebt; //sum of allocations of all deposited NFTs

	uint256 public lastCredit; // Keep track of our latest credit score from masterchef

    uint256 public defaultDirectPayout = 50; //0.5% if withdrawn into wallet

    event Deposit(address indexed tokenAddress, uint256 indexed tokenID, address indexed depositor, uint256 shares, uint256 nftAllocation, address allocContract);
    event Withdraw(address indexed sender, uint256 stakeID, address indexed token, uint256 indexed tokenID, uint256 shares, uint256 harvestAmount);
    event UserSettingUpdate(address indexed user, address poolAddress, uint256 threshold, uint256 feeToPay);

    event AddVotingCredit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 _stakeID, address indexed token, uint256 tokenID);
    event SelfHarvest(address indexed user, address harvestInto, uint256 harvestAmount, uint256 penalty);

    constructor(
        IERC20 _token,
        IMasterChef _masterchef,
        address _allocationContract
    ) {
        token = _token;
        admin = msg.sender;
		masterchef = _masterchef;
        allocationContract = _allocationContract;

		
		poolPayout[].amount = 100;
        poolPayout[].minServe = 864000;

        poolPayout[].amount = 300;
        poolPayout[].minServe = 2592000;

        poolPayout[].amount = 500;
        poolPayout[].minServe = 5184000;

        poolPayout[].amount = 1000;
        poolPayout[].minServe = 8640000;

        poolPayout[].amount = 2500;
        poolPayout[].minServe = 20736000;

        poolPayout[].amount = 10000;
        poolPayout[].minServe = 31536000; 
    }
    
    /**
     * @notice Checks if the msg.sender is the admin
     */
    modifier decentralizedVoting() {
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
		IMasterChef(masterchef).updatePool(poolID);
		uint256 _currentCredit = IMasterChef(masterchef).credit(address(this));
		uint256 _accumulatedRewards = lastCredit - _currentCredit;
		lastCredit = _currentCredit;
		accDtxPerShare+= _accumulatedRewards * 1e12  / totalAllocation;
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
            IMasterChef(masterchef).publishTokens(msg.sender, _toWithdraw);
         } else {
            require(poolPayout[_harvestInto].amount != 0, "incorrect pool!");
            _toWithdraw = currentAmount * poolPayout[_harvestInto].amount / 10000;
            currentAmount = currentAmount - _toWithdraw;
			IMasterChef(masterchef).publishTokens(address(this), _toWithdraw);
            IacPool(_harvestInto).giftDeposit(_toWithdraw, msg.sender, poolPayout[_harvestInto].minServe);
        }
        IMasterChef(masterchef).publishTokens(treasury, currentAmount); //penalty goes to governing contract

		lastCredit = lastCredit - (_toWithdraw + currentAmount);

		emit Withdraw(msg.sender, _stakeID, _tokenAddress, _tokenID, _toWithdraw, currentAmount);

        IERC721(_tokenAddress).safeTransferFrom(address(this), msg.sender, _tokenID); //withdraw NFT
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
            IMasterChef(masterchef).publishTokens(msg.sender, _payout); 
        } else {
            require(poolPayout[_harvestInto].amount != 0, "incorrect pool!");
            _payout = _totalWithdraw * poolPayout[_harvestInto].amount / 10000;
			IMasterChef(masterchef).publishTokens(address(this), _payout);
            IacPool(_harvestInto).giftDeposit(_payout, msg.sender, poolPayout[_harvestInto].minServe);
        }
        uint256 _penalty = _totalWithdraw - _payout;
        IMasterChef(masterchef).publishTokens(treasury, _penalty); //penalty to treasury

		lastCredit = lastCredit - (_payout + _penalty);

        emit SelfHarvest(msg.sender, _harvestInto, _payout, _penalty);
    }


    function selfHarvestCustom(address _harvestInto, uint256[] memory _stakeID) external nonReentrant {
        UserInfo[] storage user = userInfo[msg.sender];
		require(user.length > 0, "user has no stakes");
        harvest();
        uint256 _totalWithdraw = 0;
        uint256 _toWithdraw = 0;
        uint256 _payout = 0;
 
        for(uint256 i = 0; i<_stakeID.length; i++) {
            _toWithdraw = user[_stakeID[i]].allocation * accDtxPerShare / 1e12 - user[_stakeID[i]].debt;
            user[_stakeID[i]].debt = user[_stakeID[i]].allocation * accDtxPerShare / 1e12;
            _totalWithdraw+= _toWithdraw;
        }

        if(_harvestInto == msg.sender) {
            _payout = _totalWithdraw * defaultDirectPayout / 10000;
            IMasterChef(masterchef).publishTokens(msg.sender, _payout); 
        } else {
            require(poolPayout[_harvestInto].amount != 0, "incorrect pool!");
            _payout = _totalWithdraw * poolPayout[_harvestInto].amount / 10000;
			IMasterChef(masterchef).publishTokens(address(this), _payout);
            IacPool(_harvestInto).giftDeposit(_payout, msg.sender, poolPayout[_harvestInto].minServe);
        }
        uint256 _penalty = _totalWithdraw - _payout;
        IMasterChef(masterchef).publishTokens(treasury, _penalty); //penalty to treasury

        emit SelfHarvest(msg.sender, _harvestInto, _payout, _penalty);
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
        if(_alloc == 0) { //no longer valid, anyone can push out and withdraw NFT to the owner (copy+paste withdraw option). If owner doesn't take action, rewards are lost
            uint256 currentAmount = user.allocation * accDtxPerShare / 1e12 - user.debt;
            totalAllocation-= user.allocation;

            uint256 _tokenID = user.tokenID;
			address _tokenAddress = user.tokenAddress;

            emit Withdraw(_staker, _stakeID, user.tokenAddress, _tokenID, user.allocation, currentAmount);
            
            _removeStake(_staker, _stakeID); //delete the stake

            IMasterChef(masterchef).publishTokens(treasury, currentAmount); //penalty goes to governing contract

            IERC721(_tokenAddress).safeTransferFrom(address(this), _staker, _tokenID); //withdraw NFT
        } else if(_alloc != user.allocation) { //change allocation
            uint256 _profit = user.allocation * accDtxPerShare / 1e12 - user.debt;
            user.debt = user.debt - _profit; //debt reduces by user earnings(amount available for harvest)
			totalAllocation = totalAllocation - user.allocation + _alloc; // minus previous, plus new
            user.allocation = _alloc;
        }
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
		require(_amount <= 10000, "out of range"); 
		poolPayout[_poolAddress].amount = _amount;
		poolPayout[_poolAddress].minServe = _minServe; //mandatory lockup(else stake for 5yr, withdraw with 82% penalty and receive 18%)
    }
    
    function updateSettings(uint256 _defaultDirectPayout) external decentralizedVoting {
        defaultDirectPayout = _defaultDirectPayout;
    }
	
	/*
	 * Unlikely, but Masterchef can be changed if needed to be used without changing pools
	 * masterchef = IMasterChef(token.owner());
	 * Must stop earning first(withdraw tokens from old chef)
	*/
	function setMasterChefAddress(IMasterChef _masterchef, uint256 _newPoolID) external decentralizedVoting {
		masterchef = _masterchef;
		poolID = _newPoolID; //in case pool ID changes
	}
	
	
	/**
	 * option to withdraw wrongfully sent tokens(but requires change of the governing contract to do so)
	 * If you send wrong tokens to the contract address, consider them lost. Though there is possibility of recovery
	 */
	function withdrawStuckTokens(address _tokenAddress) external decentralizedVoting {
		require(_tokenAddress != address(token), "wrong token");
		
		IERC20(_tokenAddress).safeTransfer(IGovernor(admin).treasuryWallet(), IERC20(_tokenAddress).balanceOf(address(this)));
	}

	// Adding virtual harvest for the external viewing
	function virtualaccDtxPerShare() public view returns (uint256) {
		uint256 _pending = IMasterChef(masterchef).pendingDtx(poolID);
		return (accDtxPerShare + _pending * 1e12  / totalAllocation);
	}

	function viewStakeEarnings(address _user, uint256 _stakeID) external view returns (uint256) {
		UserInfo storage _stake = userInfo[_user][_stakeID];
        uint256 _pending = _stake.allocation * virtualaccDtxPerShare() / 1e12 - _stake.debt;
        return _pending;
    }

    function viewUserTotalEarnings(address _user) external view returns (uint256) {
        UserInfo[] storage _stake = userInfo[_user];
        uint256 nrOfUserStakes = _stake.length;

		uint256 _totalPending = 0;
		
		for(uint256 i=0; i < nrOfUserStakes; i++) {
			_totalPending+= _stake[i].allocation * virtualaccDtxPerShare() / 1e12 - _stake[i].debt;
		}
		
		return _totalPending;
    }
	//we want user deposit, we want total deposited, we want pending rewards, 
	function multiCall(address _user, uint256 _stakeID) external view returns(uint256, uint256, uint256, address, uint256) {
		UserInfo storage user = userInfo[_user][_stakeID];
		uint256 _pending = user.allocation * virtualaccDtxPerShare() / 1e12 - user.debt;
		return(user.allocation, totalAllocation, _pending, user.tokenAddress, user.tokenID);
	}
	

    /**
     * @return Returns total pending XPD rewards
     */
    function calculateTotalpendingDtxRewards() external view returns (uint256) {
        return(IMasterChef(masterchef).pendingDtx(poolID));
    }

	/**
     * Returns number of stakes for a user
     */
    function getNrOfStakes(address _user) public view returns (uint256) {
        return userInfo[_user].length;
    }

	
	//public lookup for UI
    function publicBalanceOf() public view returns (uint256) {
        uint256 amount = IMasterChef(masterchef).pendingDtx(poolID); 
        return token.balanceOf(address(this)) + amount; 
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
