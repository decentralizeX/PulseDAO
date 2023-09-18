// SPDX-License-Identifier: NONE
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.0/contracts/security/ReentrancyGuard.sol";

import "./interface/IMasterChef.sol";
import "./interface/IGovernor.sol";

contract XPD is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
	uint256 public constant MAX_SUPPLY = 21000000000 * 1e18; //21 billion max supply
	string private _name;
    string private _symbol;
    
	constructor() ERC20("PulseDAO Currency", "XPD") Ownable(msg.sender) {
		_name = string("PulseDAO");
		_symbol = string("XPD");
	}
	
    modifier decentralizedVoting {
    	require(msg.sender == governor(), "Governor only, decentralized voting required");
    	_;
    }
	

    function mint(address to, uint256 amount) public onlyOwner {
		require(totalSupply() + amount <= MAX_SUPPLY, "MAX SUPPLY REACHED!");
        _mint(to, amount);
    }
	
    function burnToken(address account, uint256 amount) external onlyOwner returns (bool) {
	_burn(account, amount);
	return true;
    }

	
	//Standard ERC20 makes name and symbol immutable
	//We add potential to rebrand for full flexibility if stakers choose to do so through voting
	function rebrandName(string memory _newName) external decentralizedVoting {
		_name = _newName;
	}
	function rebrandSymbol(string memory _newSymbol) external decentralizedVoting {
        _symbol = _newSymbol;
	}
	
	// Governor is a smart contract that allows the control of the entire system in a decentralized manner
	//DTX token is owned by masterchef and masterchef is owned by Governor
	function governor() public view returns (address) {
		return IMasterChef(owner()).owner();
	}
	
	// masterchef is the owner of the token (handles token minting/inflation)
	function masterchefAddress() external view returns (address) {
		return owner();
	}
	
	
    /**
     * @dev Returns the name of the token.
     */
    function name() public override view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public override view returns (string memory) {
        return _symbol;
    }
}
