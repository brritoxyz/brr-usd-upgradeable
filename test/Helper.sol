// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {BrrUSD} from "src/BrrUSD.sol";

contract Helper is Test {
    using SafeTransferLib for address;

    ERC1967Factory public constant ERC1967_FACTORY =
        ERC1967Factory(0x0000000000006396FF2a80c067f99B3d2Ab4Df24);
    address public constant COMET = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    address public constant COMET_REWARDS =
        0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address public constant ROUTER = 0xe88483B5901FA3537355C4324ccF92a8d4155260;
    uint256 public constant INITIAL_REWARD_FEE = 1_000;
    address public constant USDC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public constant COMP = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    string public constant NAME = "Brrito USD";
    string public constant SYMBOL = "brrUSD";
    uint256 public constant COMET_ROUNDING_ERROR_MARGIN = 2;
    address public immutable admin = address(this);
    address public immutable vaultImplementation = address(new BrrUSD());
    BrrUSD public immutable vault;

    constructor() {
        vault = BrrUSD(
            ERC1967_FACTORY.deployAndCall(
                vaultImplementation,
                admin,
                abi.encodeWithSelector(
                    BrrUSD.initialize.selector,
                    COMET_REWARDS,
                    ROUTER,
                    INITIAL_REWARD_FEE,
                    admin,
                    admin
                )
            )
        );

        deal(USDC, address(this), 10_000e6);
        USDC.safeApprove(address(vault), type(uint256).max);
        USDC.safeApprove(COMET, type(uint256).max);
        COMET.safeApprove(address(vault), type(uint256).max);
    }
}
