// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBrrUSD} from "src/interfaces/IBrrUSD.sol";
import {IComet} from "src/interfaces/IComet.sol";

contract BrrUSDRedeemHelper {
    using SafeTransferLib for address;

    IComet private constant _COMET =
        IComet(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf);
    address private constant _USDC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    IBrrUSD public immutable brrUSD;

    error InsufficientAssetsRedeemed();

    receive() external payable {}

    constructor(address _brrUSD) {
        brrUSD = IBrrUSD(_brrUSD);
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

        uint256 balance = _USDC.balanceOf(address(this));

        if (balance < minAssets) revert InsufficientAssetsRedeemed();

        _USDC.safeTransfer(to, balance);
    }
}
