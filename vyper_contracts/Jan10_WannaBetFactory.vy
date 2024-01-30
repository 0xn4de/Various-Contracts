interface FeedRegistryInterface:
    def latestRoundData(base: address, quote: address) -> (uint256, int256, uint256, uint256, uint256): view
    def getFeed(base: address, quote: address) -> address: view
interface WannaBetV2:
    def initialize(_base: address, _quote: address, _registry: FeedRegistryInterface): nonpayable
feedRegistry: immutable(FeedRegistryInterface)
baseWannaBetV2: immutable(address)
pools: public(HashMap[address, HashMap[address, address]])

@external
def __init__(_feedRegistry: address, _baseWannaBetV2: address):
    feedRegistry = FeedRegistryInterface(_feedRegistry)
    baseWannaBetV2 = _baseWannaBetV2

@external
def deploy(base: address, quote: address) -> address:
    assert self.pools[base][quote] == empty(address), "Pool already deployed"
    feedRegistry.getFeed(base, quote) # will revert if feed does not exist
    pool: address = create_copy_of(baseWannaBetV2)
    WannaBetV2(pool).initialize(base, quote, feedRegistry)
    self.pools[base][quote] = pool
    return pool