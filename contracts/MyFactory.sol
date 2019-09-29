pragma solidity ^0.5.11;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./IFactory.sol";
import "./MyCollectible.sol";
import "./Strings.sol";

// WIP
contract MyFactory is IFactory, Ownable {
  using Strings for string;
  using SafeMath for uint256;

  address public proxyRegistryAddress;
  address public nftAddress;
  string internal baseMetadataURI = "https://opensea-creatures-api.herokuapp.com/api/factory/";

  /**
   * Enforce the existence of only 100 items per option/token ID
   */
  uint256 SUPPLY_PER_TOKEN_ID = 100;

  /**
   * Three different options for minting MyCollectibles (basic, premium, and gold).
   */
  enum Option {
    Basic,
    Premium,
    Gold
  }
  uint256 constant NUM_OPTIONS = 3;
  mapping (uint256 => uint256) public optionToTokenID;

  /**
   * @dev Require msg.sender to be the owner proxy or owner.
   */
  modifier onlyOwner() {
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    require(
      address(proxyRegistry.proxies(owner())) == msg.sender ||
      owner() == msg.sender,
      "MyFactory#mint: NOT_AUTHORIZED_TO_MINT"
    );
    _;
  }

  constructor(address _proxyRegistryAddress, address _nftAddress) public {
    proxyRegistryAddress = _proxyRegistryAddress;
    nftAddress = _nftAddress;
  }

  /////
  // IFACTORY METHODS
  /////

  function name() external view returns (string memory) {
    return "My Collectible Pre-Sale";
  }

  function symbol() external view returns (string memory) {
    return "MCP";
  }

  function supportsFactoryInterface() external view returns (bool) {
    return true;
  }

  function numOptions() external view returns (uint256) {
    return NUM_OPTIONS;
  }

  function canMint(uint256 _optionId, uint256 _amount) external view returns (bool) {
    return _canMint(Option(_optionId), _amount);
  }

  function mint(uint256 _optionId, address _toAddress, uint256 _amount, bytes calldata _data) external {
    return _mint(Option(_optionId), _toAddress, _amount, _data);
  }

  function uri(uint256 _optionId) external view returns (string memory) {
    return Strings.strConcat(
      baseMetadataURI,
      Strings.uint2str(_optionId)
    );
  }

  /**
   * @dev Main minting logic implemented here!
   */
  function _mint(
    Option _option,
    address _toAddress,
    uint256 _amount,
    bytes memory _data
  ) internal onlyOwner {
    require(_canMint(_option, _amount), "MyFactory#_mint: CANNOT_MINT_MORE");
    uint256 optionId = uint256(_option);
    MyCollectible nftContract = MyCollectible(nftAddress);
    uint256 id = optionToTokenID[optionId];
    if (id == 0) {
      id = nftContract.create(_toAddress, _amount, "", _data);
      optionToTokenID[optionId] = id;
    } else {
      nftContract.mint(_toAddress, id, _amount, _data);
    }
  }

  /**
   * Get the factory's ownership of Option.
   * Should be the amount it can still mint.
   * NOTE: Called by `canMint`
   */
  function balanceOf(
    address _owner,
    uint256 _optionId
  ) public view returns (uint256) {
    if (_owner != owner()) {
      return 0;
    }
    uint256 id = optionToTokenID[_optionId];
    if (id == 0) {
      // Haven't minted yet
      return SUPPLY_PER_TOKEN_ID;
    }

    MyCollectible nftContract = MyCollectible(nftAddress);
    uint256 currentSupply = nftContract.totalSupply(id);
    return SUPPLY_PER_TOKEN_ID.sub(currentSupply);
  }

  /**
   * Hack to get things to work automatically on OpenSea.
   * Use safeTransferFrom so the frontend doesn't have to worry about different method names.
   */
  function safeTransferFrom(
    address /* _from */,
    address _to,
    uint256 _optionId,
    uint256 _amount,
    bytes calldata _data
  ) external {
    _mint(Option(_optionId), _to, _amount, _data);
  }

  //////
  // Below methods shouldn't need to be overridden or modified
  //////

  function isApprovedForAll(
    address _owner,
    address _operator
  ) external view returns (bool) {
    if (owner() == _owner && _owner == _operator) {
      return true;
    }

    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (owner() == _owner && address(proxyRegistry.proxies(_owner)) == _operator) {
      return true;
    }

    return false;
  }

  function _canMint(
    Option _option,
    uint256 _amount
  ) internal view returns (bool) {
    uint256 optionId = uint256(_option);
    return _amount > 0 && balanceOf(owner(), optionId) >= _amount;
  }
}
