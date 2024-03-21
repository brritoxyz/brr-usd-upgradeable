// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBrrUSD} from "src/interfaces/IBrrUSD.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrUSDv2Helper {
    using SafeTransferLib for address;

    IComet private constant _COMET =
        IComet(0xb125E6687d4313864e53df431d5425969c15Eb2F);
    address private constant _USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    IBrrUSD public immutable brrUSD;

    error InsufficientAssetsRedeemed();

    constructor(address _brrUSD) {
        brrUSD = IBrrUSD(_brrUSD);

        _USDC.safeApprove(_brrUSD, type(uint256).max);
    }

    /**
     * @notice Redeem brrUSD for USDC.
     * @param  shares     uint256  Amount of shares to redeem.
     * @param  to         address  USDC recipient.
     * @param  minAssets  uint256  The minimum amount of assets that must be redeemed.
     */
    function redeem(uint256 shares, address to, uint256 minAssets) external {
        // Requires approval from the caller to spend their brrUSD balance.
        brrUSD.redeem(shares, address(this), msg.sender);

        // Comet's alias for an "entire balance" is `type(uint256).max`.
        _COMET.withdraw(_USDC, type(uint256).max);

        uint256 redeemedAssets = _USDC.balanceOf(address(this));

        if (redeemedAssets < minAssets) revert InsufficientAssetsRedeemed();

        _USDC.safeTransfer(to, redeemedAssets);
    }
}
