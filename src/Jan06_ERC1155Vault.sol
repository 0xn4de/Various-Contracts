// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
/// @notice Minimal ERC4626-style tokenized Vault implementation with ERC1155 accounting.
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol)
abstract contract ERC1155Vault is ERC1155, ERC1155TokenReceiver {
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Create(ERC1155 indexed asset, uint256 tokenId, uint256 id);

    event Deposit(
        address indexed caller, 
        address indexed owner, 
        ERC1155 indexed asset,
        uint256 tokenId, 
        uint256 assets, 
        uint256 shares
    );

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        ERC1155 asset,
        uint256 tokenId,
        uint256 assets,
        uint256 shares
    );
    function uri(uint256 tokenId) public view virtual override returns (string memory) {}

    /*///////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(ERC1155 => mapping(uint256 => Vault)) public vaults;

    struct Vault {
        uint256 id;
        uint256 totalSupply;
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function create(ERC1155 asset, uint256 tokenId) public virtual returns (uint256 id) {
        require(vaults[asset][tokenId].id == 0, "CREATED");
        
        // cannot overflow on human timescales
        unchecked {
            id = ++totalSupply;
        }

        vaults[asset][tokenId].id = id;

        emit Create(asset, tokenId, id);
    }

    // should be possible to make depositing for multiple tokenId vaults possible, deciding not to
    function deposit(
        ERC1155 asset,
        uint256 tokenId, 
        uint256 assets, 
        address receiver
    ) public virtual returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(asset, tokenId, assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), tokenId, assets, "");

        _mint(receiver, vaults[asset][tokenId].id, shares, "");

        vaults[asset][tokenId].totalSupply += shares;

        emit Deposit(msg.sender, receiver, asset, tokenId, assets, shares);

        afterDeposit(asset, assets, shares);
    }

    function mint(
        ERC1155 asset,
        uint256 tokenId,
        uint256 shares, 
        address receiver
    ) public virtual returns (uint256 assets) {
        assets = previewMint(asset, tokenId, shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), tokenId, assets, "");

        _mint(receiver, vaults[asset][tokenId].id, shares, "");

        vaults[asset][tokenId].totalSupply += shares;

        emit Deposit(msg.sender, receiver, asset, tokenId, assets, shares);

        afterDeposit(asset, assets, shares);
    }

    function withdraw(
        ERC1155 asset,
        uint256 tokenId,
        uint256 assets,
        address receiver,
        address owner,
        bytes calldata data // to comply with ERC-1155 Token Receiver
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(asset, tokenId, assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) require(isApprovedForAll[owner][msg.sender], "NOT_OPERATOR");

        beforeWithdraw(asset, assets, shares);

        _burn(owner, vaults[asset][tokenId].id, shares);

        vaults[asset][tokenId].totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, asset, tokenId, assets, shares);
        asset.safeTransferFrom(address(this), receiver, tokenId, assets, data);
    }

    function redeem(
        ERC1155 asset,
        uint256 tokenId,
        uint256 shares,
        address receiver,
        address owner,
        bytes calldata data
    ) public virtual returns (uint256 assets) {
        if (msg.sender != owner) require(isApprovedForAll[owner][msg.sender], "NOT_OPERATOR");

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(asset, tokenId, shares)) != 0, "ZERO_ASSETS");
        
        beforeWithdraw(asset, assets, shares);
        
        _burn(owner, vaults[asset][tokenId].id, shares);

        vaults[asset][tokenId].totalSupply -= shares;

        emit Withdraw(msg.sender, receiver, owner, asset, tokenId, assets, shares);
        asset.safeTransferFrom(address(this), receiver, tokenId, assets, data);
    }

    /*///////////////////////////////////////////////////////////////
                           ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets(ERC1155 asset, uint256 tokenId) public view virtual returns (uint256);

    function convertToShares(ERC1155 asset, uint256 tokenId, uint256 assets) public view virtual returns (uint256) {
        uint256 supply = vaults[asset][tokenId].totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets(asset, tokenId));
    }

    function convertToAssets(ERC1155 asset, uint256 tokenId, uint256 shares) public view virtual returns (uint256) {
        uint256 supply = vaults[asset][tokenId].totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(asset, tokenId), supply);
    }

    function previewDeposit(ERC1155 asset, uint256 tokenId, uint256 assets) public view virtual returns (uint256) {
        return convertToShares(asset, tokenId, assets);
    }

    function previewMint(ERC1155 asset, uint256 tokenId, uint256 shares) public view virtual returns (uint256) {
        uint256 supply = vaults[asset][tokenId].totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(asset, tokenId), supply);
    }

    function previewWithdraw(ERC1155 asset, uint256 tokenId, uint256 assets) public view virtual returns (uint256) {
        uint256 supply = vaults[asset][tokenId].totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets(asset, tokenId));
    }

    function previewRedeem(ERC1155 asset, uint256 tokenId, uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(asset, tokenId, shares);
    }

    /*///////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(ERC1155 asset, uint256 tokenId, address owner) public view virtual returns (uint256) {
        return convertToAssets(asset, tokenId, balanceOf[owner][vaults[asset][tokenId].id]);
    }

    function maxRedeem(ERC1155 asset, uint256 tokenId, address owner) public view virtual returns (uint256) {
        return balanceOf[owner][vaults[asset][tokenId].id];
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(ERC1155 asset, uint256 assets, uint256 shares) internal virtual {}

    function afterDeposit(ERC1155 asset, uint256 assets, uint256 shares) internal virtual {}
}