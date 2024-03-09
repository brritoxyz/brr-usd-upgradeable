// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrUSD} from "src/BrrUSD.sol";
import {BrrUSDHelper} from "src/BrrUSDHelper.sol";
import {Helper} from "test/Helper.sol";

contract BrrUSDHelperTest is Test, Helper {
    using SafeTransferLib for address;

    BrrUSDHelper public immutable redeemHelper;

    receive() external payable {}

    constructor() {
        redeemHelper = new BrrUSDHelper(address(vault), ROUTER);

        vault.approve(address(redeemHelper), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testCannotRedeemInsufficientAssetsRedeemed() external {
        uint256 shares = vault.deposit(1e6, address(this), 1);
        uint256 assets = vault.convertToAssets(shares) + 1e6;

        vm.expectRevert(BrrUSDHelper.InsufficientAssetsRedeemed.selector);

        redeemHelper.redeem(shares, address(this), assets);
    }

    function testRedeem() external {
        uint256 shares = vault.deposit(1e6, address(this), 1);

        // The amount of cUSDC that will be redeemed from brrUSD.
        uint256 assets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;

        uint256 assetBalanceBefore = ASSET.balanceOf(address(this));

        redeemHelper.redeem(shares, address(this), assets);

        // Account for Comet rounding down and compare against the USDC amount received.
        assertLe(assets, ASSET.balanceOf(address(this)) - assetBalanceBefore);

        // The redeem helper should not maintain balances for any of the tokens it handles.
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, ASSET.balanceOf(address(redeemHelper)));
    }

    function testRedeemFuzz(uint8 assetMultiplier) external {
        uint256 deposit = 1e6 * (uint256(assetMultiplier) + 1);
        uint256 shares = vault.deposit(deposit, address(this), 1);
        uint256 assets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;
        uint256 assetBalanceBefore = ASSET.balanceOf(address(this));

        redeemHelper.redeem(shares, address(this), assets);

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(assets, ASSET.balanceOf(address(this)) - assetBalanceBefore);

        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, ASSET.balanceOf(address(redeemHelper)));
    }
}
