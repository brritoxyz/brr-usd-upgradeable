// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {BrrUSD} from "src/BrrUSD.sol";
import {BrrUSDHelper} from "src/BrrUSDHelper.sol";

contract BrrUSDHelperScript is Script {
    // An existing brrUSD proxy.
    // https://basescan.org/address/0xe5d0481e17e89f99512fbcd1483b0ee8692529ef.
    address private constant _BRR_USD =
        0xe5d0481E17E89f99512FBCd1483b0eE8692529Ef;
    address private constant _ROUTER =
        0xe88483B5901FA3537355C4324ccF92a8d4155260;

    function run() public {
        vm.broadcast(vm.envUint("PRIVATE_KEY"));

        new BrrUSDHelper(_BRR_USD, _ROUTER);
    }
}
