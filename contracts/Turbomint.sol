pragma solidity >=0.4.22 <0.7.0;

interface IERC721 {
    function approve(address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function exists(uint256 tokenId) external view returns (bool);
}

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IDeposit {
    function lotSizeTbtc() external view returns (uint256);
    function signerFee() external view returns (uint256);
}

/// @title Turbomint is a quick way to match unqualified TDTs with TBTC holders
///        willing to provide TBTC and take care of qualification (for a fee).
/// @notice No security audits here, use at your own risk, example code!
/// @dev No security audits here, use at your own risk, example code!
contract Turbomint {
    uint256 fillFeeDivisor;

    IERC721 tdtContract;
    IERC721 frtContract;
    IERC20 tbtcContract;

    mapping (uint256=>address) openOrders;

    /// @dev Creates the Turbomint deposit for the given TBTC, FRT, and TDT
    ///      contracts, with fixed `_fillFeeDivisor` for the fee charged to
    ///      accelerate minting. The fee is kept by the provider of TBTC.
    constructor(IERC20 _tbtcContract, IERC721 _frtContract, IERC721 _tdtContract, uint256 _fillFeeDivisor) public {
        require(_fillFeeDivisor > 0, "Fill fee divisor must be > 0.");
        frtContract = _frtContract;
        tdtContract = _tdtContract;
        tbtcContract = _tbtcContract;
        fillFeeDivisor = _fillFeeDivisor;
    }

    /// @notice Transfer a TDT to the contract to request that someone exchange
    ///         it for the lot size amount of TBTC - signer fee requirements and
    ///         the turbominting fee. Transfer of the TDT must be preapproved.
    function requestTurbomint(uint256 _tdtId) public {
        tdtContract.transferFrom(msg.sender, address(this), _tdtId);
        openOrders[_tdtId] = msg.sender;
    }

    /// @notice Reclaims a TDT that has not yet had TBTC provided. Only available
    ///         to the original requester.
    function nopeOut(uint256 _tdtId) public {
        address originalRequester = openOrders[_tdtId];
        require(originalRequester != address(0), "No open order for the given TDT id.");
        require(msg.sender == originalRequester, "Only original TDT holder can nope out.");

        tdtContract.transferFrom(address(this), msg.sender, _tdtId);

        delete openOrders[_tdtId];
    }

    /// @notice Provides the turbomint service by transferring TBTC from the sender
    ///         to the requester who turned in the given TDT. The amount of TBTC is
    ///         the amount returned by `getTbtcToFill(_tdtId)`, and is equivalent to
    ///         the lot size of the associated tBTC deposit less unescrowed signer
    ///         fees and the turbomint fee.
    function provideTurbomint(uint256 _tdtId) public returns (uint256) {
        address recipient = openOrders[_tdtId];
        require(recipient != address(0), "No open order for the given TDT id.");      

        uint256 finalTransferAmount = getTbtcToFill(_tdtId);

        tdtContract.transferFrom(address(this), msg.sender, _tdtId);
        tbtcContract.transferFrom(msg.sender, recipient, finalTransferAmount);

        delete openOrders[_tdtId];

        return finalTransferAmount;
    }

    /// @notice Returns the amount of TBTC that would be transferred to the original
    ///         turbomint requester for the given TDT id from an account that calls
    ///         `provideTurbomint`. The amount is equivalent to the lot size of the
    //          associated tBTC deposit less unescrowed signer fees and the turbomint
    ///         fee.
    function getTbtcToFill(uint256 _tdtId) public view returns (uint256) {
        IDeposit deposit = IDeposit(address(uint160(_tdtId)));

        uint256 amount = deposit.lotSizeTbtc();
        uint256 frtDeduction = deposit.signerFee();
        if (frtContract.exists(_tdtId)) {
            frtDeduction = 0;
        }
        uint256 fillFee = amount / fillFeeDivisor;
        
        return amount - frtDeduction - fillFee;
    }
}