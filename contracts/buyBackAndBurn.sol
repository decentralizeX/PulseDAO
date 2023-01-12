// SPDX-License-Identifier: NONE
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";

import "interface/IDTX.sol";
import "interface/IGovernor.sol";

contract BuybackDTX {
    address public constant UNISWAP_ROUTER_ADDRESS = ;
    address public immutable DTX = ;
    address public immutable wPLS = ;

    IUniswapV2Router02 public uniswapRouter;
	
	bool public toBurn = true;

    constructor() {
        uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    }

    function buybackPLS() public {
		require(msg.sender == tx.origin);
        uint deadline = block.timestamp + 15; 
        uint[] memory _minOutT = getEstimatedDTXforETH();
        uint _minOut = _minOutT[_minOutT.length-1] * 99 / 100;
        uniswapRouter.swapETHForExactTokens{ value: address(this).balance }(_minOut, getPLSpath(), address(this), deadline);
    }
	
	function buybackAndBurn(bool _pls) external {
		if(_pls) {
			buybackPLS();
		}
		burnTokens();
	}
	
    function burnTokens() public {
		if(toBurn) {
			IDTX(DTX).burn(IERC20(DTX).balanceOf(address(this)));
		} else {
        	require(IERC20(DTX).transfer(treasury(), IERC20(DTX).balanceOf(address(this))));
		}
    }

    function withdraw() external {
        require(msg.sender == governor(), "only thru decentralized Governance");
        payable(treasury()).transfer(address(this).balance);
    }
    
    function withdrawToken(address _token) external {
      require(msg.sender == governor(), "only thru decentralized Governance");
      IERC20(_token).transfer(treasury(), IERC20(_token).balanceOf(address(this)));
    }
	
	function switchBurn(bool _option) external {
		require(msg.sender == governor(), "only thru decentralized Governance");
		toBurn = _option;
	}

    //with gets amount in you provide how much you want out
    function getEstimatedDTXforETH() public view returns (uint[] memory) {
        return uniswapRouter.getAmountsOut(address(this).balance, getPLSpath()); //NOTICE: ETH is matic PLS
    }

    function getPLSpath() private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = wPLS;
        path[1] = DTX;

        return path;
    }

	function governor() public view returns (address) {
		return IDTX(DTX).governor();
	}

  	function treasury() public view returns (address) {
		return IGovernor(governor()).treasuryWallet();
	}

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
