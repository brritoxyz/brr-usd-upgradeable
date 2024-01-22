// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrUSD} from "src/BrrUSD.sol";

contract BrrUSDTest is Helper {
    using SafeTransferLib for address;

    function _getCUSDbC(uint256 amount) internal returns (uint256 balance) {

        console.log("a", COMET.balanceOf(address(this)));

        deal(COMET, address(this), amount);

        balance = COMET.balanceOf(address(this));

        console.log("b", COMET.balanceOf(address(this)));
    }

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

    /*//////////////////////////////////////////////////////////////
                             deposit
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositInsufficientAssetBalance() external {
        uint256 assets = type(uint256).max;
        address to = address(this);

        assertLt(COMET.balanceOf(address(this)), assets);

        vm.expectRevert(BrrUSD.InsufficientAssetBalance.selector);

        vault.deposit(assets, to);
    }

    function testCannotDepositInsufficientAssetBalanceFuzz(
        uint256 assets
    ) external {
        vm.assume(assets != 0);

        address to = address(this);

        assertLt(COMET.balanceOf(address(this)), assets);

        vm.expectRevert(BrrUSD.InsufficientAssetBalance.selector);

        vault.deposit(assets, to);
    }

    // function testDeposit() external {
    //     uint256 assets = _getCWETH(1e18);
    //     address to = address(this);
    //     uint256 totalSupplyBefore = vault.totalSupply();
    //     uint256 totalAssetsBefore = vault.totalAssets();

    //     // Comet rounds down transfer amounts, making it difficult to check the final emitted values.
    //     vm.expectEmit(true, true, true, false, address(vault));

    //     emit ERC4626.Deposit(address(this), to, assets, 0);

    //     uint256 shares = vault.deposit(assets, to);
    //     uint256 totalSupplyAfter = vault.totalSupply();
    //     uint256 totalAssetsAfter = vault.totalAssets();
    //     uint256 expectedShares = vault.convertToShares(
    //         totalAssetsAfter - totalAssetsBefore,
    //         totalSupplyBefore,
    //         totalAssetsBefore
    //     );

    //     assertEq(expectedShares, shares);
    //     assertEq(shares, totalSupplyAfter - totalSupplyBefore);
    //     assertEq(shares, vault.balanceOf(to));
    //     assertLe(totalSupplyAfter, totalAssetsAfter);
    // }

    // function testDepositMultiple() external {
    //     uint256 baseAsset = 0.001 ether;
    //     uint256 totalSupply = 0;
    //     uint256 totalAssets = 0;

    //     for (uint256 i = 0; i < anvilAccounts.length; ++i) {
    //         uint256 asset = _getCWETH(baseAsset * (i + 1));
    //         uint256 totalSupplyBefore = vault.totalSupply();
    //         uint256 totalAssetsBefore = vault.totalAssets();

    //         vm.expectEmit(true, true, true, false, address(vault));

    //         emit ERC4626.Deposit(address(this), anvilAccounts[i], asset, 0);

    //         uint256 shares = vault.deposit(asset, anvilAccounts[i]);
    //         uint256 totalSupplyAfter = vault.totalSupply();
    //         uint256 totalAssetsAfter = vault.totalAssets();
    //         uint256 expectedShares = vault.convertToShares(
    //             totalAssetsAfter - totalAssetsBefore,
    //             totalSupplyBefore,
    //             totalAssetsBefore
    //         );
    //         totalSupply += totalSupplyAfter - totalSupplyBefore;
    //         totalAssets += totalAssetsAfter - totalAssetsBefore;

    //         assertLt(0, shares);
    //         assertEq(expectedShares, shares);
    //         assertEq(shares, totalSupplyAfter - totalSupplyBefore);
    //         assertEq(shares, vault.balanceOf(anvilAccounts[i]));
    //         assertLe(totalSupplyAfter, totalAssetsAfter);
    //     }

    //     assertEq(totalSupply, vault.totalSupply());
    //     assertEq(totalAssets, vault.totalAssets());
    // }

    // function testDepositFuzz(uint80 assets, address to) external {
    //     assets = uint80(_getCWETH(assets));
    //     uint256 totalSupplyBefore = vault.totalSupply();
    //     uint256 totalAssetsBefore = vault.totalAssets();

    //     vm.expectEmit(true, true, true, false, address(vault));

    //     emit ERC4626.Deposit(address(this), to, assets, 0);

    //     uint256 shares = vault.deposit(assets, to);
    //     uint256 totalSupplyAfter = vault.totalSupply();
    //     uint256 totalAssetsAfter = vault.totalAssets();
    //     uint256 expectedShares = vault.convertToShares(
    //         totalAssetsAfter - totalAssetsBefore,
    //         totalSupplyBefore,
    //         totalAssetsBefore
    //     );

    //     assertEq(expectedShares, shares);
    //     assertEq(shares, totalSupplyAfter - totalSupplyBefore);
    //     assertEq(shares, vault.balanceOf(to));
    //     assertLe(totalSupplyAfter, totalAssetsAfter);
    // }
}
