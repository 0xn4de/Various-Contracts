


from vyper.interfaces import ERC721

interface ERC721Receiver:
    def onERC721Received(
            _operator: address,
            _from: address,
            _tokenId: uint256,
            _data: Bytes[1024]
        ) -> bytes4: nonpayable

implements: ERC721Receiver

interface ERC6909:
    def transfer(receiver: address, id: uint256, amount: uint256) -> bool: nonpayable
    def transferFrom(sender: address, receiver: address, id: uint256, amount: uint256) -> bool: nonpayable

enum NFT:
    ERC721
    ERC6909
struct Auction:
    finished: bool
    nftType: uint8
    maker: address
    currentBidder: address
    nft: address
    tokenId: uint256
    reserve: uint256
    minRaise: uint256
    buyNow: uint256
    currentBid: uint256
    deadline: uint256

totalAuctions: public(uint256)

auctions: public(HashMap[uint256, Auction])

event AuctionCreated:
    nft: address
    tokenId: uint256
    reserve: uint256
    minRaise: uint256
    buyNow: uint256
    deadline: uint256
event AuctionSettled:
    auctionId: indexed(uint256)
    buyer: indexed(address)
    bidAmount: indexed(uint256)
event Bid:
    auctionId: indexed(uint256)
    bidder: indexed(address)
    bidAmount: indexed(uint256)
event AuctionClosed:
    auctionId: indexed(uint256)


@external
def createAuction(nft: address, tokenId: uint256, nftType: uint8, reserve: uint256, minRaise: uint256, buyNow: uint256, auctionLength: uint256) -> uint256:
    """
    nftType was originally an NFT enum, but since vyper enum != solidity enum (https://jtriley.substack.com/p/the-vyper-compiler)
    had to change implementation to be uint8
    tests still work using the original solidity Enum in function calls, as Solidity enums are just 0,1,2,3 etc
    """
    if buyNow > 0:
        assert reserve < buyNow, "Reserve is too high"
    assert minRaise > 0, "Have to set a minimum raise"
    self.totalAuctions += 1
    if nftType == 0:
        ERC721(nft).safeTransferFrom(msg.sender, self, tokenId, b'')
    else:
        ERC6909(nft).transferFrom(msg.sender, self, tokenId, 1)
    self.auctions[self.totalAuctions] = Auction({
        finished: False, 
        nftType: nftType, 
        maker: msg.sender,
        currentBidder: empty(address),
        nft: nft,
        tokenId: tokenId,
        reserve: reserve,
        minRaise: minRaise,
        buyNow: buyNow,
        currentBid: 0,
        deadline: block.timestamp+auctionLength
    })
    log AuctionCreated(nft, tokenId, reserve, minRaise, buyNow, block.timestamp+auctionLength)
    return self.totalAuctions

@external
@payable
def bid(auctionId: uint256) -> bool:
    auction: Auction = self.auctions[auctionId]
    assert auction.deadline > block.timestamp, "Too late"
    assert not auction.finished, "Auction closed"
    assert msg.value > auction.currentBid+auction.minRaise, "Bid more"

    if auction.currentBidder != empty(address):
        lastBid: uint256 = auction.currentBid
        self.auctions[auctionId].currentBid = 0
        # this should be redesigned to have old bids get sent out through a separate call made by the bidder
        # otherwise someone can make a contract to DoS this & secure their own bid being the winner
        # maybe a check for codehash too but that disallows safes etc
        raw_call(auction.currentBidder, b'', value=lastBid)
    self.auctions[auctionId].currentBidder = msg.sender
    self.auctions[auctionId].currentBid = msg.value

    if msg.value >= auction.buyNow and auction.buyNow != 0:
        self.auctions[auctionId].finished = True
        if auction.nftType == 0:
            ERC721(auction.nft).safeTransferFrom(self, msg.sender, auction.tokenId, b'')
        else:
            ERC6909(auction.nft).transferFrom(self, msg.sender, auction.tokenId, 1)
        raw_call(auction.maker, b'', value=msg.value)
        log AuctionSettled(auctionId, msg.sender, msg.value)
        return True
    return True

@external
def settleAuction(auctionId: uint256):
    auction: Auction = self.auctions[auctionId]
    assert block.timestamp > auction.deadline, "Too early"
    assert not auction.finished, "Auction closed"
    self.auctions[auctionId].finished = True
    lastBid: uint256 = auction.currentBid
    self.auctions[auctionId].currentBid = 0
    if lastBid >= auction.reserve:
        if auction.nftType == 0:
            ERC721(auction.nft).safeTransferFrom(self, auction.currentBidder, auction.tokenId, b'')
        else:
            ERC6909(auction.nft).transfer(auction.currentBidder, auction.tokenId, 1)
        raw_call(auction.maker, b'', value=lastBid)
    else:
        raw_call(auction.currentBidder, b'', value=lastBid)
    log AuctionSettled(auctionId, auction.currentBidder, lastBid)

@external
def cancelAuction(auctionId: uint256):
    auction: Auction = self.auctions[auctionId]
    assert msg.sender == auction.maker, "You are not the creator of the auction"
    assert not auction.finished, "Auction closed"
    self.auctions[auctionId].finished = True
    if auction.nftType == 0:
        ERC721(auction.nft).safeTransferFrom(self, msg.sender, auction.tokenId, b'')
    else:
        ERC6909(auction.nft).transferFrom(self, msg.sender, auction.tokenId, 1)
    
    if auction.currentBidder != empty(address):
        raw_call(auction.currentBidder, b'', value=auction.currentBid)
    log AuctionClosed(auctionId)

@external
def onERC721Received(_operator: address, _from: address, _tokenId: uint256, _data: Bytes[1024]) -> bytes4:
    return method_id("onERC721Received(address,address,uint256,bytes)", output_type=bytes4)
