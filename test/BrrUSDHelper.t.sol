// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrUSD} from "src/BrrUSD.sol";
import {BrrUSDHelper} from "src/BrrUSDHelper.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {Helper} from "test/Helper.sol";

contract BrrUSDHelperTest is Test, Helper {
    using SafeTransferLib for address;

    BrrUSDHelper public immutable redeemHelper;

    receive() external payable {}

    constructor() {
        redeemHelper = new BrrUSDHelper(address(vault), ROUTER);

        address(vault).safeApprove(address(redeemHelper), type(uint256).max);
        USDC.safeApprove(address(redeemHelper), type(uint256).max);

        // Transfer the balance of a large USDC holder to self since `deal` is reverting.
        address usdcWhale = 0xcDAC0d6c6C59727a65F871236188350531885C43;

        vm.startPrank(usdcWhale);

        USDC.safeTransfer(address(this), USDC.balanceOf(usdcWhale));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             depositUSDC
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositUSDCInsufficientSharesMinted() external {
        uint256 amount = 100e6;
        address to = address(this);
        uint256 minShares = vault.convertToShares(amount) + 1;

        vm.expectRevert(BrrUSD.InsufficientSharesMinted.selector);

        redeemHelper.depositUSDC(amount, to, minShares);
    }

    function testDepositUSDC() external {
        uint256 amount = 100e6;
        address to = address(this);
        (, uint256 quote) = IRouter(ROUTER).getSwapOutput(
            USDC_USDBC_PAIR,
            amount
        );
        uint256 minShares = vault.convertToShares(
            quote,
            vault.totalSupply(),
            vault.totalAssets()
        ) - COMET_ROUNDING_ERROR_MARGIN;
        uint256 usdcBalanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 totalAssetsBefore = vault.totalAssets();

        redeemHelper.depositUSDC(amount, to, minShares);

        uint256 sharesReceived = vault.balanceOf(to) - sharesBalanceBefore;
        uint256 assetsReceived = vault.totalAssets() - totalAssetsBefore;

        assertLe(minShares, sharesReceived);
        assertEq(usdcBalanceBefore - amount, USDC.balanceOf(address(this)));
        assertLe(quote - COMET_ROUNDING_ERROR_MARGIN, assetsReceived);
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, USDC.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }

    function testDepositUSDCFuzz(uint256 amount) external {
        amount = bound(amount, 1e6, type(uint40).max);

        address to = address(this);
        (, uint256 quote) = IRouter(ROUTER).getSwapOutput(
            USDC_USDBC_PAIR,
            amount
        );
        uint256 minShares = vault.convertToShares(
            quote,
            vault.totalSupply(),
            vault.totalAssets()
        ) - COMET_ROUNDING_ERROR_MARGIN;
        uint256 usdcBalanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 totalAssetsBefore = vault.totalAssets();

        redeemHelper.depositUSDC(amount, to, minShares);

        uint256 sharesReceived = vault.balanceOf(to) - sharesBalanceBefore;
        uint256 assetsReceived = vault.totalAssets() - totalAssetsBefore;

        assertLe(minShares, sharesReceived);
        assertEq(usdcBalanceBefore - amount, USDC.balanceOf(address(this)));
        assertLe(quote - COMET_ROUNDING_ERROR_MARGIN, assetsReceived);
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, USDC.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
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

        uint256 assetBalanceBefore = USDBC.balanceOf(address(this));

        redeemHelper.redeem(shares, address(this), assets);

        // Account for Comet rounding down and compare against the USDC amount received.
        assertLe(assets, USDBC.balanceOf(address(this)) - assetBalanceBefore);

        // The redeem helper should not maintain balances for any of the tokens it handles.
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }

    function testRedeemFuzz(uint8 assetMultiplier) external {
        uint256 deposit = 1e6 * (uint256(assetMultiplier) + 1);
        uint256 shares = vault.deposit(deposit, address(this), 1);
        uint256 assets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;
        uint256 assetBalanceBefore = USDBC.balanceOf(address(this));

        redeemHelper.redeem(shares, address(this), assets);

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(assets, USDBC.balanceOf(address(this)) - assetBalanceBefore);

        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }
}
