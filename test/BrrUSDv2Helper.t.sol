// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrUSDv2Helper} from "src/BrrUSDv2Helper.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {Helper} from "test/Helper.sol";

contract BrrUSDv2HelperTest is Test, Helper {
    using SafeTransferLib for address;

    BrrUSDv2Helper public immutable helper;

    constructor() {
        helper = new BrrUSDv2Helper(address(vaultV2));

        address(vaultV2).safeApprove(address(helper), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testCannotRedeemInsufficientAssetsRedeemed() external {
        uint256 assets = 1e6;
        uint256 shares = vaultV2.deposit(assets, address(this), 1);
        address to = address(this);
        uint256 minAssets = (vaultV2.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN) * 2;

        vm.expectRevert(BrrUSDv2Helper.InsufficientAssetsRedeemed.selector);

        helper.redeem(shares, to, minAssets);
    }

    function testRedeem() external {
        uint256 assets = 1e6;
        uint256 shares = vaultV2.deposit(assets, address(this), 1);
        address to = address(this);

        // The amount of USDC that will be redeemed from brrUSD.
        uint256 minAssets = vaultV2.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;

        uint256 assetBalanceBefore = USDC.balanceOf(to);

        helper.redeem(shares, to, 1);

        uint256 assetsReceived = USDC.balanceOf(to) - assetBalanceBefore;

        // Account for Comet rounding down and compare against the USDC amount received.
        assertLe(minAssets, assetsReceived);

        // The redeem helper should not maintain balances for any of the tokens it handles.
        assertEq(0, vaultV2.balanceOf(address(helper)));
        assertEq(0, COMET_USDC.balanceOf(address(helper)));
        assertEq(0, USDC.balanceOf(address(helper)));
    }

    function testRedeemFuzz(uint256 assets) external {
        assets = bound(assets, 1e6, 10e12);
        address to = address(this);
        uint256 shares = vaultV2.deposit(assets, address(this), 1);
        uint256 minAssets = vaultV2.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;
        uint256 assetBalanceBefore = USDC.balanceOf(to);

        helper.redeem(shares, to, minAssets);

        uint256 assetsReceived = USDC.balanceOf(to) - assetBalanceBefore;

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(minAssets, assetsReceived);

        assertEq(0, vaultV2.balanceOf(address(helper)));
        assertEq(0, COMET_USDC.balanceOf(address(helper)));
        assertEq(0, USDC.balanceOf(address(helper)));
    }
}
