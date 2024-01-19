// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {Helper} from "test/Helper.sol";
import {BrrUSD} from "src/BrrUSD.sol";

contract BrrUSDTest is Helper {
    /*//////////////////////////////////////////////////////////////
                             initialize
    //////////////////////////////////////////////////////////////*/

    function testCannotInitializeInvalidInitialization() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);

        vault.initialize(
            COMET_REWARDS,
            ROUTER,
            INITIAL_REWARD_FEE,
            admin,
            admin
        );
    }

    function testInitialize() external {
        BrrUSD uninitializedVault = BrrUSD(
            // Deploys a new proxy but does not initialize.
            ERC1967_FACTORY.deploy(vaultImplementation, admin)
        );

        assertEq(address(0), address(uninitializedVault.cometRewards()));
        assertEq(address(0), address(uninitializedVault.router()));
        assertEq(0, uninitializedVault.rewardFee());
        assertEq(address(0), uninitializedVault.protocolFeeReceiver());
        assertEq(address(0), uninitializedVault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(uninitializedVault));

        emit Initializable.Initialized(1);

        uninitializedVault.initialize(
            COMET_REWARDS,
            ROUTER,
            INITIAL_REWARD_FEE,
            admin,
            admin
        );

        assertEq(COMET_REWARDS, address(uninitializedVault.cometRewards()));
        assertEq(ROUTER, address(uninitializedVault.router()));
        assertEq(INITIAL_REWARD_FEE, uninitializedVault.rewardFee());
        assertEq(admin, uninitializedVault.protocolFeeReceiver());
        assertEq(admin, uninitializedVault.feeDistributor());

        // Comet must have max allowance for the purposes of supplying WETH for cWETHv3.
        assertEq(
            type(uint256).max,
            ERC20(USDC).allowance(address(vault), COMET)
        );

        assertEq(
            type(uint256).max,
            ERC20(COMP).allowance(address(vault), ROUTER)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             name
    //////////////////////////////////////////////////////////////*/

    function testName() external {
        assertEq(NAME, vault.name());
    }

    /*//////////////////////////////////////////////////////////////
                             symbol
    //////////////////////////////////////////////////////////////*/

    function testSymbol() external {
        assertEq(SYMBOL, vault.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                             asset
    //////////////////////////////////////////////////////////////*/

    function testAsset() external {
        assertEq(COMET, vault.asset());
    }

    /*//////////////////////////////////////////////////////////////
                             depositUSDC
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositUSDCInsufficientSharesMinted() external {
        uint256 amount = 0;
        address to = address(this);
        uint256 minShares = vault.convertToShares(amount) + 1;

        vm.expectRevert(BrrUSD.InsufficientSharesMinted.selector);

        vault.deposit(amount, to, minShares);
    }

    function testDepositUSDC() external {
        uint256 amount = 1e6;
        address to = address(this);
        uint256 minShares = vault.convertToShares(
            amount - COMET_ROUNDING_ERROR_MARGIN
        );
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, amount, 0);

        uint256 shares = vault.deposit(amount, to, minShares);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertLe(minShares, shares);
        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }

    function testDepositUSDCFuzz(
        address msgSender,
        uint80 amount,
        address to
    ) external {
        vm.assume(
            msgSender != address(0) &&
                amount > COMET_ROUNDING_ERROR_MARGIN &&
                to != address(0)
        );

        uint256 minShares = vault.convertToShares(
            amount - COMET_ROUNDING_ERROR_MARGIN
        );
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.startPrank(msgSender);

        deal(USDC, msgSender, amount);
        ERC20(USDC).approve(address(vault), type(uint256).max);

        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(msgSender, to, amount, 0);

        uint256 shares = vault.deposit(amount, to, minShares);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        vm.stopPrank();

        assertLe(minShares, shares);
        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }
}
