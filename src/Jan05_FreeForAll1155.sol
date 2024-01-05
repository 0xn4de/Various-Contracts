// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "solmate/tokens/ERC1155.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract FreeForAll1155 is ERC1155 {

    using Strings for uint256;
    uint256 public startTime;
    uint256[] totalSupplies = [100, 100, 100];
    uint256[] mintedSupplies = [0,0,0];

    constructor() {
        startTime = block.timestamp + 1 days;
    }

    function mintTo(address recipient, uint256 id) public returns (bool) {
        require(id <= totalSupplies.length, "ID does not exist");
        require(mintedSupplies[id]+1 <= totalSupplies[id], "No supply available");
        mintedSupplies[id]++;
        _mint(recipient, id, 1, "");
        return true;
    }

    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return Strings.toString(id);
    }
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) public virtual override {
        // Few troubles arise:
        // If it has been more than 24 (but less than 25) hours since the last time someone called transferFrom
        // After the last FFA period, it won't register as being FFA, you will have to call again
        // If it has been over 25 hours, startTime will get set to startTime + 24 hours every time transferFrom is called
        // meaning it will have to be looped over until it's back on track (send NFT from bob to alice, then alice to bob etc)
        if (block.timestamp < startTime + 1 hours && block.timestamp > startTime) {
            balanceOf[from][id] -= amount;
            balanceOf[to][id] += amount;
            emit TransferSingle(msg.sender, from, to, id, amount);
            require(
                to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else {
            startTime = block.timestamp > startTime + 1 hours ? startTime + 1 days : startTime;
            super.safeTransferFrom(from, to, id, amount, data);
        }
    }
}
