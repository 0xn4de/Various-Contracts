// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

error MintPriceNotPaid();
error MaxSupply();
error NonExistentTokenURI();
error WithdrawTransfer();

contract FreeForAll is ERC721 {

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
        // Few troubles arise:
        // If it has been more than 24 (but less than 25) hours since the last time someone called transferFrom
        // After the last FFA period, it won't register as being FFA, you will have to call again
        // If it has been over 25 hours, startTime will get set to startTime + 24 hours every time transferFrom is called
        // meaning it will have to be looped over until it's back on track (send NFT from bob to alice, then alice to bob etc)
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
