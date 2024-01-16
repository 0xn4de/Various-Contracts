// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Jan03_FreeForAll.sol";

contract FreeForAllTest is Test {
    using stdStorage for StdStorage;
    address alice;
    address bob;
    address charlie;

    FreeForAll private nft;

    function setUp() public {
        // Deploy NFT contract
        nft = new FreeForAll("FreeForALL", "FFA");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
    }

    function test_correctStartTime() public {
        assertEq(nft.startTime(), block.timestamp + 1 days);
    }

    function test_ffaNotEnabledTransferRevert() public {
        nft.mintTo(address(bob));
        vm.prank(alice);
        // Expect revert as FFA not enabled and alice isn't approved
        vm.expectRevert("NOT_AUTHORIZED");
        nft.transferFrom(bob, alice, 1);
    }
    function test_ffaEnabledTransfer() public {
        nft.mintTo(address(bob));
        vm.warp(block.timestamp + 1 days + 1 seconds); // Go to where FFA is enabled
        vm.prank(alice);
        nft.transferFrom(bob, alice, 1);
        assertEq(nft.ownerOf(1), alice);
    }
    function test_ffaStartTimeChange() public {
        uint256 beforeStartTime = nft.startTime();
        nft.mintTo(address(bob));
        vm.warp(block.timestamp + 1 days + 1 hours + 1 seconds); // Go to where FFA is disabled
        vm.prank(bob);
        nft.transferFrom(bob, alice, 1);
        assertEq(nft.startTime(), beforeStartTime + 1 days);
    }

    // This test outlines how to get it on track if it has been more than 24 but less than 25 hours since last transferFrom
    // Similar way of getting it done if its over 25 hours, but needs more transferFroms
    function test_newFFAPeriodWithNoTransfers() public {
        uint256 beforeStartTime = nft.startTime();
        nft.mintTo(address(bob));
        vm.warp(block.timestamp + 2 days + 1 seconds); // Go to where FFA is enabled
        vm.prank(bob);
        // Even though it's FFA period right now (24h since last one), startTime is a day behind
        nft.transferFrom(bob, alice, 1); // Sets startTime to right now - 1 second
        uint256 beforeStartTime2 = nft.startTime();
        assertEq(beforeStartTime + 1 days, beforeStartTime2);
        nft.transferFrom(alice, bob, 1); // Bob can take his nft back because FFA is on
    }


    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      MINT/OTHER TESTS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    // Taken from https://book.getfoundry.sh/tutorials/solmate-nft?highlight=erc721#implement-a-basic-nft    

    function test_RevertMintMaxSupplyReached() public {
        uint256 slot = stdstore
            .target(address(nft))
            .sig("currentTokenId()")
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(10000));
        vm.store(address(nft), loc, mockedCurrentTokenId);
        vm.expectRevert(MaxSupply.selector);
        nft.mintTo(address(1));
    }

    function test_RevertMintToZeroAddress() public {
        vm.expectRevert("INVALID_RECIPIENT");
        nft.mintTo(address(0));
    }

    function test_NewMintOwnerRegistered() public {
        nft.mintTo(address(1));
        uint256 slotOfNewOwner = stdstore
            .target(address(nft))
            .sig(nft.ownerOf.selector)
            .with_key(1)
            .find();

        uint160 ownerOfTokenIdOne = uint160(
            uint256(
                (vm.load(address(nft), bytes32(abi.encode(slotOfNewOwner))))
            )
        );
        assertEq(address(ownerOfTokenIdOne), address(1));
    }

    function test_BalanceIncremented() public {
        nft.mintTo(address(1));
        uint256 slotBalance = stdstore
            .target(address(nft))
            .sig(nft.balanceOf.selector)
            .with_key(address(1))
            .find();

        uint256 balanceFirstMint = uint256(
            vm.load(address(nft), bytes32(slotBalance))
        );
        assertEq(balanceFirstMint, 1);

        nft.mintTo(address(1));
        uint256 balanceSecondMint = uint256(
            vm.load(address(nft), bytes32(slotBalance))
        );
        assertEq(balanceSecondMint, 2);
    }

    function test_SafeContractReceiver() public {
        Receiver receiver = new Receiver();
        nft.mintTo(address(receiver));
        uint256 slotBalance = stdstore
            .target(address(nft))
            .sig(nft.balanceOf.selector)
            .with_key(address(receiver))
            .find();

        uint256 balance = uint256(vm.load(address(nft), bytes32(slotBalance)));
        assertEq(balance, 1);
    }

    function test_RevertUnSafeContractReceiver() public {
        // Adress set to 11, because first 10 addresses are restricted for precompiles
        vm.etch(address(11), bytes("mock code"));
        vm.expectRevert(bytes(""));
        nft.mintTo(address(11));
    }
    function test_tokenURI() public {
        nft.mintTo(address(bob));
        string memory token = nft.tokenURI(1);
        assertEq(token, "1");
    }
    function test_tokenURIRevert() public {
        nft.mintTo(address(bob));
        vm.expectRevert("NOT_MINTED");
        nft.tokenURI(555);
    }
}

contract Receiver is ERC721TokenReceiver {
    function onERC721Received(
        address /* operator */ ,
        address /* from */,
        uint256 /* id */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

