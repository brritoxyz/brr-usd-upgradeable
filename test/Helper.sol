// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
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
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address public constant COMP = 0x9e1028F5F1D5eDE59748FFceE5532509976840E0;
    string public constant NAME = "Brrito USD";
    string public constant SYMBOL = "brrUSD";
    uint256 internal constant FEE_BASE = 10_000;
    uint256 public constant COMET_ROUNDING_ERROR_MARGIN = 2;
    uint8 public constant USDC_DECIMALS = 6;
    uint8 public constant USDBC_DECIMALS = 6;
    bytes32 public constant USDC_USDBC_PAIR =
        0xdcc50c3ab25d4ef721f614c96012bfb9eb3ae8e7a576e2d2d831fcd947685013;
    bytes32 public constant USDBC_USDC_PAIR =
        0x46553b59eca6ca194c1e37832a44f4e193ac3548d5573b119d62837c673a72aa;
    address public immutable admin = address(this);
    address public immutable vaultImplementation = address(new BrrUSD());
    BrrUSD public immutable vault;
    uint256 public immutable swapFeeDeducted;

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

        swapFeeDeducted = IRouter(ROUTER).feeDeducted();

        deal(USDBC, address(this), 10_000e6);
        USDBC.safeApprove(address(vault), type(uint256).max);
        USDBC.safeApprove(COMET, type(uint256).max);
        COMET.safeApprove(address(vault), type(uint256).max);
    }

    /**
     * @notice Convenient helper for getting the vault (ERC1967 proxy) admin.
     * @return address  Proxy admin.
     */
    function _getVaultProxyAdmin() internal view returns (address) {
        return ERC1967_FACTORY.adminOf(address(vault));
    }
}
