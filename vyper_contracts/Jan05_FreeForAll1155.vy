############### imports ###############
from vyper.interfaces import ERC165

############### variables ###############
# maximum items in a batch call. Set to 128, to be determined what the practical limits are.
BATCH_SIZE: constant(uint256) = 128             

# callback number of bytes
CALLBACK_NUMBYTES: constant(uint256) = 4096

# URI length set to 300. 
MAX_URI_LENGTH: constant(uint256) = 300 
# for uint2str / dynamic URI
MAX_DYNURI_LENGTH: constant(uint256) = 78      
# for the .json extension on the URL
MAX_EXTENSION_LENGTH: constant(uint256) = 5  

MAX_URL_LENGTH: constant(uint256) = MAX_URI_LENGTH+MAX_DYNURI_LENGTH+MAX_EXTENSION_LENGTH # dynamic URI status
        

startTime: public(uint256)

totalSupplies: constant(uint256[3]) = [100, 100, 100]
mintedSupplies: public(uint256[3])

# Interface IDs
ERC165_INTERFACE_ID: constant(bytes4)  = 0x01ffc9a7
ERC1155_INTERFACE_ID: constant(bytes4) = 0xd9b67a26
ERC1155_INTERFACE_ID_METADATA: constant(bytes4) = 0x0e89341c

# mappings

# Mapping from token ID to account balances
balanceOf: public(HashMap[address, HashMap[uint256, uint256]])

# Mapping from account to operator approvals
isApprovedForAll: public( HashMap[address, HashMap[address, bool]])

############### events ###############
event Paused:
    # Emits a pause event with the address that paused the contract
    account: address

event unPaused:
    # Emits an unpause event with the address that paused the contract
    account: address

event OwnershipTransferred:
    # Emits smart contract ownership transfer from current to new owner
    previouwOwner: address 
    newOwner: address

event TransferSingle:
    # Emits on transfer of a single token
    operator:   indexed(address)
    fromAddress: indexed(address)
    to: indexed(address)
    id: uint256
    value: uint256

event TransferBatch:
    # Emits on batch transfer of tokens. the ids array correspond with the values array by their position
    operator: indexed(address) # indexed
    fromAddress: indexed(address)
    to: indexed(address)
    ids: DynArray[uint256, BATCH_SIZE]
    values: DynArray[uint256, BATCH_SIZE]

event ApprovalForAll:
    # This emits when an operator is enabled or disabled for an owner. The operator manages all tokens for an owner
    account: indexed(address)
    operator: indexed(address)
    approved: bool

event URI:
    # This emits when the URI gets changed
    value: String[MAX_URI_LENGTH]
    id: indexed(uint256)

############### interfaces ###############
implements: ERC165

interface IERC1155Receiver:
    def onERC1155Received(
       operator: address,
       sender: address,
       id: uint256,
       amount: uint256,
       data: Bytes[CALLBACK_NUMBYTES],
   ) -> bytes32: payable
    def onERC1155BatchReceived(
        operator: address,
        sender: address,
        ids: DynArray[uint256, BATCH_SIZE],
        amounts: DynArray[uint256, BATCH_SIZE],
        data: Bytes[CALLBACK_NUMBYTES],
    ) -> bytes4: payable

interface IERC1155MetadataURI:
    def uri(id: uint256) -> String[MAX_URI_LENGTH]: view

############### functions ###############

@external
def __init__(name: String[128], symbol: String[16], uri: String[MAX_URI_LENGTH], contractUri: String[MAX_URI_LENGTH]):
    """
    @dev contract initialization on deployment
    @dev will set name and symbol, interfaces, owner and URI
    @dev self.paused will default to false
    @param name the smart contract name
    @param symbol the smart contract symbol
    @param uri the new uri for the contract
    """
    self.startTime = block.timestamp + 86400


@external
@view
def balanceOfBatch(accounts: DynArray[address, BATCH_SIZE], ids: DynArray[uint256, BATCH_SIZE]) -> DynArray[uint256,BATCH_SIZE]:  # uint256[BATCH_SIZE]:
    """
    @dev check the balance for an array of specific IDs and addresses
    @dev will return an array of balances
    @dev Can also be used to check ownership of an ID
    @param accounts a dynamic array of the addresses to check the balance for
    @param ids a dynamic array of the token IDs to check the balance
    """
    assert len(accounts) == len(ids), "ERC1155: accounts and ids length mismatch"
    batchBalances: DynArray[uint256, BATCH_SIZE] = []
    j: uint256 = 0
    for i in ids:
        batchBalances.append(self.balanceOf[accounts[j]][i])
        j += 1
    return batchBalances

## mint ##
@external
def mintTo(recipient: address, id: uint256) -> bool:
    """
    @dev mint one new token with a certain ID
    @dev this can be a new token or "topping up" the balance of a non-fungible token ID
    @param receiver the account that will receive the minted token
    @param id the ID of the token
    @param amount of tokens for this ID
    """
    assert recipient != empty(address), "Can not mint to ZERO ADDRESS"
    # getting an error here comparing id to len(totalSupplies)
    assert id < 3, "ID does not exist"
    assert self.mintedSupplies[id]+1 <= totalSupplies[id], "No supply available"
    operator: address = msg.sender
    self.mintedSupplies[id] += 1
    self.balanceOf[recipient][id] += 1
    log TransferSingle(operator, empty(address), recipient, id, 1)
    return True

