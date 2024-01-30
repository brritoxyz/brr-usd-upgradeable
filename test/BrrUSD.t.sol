// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrUSD} from "src/BrrUSD.sol";
import {IComet} from "src/interfaces/IComet.sol";

contract BrrUSDTest is Helper {
    using SafeTransferLib for address;

    address[10] public anvilAccounts = [
        address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
        address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
        address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC),
        address(0x90F79bf6EB2c4f870365E785982E1f101E93b906),
        address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65),
        address(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc),
        address(0x976EA74026E726554dB657fA54763abd0C3a0aa9),
        address(0x14dC79964da2C08b23698B3D3cc7Ca32193d9955),
        address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f),
        address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720)
    ];

    function _getCUSDbC(uint256 amount) internal returns (uint256 balance) {
        balance = COMET.balanceOf(address(this));

        deal(ASSET, address(this), amount);
        IComet(COMET).supply(ASSET, amount);

        balance = COMET.balanceOf(address(this)) - balance;
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

        // Comet must have max allowance for the purposes of supplying USDC for the cToken.
        assertEq(
            type(uint256).max,
            ERC20(ASSET).allowance(address(vault), COMET)
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
                             deposit (direct)
    //////////////////////////////////////////////////////////////*/

    function testCannotDepositDirectInsufficientSharesMinted() external {
        uint256 amount = 0;
        address to = address(this);
        uint256 minShares = vault.convertToShares(amount) + 1;

        vm.expectRevert(BrrUSD.InsufficientSharesMinted.selector);

        vault.deposit(amount, to, minShares);
    }

    function testDepositDirect() external {
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

    function testDepositDirectFuzz(
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

        deal(ASSET, msgSender, amount);
        ERC20(ASSET).approve(address(vault), type(uint256).max);

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

    function testDeposit() external {
        uint256 assets = _getCUSDbC(1e6);
        address to = address(this);
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        // Comet rounds down transfer amounts, making it difficult to check the final emitted values.
        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit(assets, to);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }

    function testDepositMultiple() external {
        uint256 baseAsset = 100e6;
        uint256 totalSupply = 0;
        uint256 totalAssets = 0;

        for (uint256 i = 0; i < anvilAccounts.length; ++i) {
            uint256 asset = _getCUSDbC(baseAsset * (i + 1));
            uint256 totalSupplyBefore = vault.totalSupply();
            uint256 totalAssetsBefore = vault.totalAssets();

            vm.expectEmit(true, true, true, false, address(vault));

            emit ERC4626.Deposit(address(this), anvilAccounts[i], asset, 0);

            uint256 shares = vault.deposit(asset, anvilAccounts[i]);
            uint256 totalSupplyAfter = vault.totalSupply();
            uint256 totalAssetsAfter = vault.totalAssets();
            uint256 expectedShares = vault.convertToShares(
                totalAssetsAfter - totalAssetsBefore,
                totalSupplyBefore,
                totalAssetsBefore
            );
            totalSupply += totalSupplyAfter - totalSupplyBefore;
            totalAssets += totalAssetsAfter - totalAssetsBefore;

            assertLt(0, shares);
            assertEq(expectedShares, shares);
            assertEq(shares, totalSupplyAfter - totalSupplyBefore);
            assertEq(shares, vault.balanceOf(anvilAccounts[i]));
            assertLe(totalSupplyAfter, totalAssetsAfter);
        }

        assertEq(totalSupply, vault.totalSupply());
        assertEq(totalAssets, vault.totalAssets());
    }

    function testDepositFuzz(uint40 assets, address to) external {
        assets = uint40(_getCUSDbC(assets));
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.expectEmit(true, true, true, false, address(vault));

        emit ERC4626.Deposit(address(this), to, assets, 0);

        uint256 shares = vault.deposit(assets, to);
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 expectedShares = vault.convertToShares(
            totalAssetsAfter - totalAssetsBefore,
            totalSupplyBefore,
            totalAssetsBefore
        );

        assertEq(expectedShares, shares);
        assertEq(shares, totalSupplyAfter - totalSupplyBefore);
        assertEq(shares, vault.balanceOf(to));
        assertLe(totalSupplyAfter, totalAssetsAfter);
    }
}
