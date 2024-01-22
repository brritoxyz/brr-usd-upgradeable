// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Factory} from "solady/utils/ERC1967Factory.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {ICometRewards} from "src/interfaces/ICometRewards.sol";
import {IRouter} from "src/interfaces/IRouter.sol";

/// @title Brrito brrUSD.
/// @author kp (kphed.eth).
/// @notice A yield-bearing USD derivative built on Compound III.
contract BrrUSD is UUPSUpgradeable, Initializable, ERC4626 {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    string private constant _NAME = "Brrito USD";
    string private constant _SYMBOL = "brrUSD";
    address private constant _ASSET =
        0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    uint8 private constant _ASSET_DECIMALS = 6;
    uint256 private constant _FEE_BASE = 10_000;
    address private constant _COMET =
        0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    ERC1967Factory private constant _ERC1967_FACTORY =
        ERC1967Factory(0x0000000000006396FF2a80c067f99B3d2Ab4Df24);

    ICometRewards public cometRewards;

    // The router used to swap rewards for USDC.
    IRouter public router;

    // The default reward fee is 0% and can be increased up to 100% (only for specific use cases).
    uint256 public rewardFee;

    // Receives the protocol's share of reward fees.
    address public protocolFeeReceiver;

    // Receives and distributes the stakedBRR token holder's share of reward fees.
    address public feeDistributor;

    event Harvest(
        address indexed token,
        uint256 rewards,
        uint256 supplyAssets,
        uint256 fees
    );
    event SetCometRewards(address, bool);
    event SetRouter(address);
    event SetRewardFee(uint256);
    event SetProtocolFeeReceiver(address);
    event SetFeeDistributor(address);

    error InsufficientSharesMinted();
    error InsufficientAssetBalance();
    error InvalidCometRewards();
    error InvalidRouter();
    error InvalidRewardFee();
    error InvalidProtocolFeeReceiver();
    error InvalidFeeDistributor();
    error RemovedERC4626Method();

    constructor() {
        _disableInitializers();
    }

    modifier onlyAdmin() {
        if (msg.sender != _ERC1967_FACTORY.adminOf(address(this)))
            revert ERC1967Factory.Unauthorized();

        _;
    }

    function initialize(
        address _cometRewards,
        address _router,
        uint256 _rewardFee,
        address _protocolFeeReceiver,
        address _feeDistributor
    ) external initializer {
        cometRewards = ICometRewards(_cometRewards);
        router = IRouter(_router);
        rewardFee = _rewardFee;
        protocolFeeReceiver = _protocolFeeReceiver;
        feeDistributor = _feeDistributor;
        ICometRewards.RewardConfig memory rewardConfig = cometRewards
            .rewardConfig(_COMET);

        // Enable the router to swap our Comet rewards for USDC.
        rewardConfig.token.safeApproveWithRetry(
            address(router),
            type(uint256).max
        );

        // Enable Comet to transfer our USDC in exchange for cUSDC.
        _ASSET.safeApproveWithRetry(_COMET, type(uint256).max);
    }

    /**
     * @notice ERC20 token name.
     * @return string  Token name.
     */
    function name() public pure override returns (string memory) {
        return _NAME;
    }

    /**
     * @notice ERC20 token symbol.
     * @return string  Token symbol.
     */
    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    /**
     * @notice Underlying ERC20 token asset.
     * @return address  Asset contract address.
     */
    function asset() public pure override returns (address) {
        return _COMET;
    }

    /**
     * @notice Underlying ERC20 token asset decimals.
     * @return uint8  Asset decimals.
     */
    function _underlyingDecimals() internal pure override returns (uint8) {
        return _ASSET_DECIMALS;
    }

    /**
     * @notice Returns the amount of shares that the Vault will exchange for the amount of assets provided,
     *         in an ideal scenario where all conditions are met.
     * @param  assets       uint256  Amount of assets to convert to shares.
     * @param  totalSupply  uint256  Amount of shares in the Vault prior to minting `shares`.
     * @param  totalAssets  uint256  Amount of assets in the Vault prior to transferring in `assets`.
     * @return              uint256  Amount of shares minted in exchange for `assets`.
     */
    function convertToShares(
        uint256 assets,
        uint256 totalSupply,
        uint256 totalAssets
    ) public pure returns (uint256) {
        // Will not realistically overflow since the `totalSupply` and `totalAssets` should never
        // exceed the amount of cUSDC that is deposited or received from compounding rewards.
        unchecked {
            return assets.fullMulDiv(totalSupply + 1, totalAssets + 1);
        }
    }

    /**
     * @notice Mints `shares` and emits the `Deposit` event.
     * @param  by      address  Address that minted the shares.
     * @param  to      address  Address to mint shares to.
     * @param  assets  uint256  Amount of assets deposited.
     * @param  shares  uint256  Amount of shares minted.
     */
    function _deposit(
        address by,
        address to,
        uint256 assets,
        uint256 shares
    ) internal override {
        _mint(to, shares);

        emit Deposit(by, to, assets, shares);
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
        _ASSET.safeTransferFrom(msg.sender, address(this), amount);

        uint256 totalAssetsBefore = totalAssets();

        IComet(_COMET).supply(_ASSET, amount);

        uint256 assets = totalAssets() - totalAssetsBefore;
        shares = convertToShares(assets, totalSupply(), totalAssetsBefore);

        if (shares < minShares) revert InsufficientSharesMinted();

        _deposit(msg.sender, to, assets, shares);
    }

    /**
     * @notice Mints `shares` Vault shares to `to` by depositing exactly `assets` of underlying tokens.
     * @dev    Comet rounds down transfer amounts, which will result in a 1+ wei discrepancy between `assets`
     *         and the actual amount received by the vault. To err on the side of safety, we are using the
     *         actual amount of assets received by the vault when calculating the amount of shares to mint.
     * @param  assets  uint256  Amount of assets to deposit.
     * @param  to      address  Address to mint shares to.
     * @return shares  uint256  Amount of shares minted.
     */
    function deposit(
        uint256 assets,
        address to
    ) public override returns (uint256 shares) {
        // Prevents `msg.sender` from using `type(uint256).max` for `assets` which is Comet's alias for "entire balance".
        if (assets > _COMET.balanceOf(msg.sender))
            revert InsufficientAssetBalance();

        uint256 totalAssetsBefore = totalAssets();

        _COMET.safeTransferFrom(msg.sender, address(this), assets);

        shares = convertToShares(
            // The difference is the exact amount of cUSDC received, after rounding down.
            totalAssets() - totalAssetsBefore,
            totalSupply(),
            totalAssetsBefore
        );

        _deposit(msg.sender, to, assets, shares);
    }

    /// @notice Claim rewards and convert them into the vault asset.
    function harvest() public {}

    /*//////////////////////////////////////////////////////////////
                        PRIVILEGED SETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the Comet Rewards contract.
     * @param  _cometRewards  address  Comet Rewards contract address.
     * @param  shouldHarvest  bool     Whether to call `harvest` before setting `cometRewards`.
     */
    function setCometRewards(
        address _cometRewards,
        bool shouldHarvest
    ) external onlyAdmin {
        if (_cometRewards == address(0)) revert InvalidCometRewards();
        if (shouldHarvest) harvest();

        cometRewards = ICometRewards(_cometRewards);

        emit SetCometRewards(_cometRewards, shouldHarvest);
    }

    /**
     * @notice Set the router contract.
     * @param  _router  address  Router contract address.
     */
    function setRouter(address _router) external onlyAdmin {
        if (_router == address(0)) revert InvalidRouter();

        ICometRewards.RewardConfig memory rewardConfig = cometRewards
            .rewardConfig(_COMET);

        // Revoke the spend allowance from the soon-to-be changed router.
        rewardConfig.token.safeApproveWithRetry(address(router), 0);

        router = IRouter(_router);

        // Enable the new router to swap reward tokens into more USDC.
        rewardConfig.token.safeApproveWithRetry(_router, type(uint256).max);

        emit SetRouter(_router);
    }

    /**
     * @notice Set the reward fee.
     * @param  _rewardFee  uint256  Reward fee.
     */
    function setRewardFee(uint256 _rewardFee) external onlyAdmin {
        if (_rewardFee > _FEE_BASE) revert InvalidRewardFee();

        rewardFee = _rewardFee;

        emit SetRewardFee(_rewardFee);
    }

    /**
     * @notice Set the protocol fee receiver.
     * @param  _protocolFeeReceiver  address  Protocol fee receiver.
     */
    function setProtocolFeeReceiver(
        address _protocolFeeReceiver
    ) external onlyAdmin {
        if (_protocolFeeReceiver == address(0))
            revert InvalidProtocolFeeReceiver();

        protocolFeeReceiver = _protocolFeeReceiver;

        emit SetProtocolFeeReceiver(_protocolFeeReceiver);
    }

    /**
     * @notice Set the fee distributor.
     * @param  _feeDistributor  address  Fee distributor.
     */
    function setFeeDistributor(address _feeDistributor) external onlyAdmin {
        if (_feeDistributor == address(0)) revert InvalidFeeDistributor();

        feeDistributor = _feeDistributor;

        emit SetFeeDistributor(_feeDistributor);
    }

    /*//////////////////////////////////////////////////////////////
                    OVERRIDDEN UUPSUpgradeable METHODS
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal view override onlyAdmin {}

    /*//////////////////////////////////////////////////////////////
                        REMOVED ERC4626 METHODS
    //////////////////////////////////////////////////////////////*/

    function maxMint(address) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function maxWithdraw(address) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function previewMint(uint256) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function previewWithdraw(uint256) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function mint(uint256, address) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }

    function withdraw(
        uint256,
        address,
        address
    ) public pure override returns (uint256) {
        revert RemovedERC4626Method();
    }
}
