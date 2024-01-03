// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

error MintPriceNotPaid();
error MaxSupply();
error NonExistentTokenURI();
error WithdrawTransfer();

contract NFT is ERC721, Ownable {

    using Strings for uint256;
    uint256 public currentTokenId;
    uint256 public constant TOTAL_SUPPLY = 10_000;
    uint256 public startTime;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        startTime = block.timestamp + 1 days;
    }

    function mintTo(address recipient) public returns (uint256) {
        uint256 newTokenId = ++currentTokenId;
        if (newTokenId > TOTAL_SUPPLY) {
            revert MaxSupply();
        }
        _safeMint(recipient, newTokenId);
        return newTokenId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (ownerOf(tokenId) == address(0)) {
            revert NonExistentTokenURI();
        }
        return Strings.toString(tokenId);
    }
    function transferFrom(address from, address to, uint256 id) public virtual override {
        if (block.timestamp < startTime + 1 hours && block.timestamp > startTime) {
            // Impl. lifted from https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol#L98-#L106
            require(from == _ownerOf[id], "WRONG_FROM");
            unchecked {
                _balanceOf[from]--;

                _balanceOf[to]++;
            }
            _ownerOf[id] = to;
            delete getApproved[id];
        } else {
            startTime = block.timestamp > startTime + 1 hours ? startTime + 1 days : startTime;
            super.transferFrom(from, to, id);
        }
    }
}