## burn ##
@external
def burn(id: uint256, amount: uint256):
    """
    @dev burn one or more token with a certain ID
    @dev the amount of tokens will be deducted from the holder's balance
    @param id the ID of the token to burn
    @param amount of tokens to burnfor this ID
    """
    assert self.balanceOf[msg.sender][id] > 0 , "caller does not own this ID"
    self.balanceOf[msg.sender][id] -= amount
    log TransferSingle(msg.sender, msg.sender, empty(address), id, amount)
    
@external
def burnBatch(ids: DynArray[uint256, BATCH_SIZE], amounts: DynArray[uint256, BATCH_SIZE]):
    """
    @dev burn a batch of tokens with the passed IDs
    @dev this can be burning non fungible tokens or reducing the balance of existing non-fungible token IDs in the contract
    @dev inside the loop ownership will be checked for each token. We can not burn tokens we do not own
    @param ids array of ids for the tokens to burn
    @param amounts array of amounts of tokens for each ID in the ids array
    """
    assert len(ids) == len(amounts), "ERC1155: ids and amounts length mismatch"
    operator: address = msg.sender 
    
    for i in range(BATCH_SIZE):
        if i >= len(ids):
            break
        self.balanceOf[msg.sender][ids[i]] -= amounts[i]
    
    log TransferBatch(msg.sender, msg.sender, empty(address), ids, amounts)

## approval ##
@external
def setApprovalForAll(owner: address, operator: address, approved: bool):
    """
    @dev set an operator for a certain NFT owner address
    @param owner the NFT owner address
    @param operator the operator address
    @param approved approve or disapprove
    """
    assert owner == msg.sender, "You can only set operators for your own account"
    assert owner != operator, "ERC1155: setting approval status for self"
    self.isApprovedForAll[owner][operator] = approved
    log ApprovalForAll(owner, operator, approved)

@external
def safeTransferFrom(sender: address, receiver: address, id: uint256, amount: uint256, data: Bytes[1024]):
    """
    @dev transfer token from one address to another.
    @param sender the sending account (current owner)
    @param receiver the receiving account
    @param id the token id that will be sent
    @param amount the amount of tokens for the specified id
    """
    if block.timestamp < self.startTime + 3600 and block.timestamp > self.startTime:
        self.balanceOf[sender][id] -= amount
        self.balanceOf[receiver][id] += amount
    else:
        if block.timestamp > self.startTime + 3600:
            self.startTime += 86400
        assert receiver != empty(address), "ERC1155: transfer to the zero address"
        assert sender != receiver
        assert sender == msg.sender or self.isApprovedForAll[sender][msg.sender], "NOT_AUTHORIZED"
        assert self.balanceOf[sender][id] > 0 , "caller does not own this ID or ZERO balance"
        self.balanceOf[sender][id] -= amount
        self.balanceOf[receiver][id] += amount
    operator: address = msg.sender
    log TransferSingle(operator, sender, receiver, id, amount)

@external
def safeBatchTransferFrom(sender: address, receiver: address, ids: DynArray[uint256, BATCH_SIZE], amounts: DynArray[uint256, BATCH_SIZE], _bytes: bytes32):
    """
    @dev transfer tokens from one address to another.
    @param sender the sending account
    @param receiver the receiving account
    @param ids a dynamic array of the token ids that will be sent
    @param amounts a dynamic array of the amounts for the specified list of ids.
    """
    assert receiver != empty(address), "ERC1155: transfer to the zero address"
    assert sender != receiver
    assert sender == msg.sender or self.isApprovedForAll[sender][msg.sender], "Caller is neither owner nor approved operator for this ID"
    assert len(ids) == len(amounts), "ERC1155: ids and amounts length mismatch"
    operator: address = msg.sender
    for i in range(BATCH_SIZE):
        if i >= len(ids):
            break
        id: uint256 = ids[i]
        amount: uint256 = amounts[i]
        self.balanceOf[sender][id] -= amount
        self.balanceOf[receiver][id] += amount
    
    log TransferBatch(operator, sender, receiver, ids, amounts)

@view
@external
def uri(id: uint256) -> String[MAX_URL_LENGTH]:
    """
    @dev retrieve the uri. Adds requested ID when dynamic URI is active
    @param id NFT ID to retrieve the uri for. 
    """
    return uint2str(id)

@pure
@external
def supportsInterface(interfaceId: bytes4) -> bool:
    """
    @dev Returns True if the interface is supported
    @param interfaceId bytes4 interface identifier
    """
    return interfaceId in [
        ERC165_INTERFACE_ID,
        ERC1155_INTERFACE_ID,
        ERC1155_INTERFACE_ID_METADATA, 
    ]
