// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ERC1155Vault} from "../../src/Jan06_ERC1155Vault.sol";
// Modified from https://github.com/transmissions11/solmate/blob/main/src/test/utils/mocks/MockERC4626.sol
contract MockERC1155Vault is ERC1155Vault {
    uint256 public beforeWithdrawHookCalledCounter = 0;
    uint256 public afterDepositHookCalledCounter = 0;

    function totalAssets(ERC1155 asset, uint256 tokenId) public view override returns (uint256) {
        return asset.balanceOf(address(this), tokenId);
    }

    function beforeWithdraw(ERC1155, uint256, uint256) internal override {
        beforeWithdrawHookCalledCounter++;
    }

    function afterDeposit(ERC1155, uint256, uint256) internal override {
        afterDepositHookCalledCounter++;
    }
}