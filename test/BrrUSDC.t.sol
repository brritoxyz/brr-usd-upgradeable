// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {Helper} from "test/Helper.sol";
import {BrrUSDC} from "src/BrrUSDC.sol";

contract BrrUSDCTest is Helper {
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
        BrrUSDC uninitializedVault = BrrUSDC(
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
}
