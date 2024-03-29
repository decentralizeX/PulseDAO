// SPDX-License-Identifier: NONE

pragma solidity 0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.0/contracts/security/ReentrancyGuard.sol";


import "../interface/IGovernor.sol";
import "../interface/IMasterChef.sol";
import "../interface/IacPool.sol";

interface ILookup {
	function stakeCount(address _staker) external view returns (uint256);
	function stakeLists(address, uint256) external view returns (uint40,uint72,uint72,uint16,uint16,uint16,bool);
}

/**
 * tshare Vault
 */
contract tshareVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
		uint256 debt;
		uint256 lastAction;
    }

    struct PoolPayout {
        uint256 amount;
        uint256 minServe;
    }
	
    IERC20 public immutable token; // DTX token
	
	ILookup public immutable hexC = ILookup(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39);

    IMasterChef public masterchef;  

    mapping(address => UserInfo) public userInfo;
    mapping(address => PoolPayout) public poolPayout; //determines the percentage received depending on withdrawal option

	// Referral system: Track referrer + referral points
	mapping(address => address) public referredBy;
	mapping(address => uint256) public referralPoints;

	uint256 public safePeriod = 12 hours;
	uint256 public poolID; 
	uint256 public accDtxPerShare;
    address public treasury; //penalties
	uint256 public totalTshares = 1e8; // Negligible share to avoid division by 0 on first deposit. 

	uint256 public lastCredit; // Keep track of our latest credit score from masterchef
	
	uint256 public maxStakes = 150;

    uint256 public defaultDirectPayout = 50; //0.5% if withdrawn into wallet
	

    event Deposit(address indexed sender, uint256 amount, uint256 debt, address indexed referredBy);
    event Withdraw(address indexed sender, uint256 harvestAmount, uint256 penalty);

    event Harvest(address indexed user, address indexed harvestInto, uint256 harvestAmount, uint256 penalty);

    /**
     * @notice Constructor
     * @param _token: DTX token contract
     * @param _masterchef: MasterChef contract
     */
    constructor(
        IERC20 _token,
        IMasterChef _masterchef
    ) {
        token = _token;
        masterchef = _masterchef;
        poolID = 10;
	
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
        require(msg.sender == IMasterChef(masterchef).owner(), "admin: wut?");
        _;
    }

	
    /**
     * Creates a NEW stake
	 * threshold is the amount to allow another user to harvest 
	 * fee is the amount paid to harvester
     */
    function stakeHexShares(address _referral) external nonReentrant {
		address _userAddress = msg.sender;
		UserInfo storage user = userInfo[_userAddress];
		require(user.amount == 0, "already have an active stake!");
        harvest();

		if(referredBy[_userAddress] == address(0) && _referral != _userAddress) {
			referredBy[_userAddress] = _referral;
		}
		
		uint256 nrOfStakes = hexC.stakeCount(_userAddress);
		require(nrOfStakes > 0, "no stakes");
		uint256 _shares;
        uint256 _amount = 0;

		if(nrOfStakes > maxStakes) { nrOfStakes = maxStakes; }
		for(uint256 i=0; i<nrOfStakes; ++i) {
			(, , _shares, , , ,) = hexC.stakeLists(_userAddress, i);
			_amount+= _shares;
		}
		uint256 _debt = _amount * accDtxPerShare / 1e12;
		totalTshares+= _amount;
        
		user.amount = _amount;
		user.debt = _debt;
		user.lastAction = block.timestamp;

        emit Deposit(_userAddress, _amount, _debt, _referral);
    }
	
    /**
     * Harvests into pool
     */
    function harvest() public {
		IMasterChef(masterchef).updatePool(poolID);
		uint256 _currentCredit = IMasterChef(masterchef).credit(address(this));
		uint256 _accumulatedRewards = _currentCredit - lastCredit;
		lastCredit = _currentCredit;
		accDtxPerShare+= _accumulatedRewards * 1e12  / totalTshares;
    }

    /**
    *
    */
    function updateTreasury() external {
        treasury = IMasterChef(masterchef).feeAddress();
    }

    /**
     * Withdraws all tokens
     */
    function withdraw(address _harvestInto) public nonReentrant {
        harvest();
        UserInfo storage user = userInfo[msg.sender];
		require(user.lastAction + safePeriod < block.timestamp, "You must wait a SAFE PERIOD of 12hours before withdrawing!");
		uint256 userTokens = user.amount; 
		require(userTokens > 0, "no active stake");

		uint256 currentAmount = userTokens * accDtxPerShare / 1e12 - user.debt;
		totalTshares-= userTokens;
		
		user.amount = 0;
		user.debt = 0;

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

		if(referredBy[msg.sender] != address(0)) {
			referralPoints[msg.sender]+= _toWithdraw;
			referralPoints[referredBy[msg.sender]]+= _toWithdraw;
		}

		if(currentAmount > 0) {
        	IMasterChef(masterchef).publishTokens(treasury, currentAmount); //penalty goes to governing contract
		}

		lastCredit = lastCredit - (_toWithdraw + currentAmount);
		
		emit Withdraw(msg.sender, _toWithdraw, currentAmount);
    } 



	//copy+paste of the previous function, can harvest custom stake ID
	//In case user has too many stakes, or if some are not worth harvesting
	function selfHarvest(address _harvestInto) external {
        UserInfo storage user = userInfo[msg.sender];
		require(user.lastAction + safePeriod < block.timestamp, "You must wait a SAFE PERIOD of 12hours before withdrawing!");
		require(user.amount > 0, "no shares");
        harvest();
        uint256 _toWithdraw = 0;
        uint256 _payout = 0;

		_toWithdraw = user.amount * accDtxPerShare / 1e12 - user.debt;
		user.debt = user.amount * accDtxPerShare / 1e12;
		
		if(_harvestInto == msg.sender) {
		_payout = _toWithdraw * defaultDirectPayout / 10000;
		IMasterChef(masterchef).publishTokens(msg.sender, _payout); 
		} else {
			require(poolPayout[_harvestInto].amount != 0, "incorrect pool!");
			_payout = _toWithdraw * poolPayout[_harvestInto].amount / 10000;
			IMasterChef(masterchef).publishTokens(address(this), _payout);
			IacPool(_harvestInto).giftDeposit(_payout, msg.sender, poolPayout[_harvestInto].minServe);
		}

		if(referredBy[msg.sender] != address(0)) {
			referralPoints[msg.sender]+= _payout;
			referralPoints[referredBy[msg.sender]]+= _payout;
		}

		uint256 _penalty = _toWithdraw - _payout;
		if(_penalty > 0) {
			IMasterChef(masterchef).publishTokens(treasury, _penalty); //penalty to treasury
		}

		lastCredit = lastCredit - (_payout + _penalty);

		emit Harvest(msg.sender, _harvestInto, _payout, _penalty);      
    }
	
	function recalculate(address _user) public {
		harvest();
		uint256 nrOfStakes = hexC.stakeCount(_user);
		if(nrOfStakes > maxStakes) { nrOfStakes = maxStakes; }
		uint256 _amount = 0; //total shares for user
        uint256 _shares;
		for(uint256 i=0; i<nrOfStakes; ++i) {
			(, , _shares, , , ,) = hexC.stakeLists(msg.sender, i);
			_amount+= _shares;
		}
		UserInfo storage user = userInfo[_user];
		if(user.amount != _amount) {
			user.lastAction = block.timestamp;
			uint256 _current = user.amount * accDtxPerShare / 1e12;
            uint256 _profit = _current - user.debt;
			user.debt = _current - _profit; //debt reduces by user earnings(amount available for harvest)
			totalTshares = totalTshares - user.amount + _amount; // minus previous, plus new
			user.amount = _amount;
		}
	}

	function massRecalculate(address[] calldata _user) external {
		for(uint256 i=0; i<_user.length; ++i) {
			recalculate(_user[i]);
		}
	}

    //need to set pools before launch or perhaps during contract launch
    //determines the payout depending on the pool. could set a governance process for it(determining amounts for pools)
	//allocation contract contains the decentralized proccess for updating setting, but so does the admin(governor)
    function setPoolPayout(address _poolAddress, uint256 _amount, uint256 _minServe) external decentralizedVoting {
		require(_amount <= 10000, "out of range"); 
		poolPayout[_poolAddress].amount = _amount;
	poolPayout[_poolAddress].minServe = _minServe; //mandatory lockup(else stake for 5yr, withdraw with 82% penalty and receive 18%)
    }
    
    function updateSettings(uint256 _defaultDirectHarvest) external decentralizedVoting {
		require(_defaultDirectHarvest <= 10_000, "cant exceed 100%");
        defaultDirectPayout = _defaultDirectHarvest;
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
	
	// tx can run out of gas. Only calculates shares based on the first (maxStakes) number of stakes
	function setMaxStakes(uint256 _amount) external decentralizedVoting {
		maxStakes = _amount;
	}

	function setSafePeriod(uint256 _amount) external decentralizedVoting {
		safePeriod = _amount;
	}
	
	/**
	 * option to withdraw wrongfully sent tokens(but requires change of the governing contract to do so)
	 * If you send wrong tokens to the contract address, consider them lost. Though there is possibility of recovery
	 */
	function withdrawStuckTokens(address _tokenAddress) external {
		require(_tokenAddress != address(token), "illegal token");
		
		IERC20(_tokenAddress).safeTransfer(IGovernor(IMasterChef(masterchef).owner()).treasuryWallet(), IERC20(_tokenAddress).balanceOf(address(this)));
	}

	function viewStakeEarnings(address _user) external view returns (uint256) {
		UserInfo storage _stake = userInfo[_user];
        uint256 _pending = _stake.amount * virtualAccDtxPerShare() / 1e12 - _stake.debt;
        return _pending;
    }

	//we want user deposit, we want total deposited, we want pending rewards, 
	function multiCall(address _user) external view returns(uint256, uint256, uint256, uint256) {
		UserInfo storage user = userInfo[_user];
		uint256 _pending = user.amount * virtualAccDtxPerShare() / 1e12 - user.debt;
		return(user.amount, totalTshares, _pending, user.lastAction);
	}

	function viewPoolPayout(address _contract) external view returns (uint256) {
		return poolPayout[_contract].amount;
	}

	function viewPoolMinServe(address _contract) external view returns (uint256) {
		return poolPayout[_contract].minServe;
	}

	/**
     * @return Returns total pending dtx rewards
     */
    function calculateTotalPendingDTXRewards() external view returns (uint256) {
        return(IMasterChef(masterchef).pendingDtx(poolID));
    }
	
	//public lookup for UI
    function publicBalanceOf() public view returns (uint256) {
        uint256 amount = IMasterChef(masterchef).pendingDtx(poolID); 
        uint256 _credit = IMasterChef(masterchef).credit(address(this));
        return _credit + amount; 
    }

	// With "Virtual harvest" for external calls
	function virtualAccDtxPerShare() public view returns (uint256) {
		uint256 _pending = IMasterChef(masterchef).pendingDtx(poolID);
		return (accDtxPerShare + _pending * 1e12  / totalTshares);
	}
}
