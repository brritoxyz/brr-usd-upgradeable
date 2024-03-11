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
     * @notice Mints `shares` Vault shares to `to` by depositing `assets` received from supplying USDC.
     * @param  amount     uint256  Amount of USDC to deposit.
     * @param  to         address  Address to mint shares to.
     * @param  minShares  uint256  The minimum amount of shares that must be minted.
     * @return shares     uint256  Amount of shares minted.
     */
    function deposit(
        uint256 amount,
        address to,
        uint256 minShares
    ) external returns (uint256 shares) {
        _USDC.safeTransferFrom(msg.sender, address(this), amount);

        (uint256 index, uint256 quote) = router.getSwapOutput(
            keccak256(abi.encodePacked(_USDC, _USDBC)),
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
     * @notice Redeem brrUSD for USDC.
     * @param  shares     uint256  Amount of shares to redeem.
     * @param  to         address  USDC recipient.
     * @param  minAssets  uint256  The minimum amount of assets that must be redeemed.
     */
    function redeem(uint256 shares, address to, uint256 minAssets) external {
        // Claim outstanding rewards and accrue interest prior to redeeming shares.
        brrUSD.harvest();

        // Requires approval from the caller to spend their brrUSD balance.
        brrUSD.redeem(shares, address(this), msg.sender);

        // Comet's alias for an "entire balance" is `type(uint256).max`.
        _COMET.withdraw(_USDBC, type(uint256).max);

        uint256 balance = _USDBC.balanceOf(address(this));

        if (balance < minAssets) revert InsufficientAssetsRedeemed();

        _USDBC.safeTransfer(to, balance);
    }
}
