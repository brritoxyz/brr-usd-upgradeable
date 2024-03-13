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
        uint256 minAssets = vault.convertToAssets(quote) -
            COMET_ROUNDING_ERROR_MARGIN;
        uint256 usdcBalanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 mintedShares = redeemHelper.depositUSDC(amount, to, minShares);
        uint256 sharesReceived = vault.balanceOf(to) - sharesBalanceBefore;
        uint256 assetsReceived = vault.totalAssets() - totalAssetsBefore;
        uint256 supplyAdded = vault.totalSupply() - totalSupplyBefore;

        assertLe(minShares, sharesReceived);
        assertLe(minShares, mintedShares);
        assertLe(minAssets, assetsReceived);
        assertEq(mintedShares, supplyAdded);
        assertEq(usdcBalanceBefore - amount, USDC.balanceOf(address(this)));
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, USDC.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }

    function testDepositUSDCFuzz(uint256 amount, address to) external {
        amount = bound(amount, 1e6, type(uint40).max);

        (, uint256 quote) = IRouter(ROUTER).getSwapOutput(
            USDC_USDBC_PAIR,
            amount
        );
        uint256 minShares = vault.convertToShares(
            quote,
            vault.totalSupply(),
            vault.totalAssets()
        ) - COMET_ROUNDING_ERROR_MARGIN;
        uint256 minAssets = vault.convertToAssets(quote) -
            COMET_ROUNDING_ERROR_MARGIN;
        uint256 usdcBalanceBefore = USDC.balanceOf(address(this));
        uint256 sharesBalanceBefore = vault.balanceOf(to);
        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 mintedShares = redeemHelper.depositUSDC(amount, to, minShares);
        uint256 sharesReceived = vault.balanceOf(to) - sharesBalanceBefore;
        uint256 assetsReceived = vault.totalAssets() - totalAssetsBefore;
        uint256 supplyAdded = vault.totalSupply() - totalSupplyBefore;

        assertLe(minShares, sharesReceived);
        assertLe(minShares, mintedShares);
        assertLe(minAssets, assetsReceived);
        assertEq(mintedShares, supplyAdded);
        assertEq(usdcBalanceBefore - amount, USDC.balanceOf(address(this)));
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, USDC.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }

    /*//////////////////////////////////////////////////////////////
                             redeem
    //////////////////////////////////////////////////////////////*/

    function testCannotRedeemInsufficientAssetsRedeemed() external {
        uint256 assets = 1e6;
        uint256 shares = vault.deposit(assets, address(this), 1);
        address to = address(this);
        uint256 minAssets = (vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN) * 2;

        vm.expectRevert(BrrUSDHelper.InsufficientAssetsRedeemed.selector);

        redeemHelper.redeem(shares, to, minAssets);
    }

    function testRedeem() external {
        uint256 assets = 1e6;
        uint256 shares = vault.deposit(assets, address(this), 1);
        address to = address(this);

        // The amount of USDBC that will be redeemed from brrUSD.
        uint256 minAssets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;

        uint256 assetBalanceBefore = USDBC.balanceOf(to);

        redeemHelper.redeem(shares, to, minAssets);

        uint256 assetsReceived = USDBC.balanceOf(to) - assetBalanceBefore;

        // Account for Comet rounding down and compare against the USDBC amount received.
        assertLe(minAssets, assetsReceived);

        // The redeem helper should not maintain balances for any of the tokens it handles.
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }

    function testRedeemFuzz(uint256 assets, address to) external {
        vm.assume(to != address(0));

        assets = bound(assets, 1e6, type(uint40).max);

        deal(USDBC, address(this), assets);

        uint256 shares = vault.deposit(assets, address(this), 1);
        uint256 minAssets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;
        uint256 assetBalanceBefore = USDBC.balanceOf(to);

        redeemHelper.redeem(shares, to, minAssets);

        uint256 assetsReceived = USDBC.balanceOf(to) - assetBalanceBefore;

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(minAssets, assetsReceived);

        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, USDBC.balanceOf(address(redeemHelper)));
    }

    /*//////////////////////////////////////////////////////////////
                             redeemUSDC
    //////////////////////////////////////////////////////////////*/

    function testCannotRedeemUSDCInsufficientAssetsRedeemed() external {
        uint256 assets = 1e6;
        uint256 shares = vault.deposit(assets, address(this), 1);
        address to = address(this);
        uint256 redeemedAssets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;
        (, uint256 minAssets) = IRouter(ROUTER).getSwapOutput(
            USDBC_USDC_PAIR,
            redeemedAssets
        );
        minAssets *= 2;

        vm.expectRevert(BrrUSDHelper.InsufficientAssetsRedeemed.selector);

        redeemHelper.redeemUSDC(shares, to, minAssets);
    }

    function testRedeemUSDC() external {
        uint256 assets = 1e6;
        uint256 shares = vault.deposit(assets, address(this), 1);
        address to = address(this);
        uint256 redeemedAssets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;

        // Amount of USDC received from swapping the USDBC redeemed.
        (, uint256 minAssets) = IRouter(ROUTER).getSwapOutput(
            USDBC_USDC_PAIR,
            redeemedAssets
        );

        uint256 assetBalanceBefore = USDC.balanceOf(to);

        redeemHelper.redeemUSDC(shares, to, minAssets);

        uint256 assetsReceived = USDC.balanceOf(to) - assetBalanceBefore;

        assertLe(minAssets, assetsReceived);
        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, USDC.balanceOf(address(redeemHelper)));
    }

    function testRedeemUSDCFuzz(uint256 assets, address to) external {
        vm.assume(to != address(0));

        assets = bound(assets, 1e6, type(uint40).max);

        deal(USDBC, address(this), assets);

        uint256 shares = vault.deposit(assets, address(this), 1);
        uint256 redeemedAssets = vault.convertToAssets(shares) -
            COMET_ROUNDING_ERROR_MARGIN;
        (, uint256 minAssets) = IRouter(ROUTER).getSwapOutput(
            USDBC_USDC_PAIR,
            redeemedAssets
        );
        uint256 assetBalanceBefore = USDC.balanceOf(to);

        redeemHelper.redeemUSDC(shares, to, minAssets);

        uint256 assetsReceived = USDC.balanceOf(to) - assetBalanceBefore;

        // Account for Comet rounding down and compare against the ETH amount received.
        assertLe(minAssets, assetsReceived);

        assertEq(0, vault.balanceOf(address(redeemHelper)));
        assertEq(0, COMET.balanceOf(address(redeemHelper)));
        assertEq(0, USDC.balanceOf(address(redeemHelper)));
    }
}
