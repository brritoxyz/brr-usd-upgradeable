// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrUSDv2} from "src/BrrUSDv2.sol";
import {BrrUSDv2Helper} from "src/BrrUSDv2Helper.sol";

contract BrrUSDv2Script is Script {
    using SafeTransferLib for address;

    ERC1967Factory public constant ERC1967_FACTORY =
        ERC1967Factory(0x0000000000006396FF2a80c067f99B3d2Ab4Df24);
    address public constant COMET = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
    address public constant COMET_REWARDS =
        0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address public constant ASSET = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant ROUTER = 0xe88483B5901FA3537355C4324ccF92a8d4155260;
    uint256 public constant INITIAL_REWARD_FEE = 0;
    uint256 public constant COMET_ROUNDING_ERROR_MARGIN = 2;
    address public constant MULTISIG =
        0x50e79ccb185354A6A95dB4AeB898A1888A466630;
    address public constant PROTOCOL_FEE_RECEIVER =
        0x8Fcc36CCa8dE6E5d6c44d4de5F8fbCa86742e0af;
    address public constant FEE_DISTRIBUTOR =
        0x8Fcc36CCa8dE6E5d6c44d4de5F8fbCa86742e0af;
    uint256 public constant INITIAL_DEPOSIT_AMOUNT = 1_000e6;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        address deployer = vm.envAddress("OWNER");
        address vaultImplementation = address(new BrrUSDv2());
        BrrUSDv2 vault = BrrUSDv2(
            ERC1967_FACTORY.deployAndCall(
                vaultImplementation,
                MULTISIG,
                abi.encodeWithSelector(
                    BrrUSDv2.initialize.selector,
                    COMET_REWARDS,
                    ROUTER,
                    INITIAL_REWARD_FEE,
                    PROTOCOL_FEE_RECEIVER,
                    FEE_DISTRIBUTOR
                )
            )
        );

        // Deploy the new helper contract for redemptions.
        new BrrUSDv2Helper(address(vault));

        ASSET.safeApprove(address(vault), type(uint256).max);
        vault.deposit(
            INITIAL_DEPOSIT_AMOUNT,
            deployer,
            INITIAL_DEPOSIT_AMOUNT - COMET_ROUNDING_ERROR_MARGIN
        );

        vm.stopBroadcast();
    }
}
