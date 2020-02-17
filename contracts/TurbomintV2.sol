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

    IERC721 tdtContract;
    IERC721 frtContract;
    IERC20 tbtcContract;

    struct Order {
        address requester;
        uint256 openedAt;
        uint256 initialFee;
        uint256 finalFee;
        uint256 timeFrame;
        uint256 timeout;
    }

    mapping (uint256 => Order) openOrders;

    /// @dev Creates the Turbomint deposit for the given TBTC, FRT, and TDT
    ///      contracts, with fixed `_fillFeeDivisor` for the fee charged to
    ///      accelerate minting. The fee is kept by the provider of TBTC.
    constructor(IERC20 _tbtcContract, IERC721 _frtContract, IERC721 _tdtContract) public {
        frtContract = _frtContract;
        tdtContract = _tdtContract;
        tbtcContract = _tbtcContract;
    }

    /// @notice Transfer a TDT to the contract to request that someone exchange
    ///         it for the lot size amount of TBTC - signer fee requirements and
    ///         the turbominting fee. Transfer of the TDT must be preapproved.
    /// @param _tdtId The ID of the TDT to exchange.
    /// @param _fee The fee to begin the order at.
    function openOrder(uint256 _tdtId, uint256 _fee) public {
        openOrder(_tdtId, _fee, _fee, 0, 0);
    }

    /// @notice Transfer a TDT to the contract to request that someone exchange
    ///         it for the lot size amount of TBTC - signer fee requirements and
    ///         the turbominting fee. Transfer of the TDT must be preapproved.
    /// @param _tdtId The ID of the TDT to exchange.
    /// @param _fee The fee to begin the order at.
    /// @param _timeout the time after which the order can no longer be fulfilled.
    function openOrder(uint256 _tdtId, uint256 _fee, uint256 _timeout) public {
        openOrder(_tdtId, _fee, _fee, 0, _timeout);
    }

    /// @notice Transfer a TDT to the contract to request that someone exchange
    ///         it for the lot size amount of TBTC - signer fee requirements and
    ///         the turbominting fee. Transfer of the TDT must be preapproved.
    /// @param _tdtId The ID of the TDT to exchange.
    /// @param _initialFee The fee to begin the order at.
    /// @param _finalFee The maximum fee the order can reach.
    /// @param _timeFrame The time frame after which the order will be at the maximum fee.
    function openOrder(
        uint256 _tdtId,
        uint256 _initialFee,
        uint256 _finalFee,
        uint256 _timeFrame
    ) public {
        openOrder(_tdtId, _initialFee, _finalFee, _timeFrame, 0);
    }

    /// @notice Transfer a TDT to the contract to request that someone exchange
    ///         it for the lot size amount of TBTC - signer fee requirements and
    ///         the turbominting fee. Transfer of the TDT must be preapproved.
    /// @param _tdtId The ID of the TDT to exchange.
    /// @param _initialFee The fee to begin the order at.
    /// @param _finalFee The maximum fee the order can reach.
    /// @param _timeFrame The time frame after which the order will be at the maximum fee.
    /// @param _timeout the time after which the order can no longer be fulfilled.
    function openOrder(
        uint256 _tdtId,
        uint256 _initialFee,
        uint256 _finalFee,
        uint256 _timeFrame,
        uint256 _timeout)
    public {
        tdtContract.transferFrom(msg.sender, address(this), _tdtId);
        openOrders[_tdtId] = Order(msg.sender, block.timestamp, _initialFee, _finalFee, _timeFrame, _timeout);
    }


    /// @notice Reclaims a TDT that has not yet had TBTC provided. Only available
    ///         to the original requester.
    function cancelOrder(uint256 _tdtId) public {
        address originalRequester = openOrders[_tdtId].requester;
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
        Order memory _order = openOrders[_tdtId];

        if(_order.timeout != 0) {
            require(block.timestamp < _order.timeout, "This order has expired");
        }

        address recipient = _order.requester;
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
        Order memory _order = openOrders[_tdtId];
        uint256 amount = deposit.lotSizeTbtc();
        uint256 frtDeduction = frtContract.exists(_tdtId) ? 0 : deposit.signerFee();
        uint256 turbomintFee = calculateFee(_order.initialFee, _order.finalFee, _order.openedAt, _order.timeFrame);

        return amount - frtDeduction - turbomintFee;
    }

    function calculateFee(uint256 _initial, uint256 _final, uint256 _opened, uint256 _timeframe) internal view returns (uint256){
        if(_initial == _final){
            return _initial;
        }
        uint256 increment = _initial > _final ? (_initial - _final) / _timeframe : (_final - _initial) / _timeframe;
        uint256 fee = _initial > _final ?
            (_opened + _timeframe) < block.timestamp ? _final : _initial + (increment * (block.timestamp - _opened)) :
            (_opened + _timeframe) < block.timestamp ? _final : _initial - (increment * (block.timestamp - _opened));

        return fee;
    }

}