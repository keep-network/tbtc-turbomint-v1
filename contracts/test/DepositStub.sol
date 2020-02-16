pragma solidity >=0.4.22 <0.7.0;

contract DepositStub {
    uint256 _lotSize;
    uint256 _signerFee;

    function lotSizeTbtc() external view returns (uint256){
        return _lotSize;
    }

    function signerFee() external view returns (uint256){
        return _signerFee;
    }

    function setLotSize(uint256 lotSize) public {
        _lotSize = lotSize;
    }

    function setSignerFee(uint256 signerFee) public {
        _signerFee = signerFee;
    }
}