// SPDX-License-Identifier: NONE

pragma solidity 0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interface/IMasterChef.sol";
import "./interface/IDTX.sol";
import "./interface/IConsensus.sol";
import "./interface/IacPool.sol";
import "./interface/ITreasury.sol";

contract DTXgovernor {
    address private immutable deployer;
    address public constant token = ; //XPD token


    //masterchef address
    address public constant masterchef = ;

	address public constant basicContract = ;
	address public constant farmContract = ;
	address public constant fibonacceningContract = ; //reward boost contract
    address public constant consensusContract = ;
	
	address public constant creditContract = ;
	
	address public constant nftStakingContract = ;
	address public constant nftAllocationContract = ;
    
    address public constant treasuryWallet = ;
    address public constant nftWallet = ;

	address public constant senateContract = ;
	address public constant rewardContract = ; //for referral rewards
    
    //addresses for time-locked deposits(autocompounding pools)
    address public constant acPool1 = ;
    address public constant acPool2 = ;
    address public constant acPool3 = ;
    address public constant acPool4 = ;
    address public constant acPool5 = ;
    address public constant acPool6 = ;
        
    //pool ID in the masterchef for respective Pool address and dummy token
    uint256 public constant acPool1ID = 0;
    uint256 public constant acPool2ID = 1;
    uint256 public constant acPool3ID = 2;
    uint256 public constant acPool4ID = 3;
    uint256 public constant acPool5ID = 4;
    uint256 public constant acPool6ID = 5;
	
	uint256 public constant nftStakingPoolID = 11;
	
	address public constant plsVault = ;
	address public constant plsxVault = ;
	address public constant incVault = ;
	address public constant hexVault = ;
	address public constant tshareVault = ;

	address public constant tokenDistributionContract = ;
	address public constant tokenDistributionContractExtraPenalty = ;
    
    mapping(address => uint256) private _rollBonus;

	uint256 public referralBonus = 1000; // 10% for both referr and invitee
	uint256 public depositFee = 0;
	uint256 public fundingRate = 0;

	uint256 public mintingPhaseLaunchDate;
	uint256 public lastTotalCredit; // Keeps track of last total credit from chef (sends 2.5% to reward contract)
    
    uint256 public costToVote = 1000 * 1e18;  // 1000 coins. All proposals are valid unless rejected. This is a minimum to prevent spam
    uint256 public delayBeforeEnforce = 2 days; //minimum number of TIME between when proposal is initiated and executed
    
    //fibonaccening event can be scheduled once minimum threshold of tokens have been collected
    uint256 public thresholdFibonaccening = 27000000 * 1e18; // roughly 2.5% of initial supply to begin with
    
    //delays for Fibonnaccening(Reward Boost) Events
    uint256 public constant minDelay = 1 days; // has to be called minimum 1 day in advance
    uint256 public constant maxDelay = 31 days; 

	bool public mintingPhase = false;
    
    uint256 public lastRegularReward = 850 * 1e18; //remembers the last reward used(outside of boost)
    bool public eventFibonacceningActive = false; // prevent some functions if event is active ..threshold and durations for fibonaccening


    uint256  public totalFibonacciEventsAfterGrand; //used for rebalancing inflation after Grand Fib
    
    uint256 public newGovernorRequestBlock;
    address public eligibleNewGovernor; //used for changing smart contract
    bool public changeGovernorActivated;
	
	uint256 public lastHarvestedTime;

	uint256[] public allocationPercentages = [5333, 8000, 12000, 26660, 34666, 40000]; // In basis points (1 basis point = 0.01%)

    event SetInflation(uint256 rewardPerBlock);
    event EnforceGovernor(address indexed _newGovernor, address indexed enforcer);
    event GiveRolloverBonus(address indexed recipient, uint256 amount, address indexed poolInto);
	event Harvest(address indexed sender, uint256 callFee);
    
    constructor() {
		deployer = msg.sender;

		// Roll-over bonuses
		_rollBonus[acPool1] = 75;
		_rollBonus[acPool2] = 100;
		_rollBonus[acPool3] = 150;
		_rollBonus[acPool4] = 250;
		_rollBonus[acPool5] = 350;
		_rollBonus[acPool6] = 500;
    }    
   
   
     /**
     * Rebalances Pools and allocates rewards in masterchef
     * Pools with higher time-lock must always pay higher rewards in relative terms
     * Eg. for 1DTX staked in the pool 6, you should always be receiving
     * 50% more rewards compared to staking in pool 4
     */
    function rebalancePools() public {
    	uint256 balancePool1 = IacPool(acPool1).balanceOf();
    	uint256 balancePool2 = IacPool(acPool2).balanceOf();
    	uint256 balancePool3 = IacPool(acPool3).balanceOf();
    	uint256 balancePool4 = IacPool(acPool4).balanceOf();
    	uint256 balancePool5 = IacPool(acPool5).balanceOf();
    	uint256 balancePool6 = IacPool(acPool6).balanceOf();
    	
   	    uint256 total = balancePool1 + balancePool2 + balancePool3 + balancePool4 + balancePool5 + balancePool6;

		IMasterChef(masterchef).set(acPool1ID, (100000 * 5333 * balancePool1) / (total * 10000), true);
    	IMasterChef(masterchef).set(acPool2ID, (100000 * 8000 * balancePool2) / (total * 10000), false);
    	IMasterChef(masterchef).set(acPool3ID, (100000 * 12000 * balancePool3) / (total * 10000), false);
    	IMasterChef(masterchef).set(acPool4ID, (100000 * 26660 * balancePool4) / (total * 10000), false);
    	IMasterChef(masterchef).set(acPool5ID, (100000 * 34666 * balancePool5) / (total * 10000), false);
    	IMasterChef(masterchef).set(acPool6ID, (100000 * 40000 * balancePool6) / (total * 10000), false);
    }
	

    /**
     * Harvests from all pools and rebalances rewards
     */
    function harvest() external {
        require(msg.sender == tx.origin, "no proxy/contracts");

        uint256 totalFee = pendingHarvestRewards();

        rebalancePools();
		
		lastHarvestedTime = block.timestamp;
	
		require(IERC20(token).transfer(msg.sender, totalFee), "token transfer failed");

		emit Harvest(msg.sender, totalFee);
    }
    
    /**
     * Mechanism, where the governor gives the bonus 
     * to user for extending(re-commiting) their stake
     * tldr; sends the gift deposit, which resets the timer
     * the pool is responsible for calculating the bonus
     */
    function stakeRolloverBonus(address _toAddress, address _depositToPool, uint256 _bonusToPay, uint256 _stakeID) external {
        require(
            msg.sender == acPool1 || msg.sender == acPool2 || msg.sender == acPool3 ||
            msg.sender == acPool4 || msg.sender == acPool5 || msg.sender == acPool6);
        
        IacPool(_depositToPool).addAndExtendStake(_toAddress, _bonusToPay, _stakeID, 0);
        
        emit GiveRolloverBonus(_toAddress, _bonusToPay, _depositToPool);
    }
    
    
    function enforceGovernor() external {
        require(msg.sender == consensusContract);
		require(newGovernorRequestBlock + newGovernorBlockDelay() < block.number, "time delay not yet passed");

		IMasterChef(masterchef).setFeeAddress(eligibleNewGovernor);
        IMasterChef(masterchef).dev(eligibleNewGovernor);
        IMasterChef(masterchef).transferOwnership(eligibleNewGovernor); //transfer masterchef ownership
		
		IERC20(token).transfer(eligibleNewGovernor, IERC20(token).balanceOf(address(this))); // send collected DTX tokens to new governor
        
		emit EnforceGovernor(eligibleNewGovernor, msg.sender);
    }
	
    function setNewGovernor(address beneficiary) external {
        require(msg.sender == consensusContract);
        newGovernorRequestBlock = block.number;
        eligibleNewGovernor = beneficiary;
        changeGovernorActivated = true;
    }
	
	function governorRejected() external {
		require(changeGovernorActivated, "not active");
		
		(bool _govInvalidated, ) = IConsensus(consensusContract).isGovInvalidated(eligibleNewGovernor);
		if(_govInvalidated) {
			changeGovernorActivated = false;
		}
	}

	function treasuryRequest(address _tokenAddr, address _recipient, uint256 _amountToSend) external {
		require(msg.sender == consensusContract);
		ITreasury(payable(treasuryWallet)).requestWithdraw(
			_tokenAddr, _recipient, _amountToSend
		);
	}


	function rememberReward() external {
		require(msg.sender == fibonacceningContract);
		lastRegularReward = IMasterChef(masterchef).DTXPerBlock();
	}


    /**
     * Sets inflation in Masterchef
     */
    function setInflation(uint256 rewardPerBlock) external {
        require(msg.sender == fibonacceningContract);
    	IMasterChef(masterchef).updateEmissionRate(rewardPerBlock);

        emit SetInflation(rewardPerBlock);
    }

	function setActivateFibonaccening(bool _arg) external {
		require(msg.sender == fibonacceningContract);
		eventFibonacceningActive = _arg;
	}


	function transferRewardBoostThreshold() external {
		require(msg.sender == fibonacceningContract);
		
		IERC20(token).transfer(fibonacceningContract, thresholdFibonaccening);
	}
	
	function postGrandFibIncreaseCount() external {
		require(msg.sender == fibonacceningContract);
		totalFibonacciEventsAfterGrand++;
	}
	
	function setThresholdFibonaccening(uint256 newThreshold) external {
	    require(msg.sender == basicContract);
	    thresholdFibonaccening = newThreshold;
	}
	
	function updateDelayBeforeEnforce(uint256 newDelay) external {
	    require(msg.sender == basicContract);
	    delayBeforeEnforce = newDelay;
	}
	
	function setCallFee(address _acPool, uint256 _newCallFee) external {
	    require(msg.sender == basicContract);
	    IacPool(_acPool).setCallFee(_newCallFee);
	}
	
	function updateCostToVote(uint256 newCostToVote) external {
	    require(msg.sender == basicContract);
	    costToVote = newCostToVote;
	}
	
	function updateRolloverBonus(address _forPool, uint256 _bonus) external {
	    require(msg.sender == basicContract);
		require(_bonus <= 1500, "15% hard limit");
	    _rollBonus[_forPool] = _bonus;
	}

	function addNewPool(address _pool) external {
	    require(msg.sender == basicContract);
		require(IMasterChef(masterchef).poolLength() < 50, "Maximum pools allowed reached");
	    IMasterChef(masterchef).add(0, _pool, false);
	}

	function setPool(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external {
	    require(msg.sender == farmContract);
	    IMasterChef(masterchef).set(_pid, _allocPoint, _withUpdate);
	}

	// If fees are changed, updateFees() function must be called to each vault contract to sync the update!
	function updateVault(uint256 _type, uint256 _amount) external {
        require(msg.sender == farmContract);

        if(_type == 0) {
            depositFee = _amount;
        } else if(_type == 1) {
            fundingRate = _amount;
        } else if (_type == 2) {
			require(_amount <= 2500, "max 25% Bonus!");
			referralBonus = _amount;
		}
    }
	
	function setGovernorTax(uint256 _amount) external {
		require(msg.sender == farmContract);
		IMasterChef(masterchef).setGovernorFee(_amount);
	}

	
	function burnTokens(uint256 amount) external {
		require(msg.sender == farmContract);
		
		IDTX(token).burn(amount);
	}
	
	function transferToTreasury(uint256 amount) external {
		require(msg.sender == farmContract);
		
		IERC20(token).transfer(treasuryWallet, amount);
	}

	// During first 2 months, we can send 2.5% of tokens to the referral reward contract
	// Afterwards this has to be managed through the treasury
	function transferToReferralContract() external {
		require(block.timestamp < mintingPhaseLaunchDate + 60 days, "Only during first 2 months!");
		
		uint256 _total = IMasterChef(masterchef).totalCreditRewards();
		uint256 _toTransfer = ((_total - lastTotalCredit) * 25 / 1000);

		if(IDTX(token).balanceOf(address(this)) >= _toTransfer) {
			IDTX(token).transfer(rewardContract, _toTransfer);
		} else {
			_toTransfer = IDTX(token).balanceOf(address(this));
			IDTX(token).transfer(rewardContract, _toTransfer);
		}

		lastTotalCredit = _total;
	}
	
    /**
     * Transfers collected fees into treasury wallet(but not DTX...for now)
     */
    function transferCollectedFees(address _tokenContract) external {
        require(msg.sender == tx.origin);
		require(_tokenContract != token, "not XPD!");
		
        uint256 amount = IERC20(_tokenContract).balanceOf(address(this));
        
        IERC20(_tokenContract).transfer(treasuryWallet, amount);
    }

	// When merkle tree root is provided to the distribution contract, the minting phase begins
	function beginMintingPhase() external {
		require(msg.sender == tokenDistributionContract, "only distribution contract!");
		require(!mintingPhase, "Minting phase has already begun!");

		mintingPhase = true;
		mintingPhaseLaunchDate = block.timestamp;
		IMasterChef(masterchef).updateStartBlock(block.number+59294); // Minting phase begins in 7 days
	}

	// Prior the minting phase begins, deployer can make changes in case of a security-related issue
	function changeGovernorForSecurityPriorMintingBegins(address _newGovernor) external {
        require(msg.sender == deployer, "Deployer only!");
		require(!mintingPhase, "Minting phase has already begun!");

        IMasterChef(masterchef).transferOwnership(_newGovernor); //transfer masterchef ownership
    }

	function getRollBonus(address _bonusForPool) external view returns (uint256) {
        return _rollBonus[_bonusForPool];
    }

	function pendingHarvestRewards() public view returns (uint256) {
		uint256 totalRewards = 
			IacPool(acPool1).calculateHarvestDTXRewards() +
			IacPool(acPool2).calculateHarvestDTXRewards() + 
			IacPool(acPool3).calculateHarvestDTXRewards() +
			IacPool(acPool4).calculateHarvestDTXRewards() + 
			IacPool(acPool5).calculateHarvestDTXRewards() + 
			IacPool(acPool6).calculateHarvestDTXRewards();
		return totalRewards;
	}
	
	/*
	 * newGovernorBlockDelay is the delay during which the governor proposal can be voted against
	 * As the time passes, changes should take longer to enforce(greater security)
	 * Prioritize speed and efficiency at launch. Prioritize security once established
	 * Delay increases by 535 blocks(roughly 1.6hours) per each day after launch
	 * Delay starts at 42772 blocks(roughly 5 days)
	 * After a month, delay will be roughly 7 days (increases 2days/month)
	 * After a year, 29 days. After 2 years, 53 days,...
	 * Can be ofcourse changed by replacing governor contract
	 */
	function newGovernorBlockDelay() public view returns (uint256) {
		return (42772 + (((block.timestamp - mintingPhaseLaunchDate) / 86400) * 535));
	}
    
}  
