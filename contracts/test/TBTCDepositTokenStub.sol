pragma solidity ^0.5.10;

import "@openzeppelin/contracts/token/ERC721/ERC721Metadata.sol";

contract TBTCDepositTokenStub is ERC721Metadata {

    constructor(address _depositFactory) 
        ERC721Metadata("tBTC Deposit Token", "TDT") 
    public {
        // solium-disable-previous-line no-empty-blocks
    }

    function mint(address _to, uint256 _tokenId) public {
        _mint(_to, _tokenId);
    }

    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }
}
