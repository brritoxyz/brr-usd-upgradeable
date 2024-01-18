// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {BrrUSDC} from "src/BrrUSDC.sol";

contract Helper is Test {
    ERC1967Factory public constant _ERC1967_FACTORY =
        ERC1967Factory(0x0000000000006396FF2a80c067f99B3d2Ab4Df24);
    address public constant _COMET_REWARDS =
        0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address public constant _ROUTER =
        0xafaE5a94e6F1C79D40F5460c47589BAD5c123B9c;
    uint256 public constant _INITIAL_REWARD_FEE = 1_000;
    address public immutable _admin = address(this);
    address public immutable _vaultImplementation = address(new BrrUSDC());
    BrrUSDC public immutable vault;

    constructor() {
        vault = BrrUSDC(
            _ERC1967_FACTORY.deployAndCall(
                _vaultImplementation,
                _admin,
                abi.encodeWithSelector(
                    BrrUSDC.initialize.selector,
                    _COMET_REWARDS,
                    _ROUTER,
                    _INITIAL_REWARD_FEE,
                    _admin,
                    _admin
                )
            )
        );
    }
}
