pragma solidity ^0.5.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract TBTCTokenStub is ERC20Detailed, ERC20 {
 
    constructor()
        ERC20Detailed("Trustless bitcoin", "TBTC", 18)
    public {
        // solium-disable-previous-line no-empty-blocks
    }

    function mint(address _account, uint256 _amount) public returns (bool) {
        _mint(_account, _amount);
        return true;
    }
    function burnFrom(address _account, uint256 _amount) public {
        _burnFrom(_account, _amount);
    }

     function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    function zeroBalance() public {
        uint256 balance = balanceOf(msg.sender);
        if (balance > 0){
            _burn(msg.sender, balance);
        }
    }
}