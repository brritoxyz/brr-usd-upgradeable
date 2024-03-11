// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IBrrUSD} from "src/interfaces/IBrrUSD.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

contract BrrUSDHelper {
    using SafeTransferLib for address;

    IComet private constant _COMET =
        IComet(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf);
    address private constant _USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address private constant _USDBC =
        0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;

    // keccak256(abi.encodePacked(_USDC, _USDBC)).
    bytes32 private constant _USDC_USDBC_PAIR =
        0xdcc50c3ab25d4ef721f614c96012bfb9eb3ae8e7a576e2d2d831fcd947685013;

    // keccak256(abi.encodePacked(_USDBC, _USDC)).
    bytes32 private constant _USDBC_USDC_PAIR =
        0x46553b59eca6ca194c1e37832a44f4e193ac3548d5573b119d62837c673a72aa;

    IBrrUSD public immutable brrUSD;
    IRouter public immutable router;

    error InsufficientAssetsRedeemed();

    receive() external payable {}

    constructor(address _brrUSD, address _router) {
        brrUSD = IBrrUSD(_brrUSD);
        router = IRouter(_router);

        // Approve token spend allowances for converting to and from USDC/USDBC when depositing or withdrawing.
        _USDC.safeApprove(_router, type(uint256).max);
        _USDBC.safeApprove(_router, type(uint256).max);
        _USDBC.safeApprove(_brrUSD, type(uint256).max);
    }

    /**
     * @notice Deposits USDC for brrUSD shares.
     * @param  amount     uint256  Amount of USDC to deposit.
     * @param  to         address  Address to mint shares to.
     * @param  minShares  uint256  The minimum amount of shares that must be minted.
     * @return            uint256  Amount of shares minted.
     */
    function depositUSDC(
        uint256 amount,
        address to,
        uint256 minShares
    ) external returns (uint256) {
        _USDC.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 index, uint256 quote) = router.getSwapOutput(
            _USDC_USDBC_PAIR,
            amount
        );

        // Convert USDC to USDbC, which can then be deposited into the brrUSD contract.
        uint256 depositAssets = router.swap(
            _USDC,
            _USDBC,
            amount,
            quote,
            index,
            address(0)
        );

        return brrUSD.deposit(depositAssets, to, minShares);
    }

    /**
     * @notice Redeems brrUSD shares for USDbC and returns the balance.
     * @param  shares  uint256  Amount of shares to redeem.
     * @return         uint256  Amount of USDbC redeemed.
     */
    function _redeem(uint256 shares) private returns (uint256) {
        // Claim outstanding rewards and accrue interest prior to redeeming shares.
        brrUSD.harvest();

        // Requires approval from the caller to spend their brrUSD balance.
        brrUSD.redeem(shares, address(this), msg.sender);

        // Comet's alias for an "entire balance" is `type(uint256).max`.
        _COMET.withdraw(_USDBC, type(uint256).max);

        return _USDBC.balanceOf(address(this));
    }

    /**
     * @notice Redeem brrUSD for USDBC.
     * @param  shares     uint256  Amount of shares to redeem.
     * @param  to         address  USDBC recipient.
     * @param  minAssets  uint256  The minimum amount of assets that must be redeemed.
     */
    function redeem(uint256 shares, address to, uint256 minAssets) external {
        uint256 redeemedAssets = _redeem(shares);

        if (redeemedAssets < minAssets) revert InsufficientAssetsRedeemed();

        _USDBC.safeTransfer(to, redeemedAssets);
    }

    /**
     * @notice Redeem brrUSD for USDC.
     * @param  shares     uint256  Amount of shares to redeem.
     * @param  to         address  USDC recipient.
     * @param  minAssets  uint256  The minimum amount of assets that must be redeemed.
     */
    function redeemUSDC(
        uint256 shares,
        address to,
        uint256 minAssets
    ) external {
        uint256 redeemedAssets = _redeem(shares);
        (uint256 index, uint256 quote) = router.getSwapOutput(
            _USDBC_USDC_PAIR,
            redeemedAssets
        );

        // Convert the USDbC redeemed from shares into USDC.
        uint256 convertedAssets = router.swap(
            _USDC,
            _USDBC,
            redeemedAssets,
            quote,
            index,
            address(0)
        );

        if (convertedAssets < minAssets) revert InsufficientAssetsRedeemed();

        _USDC.safeTransfer(to, convertedAssets);
    }
}
