// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Helper} from "test/Helper.sol";
import {BrrUSD} from "src/BrrUSD.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrUSDTest is Helper {
    using FixedPointMathLib for uint256;
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

    function _getAsset(uint256 amount) internal returns (uint256 balance) {
        balance = COMET.balanceOf(address(this));

        deal(ASSET, address(this), amount);
        IComet(COMET).supply(ASSET, amount);

        balance = COMET.balanceOf(address(this)) - balance;
    }

    function _calculateFees(
        uint256 amount
    )
        internal
        view
        returns (
            uint256 protocolFeeReceiverShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        )
    {
        uint256 rewardFee = vault.rewardFee();
        uint256 rewardFeeShare = amount.mulDiv(rewardFee, FEE_BASE);
        uint256 preFeeAmount = amount.mulDiv(FEE_BASE, SWAP_FEE_DEDUCTED);
        protocolFeeReceiverShare = rewardFeeShare / 2;
        feeDistributorShare = rewardFeeShare - protocolFeeReceiverShare;
        feeDistributorSwapFeeShare =
            (preFeeAmount - preFeeAmount.mulDiv(SWAP_FEE_DEDUCTED, FEE_BASE)) /
            2;
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
        uint256 assets = _getAsset(1e6);
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
            uint256 asset = _getAsset(baseAsset * (i + 1));
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
        assets = uint40(_getAsset(assets));
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

    /*//////////////////////////////////////////////////////////////
                             harvest
    //////////////////////////////////////////////////////////////*/

    function testHarvest() external {
        uint256 assets = 1_000e6;
        uint256 accrualTime = 1 days;

        _getAsset(assets);

        // Reassign `assets` since Comet rounds down 1.
        assets = COMET.balanceOf(address(this));

        vault.deposit(assets, address(this));

        skip(accrualTime);

        IComet(COMET).accrueAccount(address(vault));

        IComet.UserBasic memory userBasic = IComet(COMET).userBasic(
            address(vault)
        );
        uint256 rewards = userBasic.baseTrackingAccrued * 1e12;
        (, uint256 quote) = IRouter(ROUTER).getSwapOutput(
            keccak256(abi.encodePacked(COMP, ASSET)),
            rewards
        );
        (
            uint256 protocolFeeReceiverShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        ) = _calculateFees(quote);
        quote -= protocolFeeReceiverShare + feeDistributorShare;
        uint256 newAssets = quote - 1;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 protocolFeeReceiverBalance = ASSET.balanceOf(
            vault.protocolFeeReceiver()
        );

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.Harvest(
            COMP,
            rewards,
            quote,
            protocolFeeReceiverShare + feeDistributorShare
        );

        vault.harvest();

        assertEq(totalAssets + newAssets, vault.totalAssets());
        assertEq(totalSupply, vault.totalSupply());
        assertEq(
            protocolFeeReceiverBalance +
                protocolFeeReceiverShare +
                feeDistributorShare +
                feeDistributorSwapFeeShare,
            ASSET.balanceOf(_getVaultProxyAdmin())
        );
    }

    function testHarvestFuzz(
        uint40 assets,
        uint24 accrualTime,
        bool setFeeDistributor
    ) external {
        vm.assume(assets > 1_000e6 && accrualTime > 100);

        // Randomly set the fee distributor to test proper fee distribution across two different accounts.
        if (setFeeDistributor) vault.setFeeDistributor(address(0xbeef));

        _getAsset(assets);

        assets = uint40(COMET.balanceOf(address(this)));

        vault.deposit(assets, address(this));

        skip(accrualTime);

        IComet(COMET).accrueAccount(address(vault));

        IComet.UserBasic memory userBasic = IComet(COMET).userBasic(
            address(vault)
        );
        uint256 rewards = uint256(userBasic.baseTrackingAccrued) * 1e12;

        if (rewards == 0) return;

        (, uint256 quote) = IRouter(ROUTER).getSwapOutput(
            keccak256(abi.encodePacked(COMP, ASSET)),
            rewards
        );
        (
            uint256 protocolFeeReceiverShare,
            uint256 feeDistributorShare,
            uint256 feeDistributorSwapFeeShare
        ) = _calculateFees(quote);
        quote -= protocolFeeReceiverShare + feeDistributorShare;
        uint256 newAssets = quote - 5;
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        uint256 protocolFeeReceiverBalance = ASSET.balanceOf(
            vault.protocolFeeReceiver()
        );
        uint256 feeDistributorBalance = ASSET.balanceOf(vault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.Harvest(
            COMP,
            rewards,
            quote,
            protocolFeeReceiverShare + feeDistributorShare
        );

        vault.harvest();

        assertLe(totalAssets + newAssets, vault.totalAssets());
        assertEq(totalSupply, vault.totalSupply());

        if (_getVaultProxyAdmin() == vault.feeDistributor()) {
            assertEq(
                protocolFeeReceiverBalance +
                    protocolFeeReceiverShare +
                    feeDistributorShare +
                    feeDistributorSwapFeeShare,
                ASSET.balanceOf(_getVaultProxyAdmin())
            );
        } else {
            assertEq(
                protocolFeeReceiverBalance + protocolFeeReceiverShare,
                ASSET.balanceOf(_getVaultProxyAdmin())
            );
            assertEq(
                feeDistributorBalance +
                    feeDistributorShare +
                    feeDistributorSwapFeeShare,
                ASSET.balanceOf(vault.feeDistributor())
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                             setCometRewards
    //////////////////////////////////////////////////////////////*/

    function testCannotSetCometRewardsUnauthorized() external {
        address msgSender = address(0);
        address cometRewards = address(0xbeef);
        bool shouldHarvest = false;

        assertTrue(msgSender != _getVaultProxyAdmin());

        vm.prank(msgSender);
        vm.expectRevert(ERC1967Factory.Unauthorized.selector);

        vault.setCometRewards(cometRewards, shouldHarvest);
    }

    function testCannotSetCometRewardsInvalidCometRewards() external {
        address cometRewards = address(0);
        bool shouldHarvest = false;

        vm.expectRevert(BrrUSD.InvalidCometRewards.selector);

        vault.setCometRewards(cometRewards, shouldHarvest);
    }

    function testSetCometRewards() external {
        address cometRewards = address(0xbeef);
        bool shouldHarvest = false;

        assertTrue(cometRewards != address(vault.cometRewards()));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetCometRewards(cometRewards, shouldHarvest);

        vault.setCometRewards(cometRewards, shouldHarvest);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    function testSetCometRewardsShouldHarvest() external {
        address cometRewards = address(0xbeef);
        bool shouldHarvest = true;

        assertTrue(cometRewards != address(vault.cometRewards()));

        // Deposit and accrue enough time to ensure `harvest` is called (i.e. emits `Harvest` event).
        vault.deposit(1_000e6, address(this), 1);

        skip(1 days);

        // Event members are unchecked, we just need to know that `harvest` was called.
        vm.expectEmit(false, false, false, false, address(vault));

        emit BrrUSD.Harvest(COMP, 0, 0, 0);

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetCometRewards(cometRewards, shouldHarvest);

        vault.setCometRewards(cometRewards, shouldHarvest);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    function testSetCometRewardsFuzz(
        address cometRewards,
        bool shouldHarvest
    ) external {
        vm.assume(
            cometRewards != address(0) &&
                cometRewards != address(vault.cometRewards())
        );

        assertTrue(cometRewards != address(vault.cometRewards()));

        if (shouldHarvest) {
            vault.deposit(1_000e6, address(this), 1);

            skip(1 days);

            vm.expectEmit(false, false, false, false, address(vault));

            emit BrrUSD.Harvest(COMP, 0, 0, 0);
        }

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetCometRewards(cometRewards, shouldHarvest);

        vault.setCometRewards(cometRewards, shouldHarvest);

        assertEq(cometRewards, address(vault.cometRewards()));
    }

    /*//////////////////////////////////////////////////////////////
                             setRouter
    //////////////////////////////////////////////////////////////*/

    function testCannotSetRouterUnauthorized() external {
        address msgSender = address(0);
        address router = address(0xbeef);

        assertTrue(msgSender != _getVaultProxyAdmin());

        vm.prank(msgSender);
        vm.expectRevert(ERC1967Factory.Unauthorized.selector);

        vault.setRouter(router);
    }

    function testCannotSetRouterInvalidCometRewards() external {
        address router = address(0);

        vm.expectRevert(BrrUSD.InvalidRouter.selector);

        vault.setRouter(router);
    }

    function testSetRouter() external {
        ICometRewards.RewardConfig memory rewardConfig = ICometRewards(
            COMET_REWARDS
        ).rewardConfig(COMET);
        ERC20 rewardToken = ERC20(rewardConfig.token);
        address router = address(0xbeef);

        assertTrue(router != ROUTER);
        assertEq(0, rewardToken.allowance(address(vault), router));
        assertEq(
            type(uint256).max,
            rewardToken.allowance(address(vault), ROUTER)
        );

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetRouter(router);

        vault.setRouter(router);

        assertEq(router, address(vault.router()));
        assertEq(
            type(uint256).max,
            rewardToken.allowance(address(vault), router)
        );
        assertEq(0, rewardToken.allowance(address(vault), ROUTER));
    }

    function testSetRouterFuzz(address router) external {
        vm.assume(router != address(0) && router != ROUTER);

        ICometRewards.RewardConfig memory rewardConfig = ICometRewards(
            COMET_REWARDS
        ).rewardConfig(COMET);
        ERC20 rewardToken = ERC20(rewardConfig.token);

        assertEq(0, rewardToken.allowance(address(vault), router));

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetRouter(router);

        vault.setRouter(router);

        assertEq(router, address(vault.router()));
        assertEq(
            type(uint256).max,
            rewardToken.allowance(address(vault), router)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             setRewardFee
    //////////////////////////////////////////////////////////////*/

    function testCannotSetRewardFeeUnauthorized() external {
        address msgSender = address(0);
        uint256 rewardFee = 0;

        assertTrue(msgSender != _getVaultProxyAdmin());

        vm.prank(msgSender);
        vm.expectRevert(ERC1967Factory.Unauthorized.selector);

        vault.setRewardFee(rewardFee);
    }

    function testCannotSetRewardFeeInvalidRewardFee() external {
        uint256 rewardFee = FEE_BASE + 1;

        vm.expectRevert(BrrUSD.InvalidRewardFee.selector);

        vault.setRewardFee(rewardFee);
    }

    function testCannotSetRewardFeeInvalidRewardFeeFuzz(
        uint256 rewardFee
    ) external {
        vm.assume(rewardFee > FEE_BASE);
        vm.expectRevert(BrrUSD.InvalidRewardFee.selector);

        vault.setRewardFee(rewardFee);
    }

    function testSetRewardFee() external {
        uint256 rewardFee = 0;

        assertTrue(rewardFee != vault.rewardFee());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetRewardFee(rewardFee);

        vault.setRewardFee(rewardFee);

        assertEq(rewardFee, vault.rewardFee());
    }

    function testSetRewardFeeFuzz(uint16 rewardFee) external {
        vm.assume(rewardFee <= FEE_BASE);
        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetRewardFee(rewardFee);

        vault.setRewardFee(rewardFee);

        assertEq(rewardFee, vault.rewardFee());
    }

    /*//////////////////////////////////////////////////////////////
                             setProtocolFeeReceiver
    //////////////////////////////////////////////////////////////*/

    function testCannotSetProtocolFeeReceiverUnauthorized() external {
        address msgSender = address(0);
        address protocolFeeReceiver = address(0xbeef);

        assertTrue(msgSender != _getVaultProxyAdmin());

        vm.prank(msgSender);
        vm.expectRevert(ERC1967Factory.Unauthorized.selector);

        vault.setProtocolFeeReceiver(protocolFeeReceiver);
    }

    function testCannotSetProtocolFeeReceiverInvalidProtocolFeeReceiver()
        external
    {
        address msgSender = _getVaultProxyAdmin();
        address protocolFeeReceiver = address(0);

        vm.prank(msgSender);
        vm.expectRevert(BrrUSD.InvalidProtocolFeeReceiver.selector);

        vault.setProtocolFeeReceiver(protocolFeeReceiver);
    }

    function testSetProtocolFeeReceiver() external {
        address msgSender = _getVaultProxyAdmin();
        address protocolFeeReceiver = address(0xbeef);

        assertTrue(protocolFeeReceiver != vault.protocolFeeReceiver());

        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetProtocolFeeReceiver(protocolFeeReceiver);

        vault.setProtocolFeeReceiver(protocolFeeReceiver);

        assertEq(protocolFeeReceiver, vault.protocolFeeReceiver());
    }

    /*//////////////////////////////////////////////////////////////
                             setFeeDistributor
    //////////////////////////////////////////////////////////////*/

    function testCannotSetFeeDistributorUnauthorized() external {
        address msgSender = address(0);
        address feeDistributor = address(0xbeef);

        assertTrue(msgSender != _getVaultProxyAdmin());

        vm.prank(msgSender);
        vm.expectRevert(ERC1967Factory.Unauthorized.selector);

        vault.setFeeDistributor(feeDistributor);
    }

    function testCannotSetFeeDistributorInvalidFeeDistributor() external {
        address feeDistributor = address(0);

        vm.expectRevert(BrrUSD.InvalidFeeDistributor.selector);

        vault.setFeeDistributor(feeDistributor);
    }

    function testSetFeeDistributor() external {
        address feeDistributor = address(0xbeef);

        assertTrue(feeDistributor != vault.feeDistributor());

        vm.expectEmit(true, true, true, true, address(vault));

        emit BrrUSD.SetFeeDistributor(feeDistributor);

        vault.setFeeDistributor(feeDistributor);

        assertEq(feeDistributor, vault.feeDistributor());
    }

    /*//////////////////////////////////////////////////////////////
                    Removed ERC4626 methods
    //////////////////////////////////////////////////////////////*/

    function testCannotMaxMintRemovedERC4626Method() external {
        vm.expectRevert(BrrUSD.RemovedERC4626Method.selector);

        vault.maxMint(address(0));
    }

    function testCannotMaxWithdrawRemovedERC4626Method() external {
        vm.expectRevert(BrrUSD.RemovedERC4626Method.selector);

        vault.maxWithdraw(address(0));
    }

    function testCannotPreviewMintRemovedERC4626Method() external {
        vm.expectRevert(BrrUSD.RemovedERC4626Method.selector);

        vault.previewMint(0);
    }

    function testCannotPreviewWithdrawRemovedERC4626Method() external {
        vm.expectRevert(BrrUSD.RemovedERC4626Method.selector);

        vault.previewWithdraw(0);
    }

    function testCannotMintRemovedERC4626Method() external {
        vm.expectRevert(BrrUSD.RemovedERC4626Method.selector);

        vault.mint(0, address(0));
    }

    function testCannotWithdrawRemovedERC4626Method() external {
        vm.expectRevert(BrrUSD.RemovedERC4626Method.selector);

        vault.withdraw(0, address(0), address(0));
    }
}
