// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {BrrUSDC} from "src/BrrUSDC.sol";

contract Helper is Test {
    ERC1967Factory public constant ERC1967_FACTORY =
        ERC1967Factory(0x0000000000006396FF2a80c067f99B3d2Ab4Df24);
    address public constant COMET = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    address public constant COMET_REWARDS =
        0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address public constant ROUTER = 0xafaE5a94e6F1C79D40F5460c47589BAD5c123B9c;
    uint256 public constant INITIAL_REWARD_FEE = 1_000;
    address public constant USDC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address internal constant COMP = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    address public immutable admin = address(this);
    address public immutable vaultImplementation = address(new BrrUSDC());
    BrrUSDC public immutable vault;

    constructor() {
        vault = BrrUSDC(
            ERC1967_FACTORY.deployAndCall(
                vaultImplementation,
                admin,
                abi.encodeWithSelector(
                    BrrUSDC.initialize.selector,
                    COMET_REWARDS,
                    ROUTER,
                    INITIAL_REWARD_FEE,
                    admin,
                    admin
                )
            )
        );
    }
}
