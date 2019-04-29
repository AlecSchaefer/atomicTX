pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Escrow.sol";
import "./tokens/_ERC721.sol";

contract ERC721Tx is Escrow {

  uint256[] public _tokenIDs;

  mapping(uint256 => address) public _tokenOwners;
  mapping(uint256 => address) public _shadowTokenOwners;

  ERC721 public _tokenContract;

  constructor(
    address tokenContract,
    uint256 delta,
    uint256 delay,
    bytes32[] memory paths,
    bytes32[] memory hashLocks,
    address[] memory participants
  ) Escrow(delta, delay, paths, hashLocks, participants) public {
    _tokenContract = _ERC721(tokenContract);
  }

  function escrow(uint256[] calldata tokenIDs) txStarted(false) external {

    for (uint256 i = 0; i < tokenIDs.length; i++) {
      require(
        _tokenContract.getApproved(tokenIDs[i]) == address(this),
        "Escrow contract not approved for token."
      );
      _tokenContract.transferFrom(msg.sender, address(this), tokenIDs[i]);
      _tokenOwners[tokenIDs[i]] = msg.sender;
      _shadowTokenOwners[tokenIDs[i]] = msg.sender;
      _balances[msg.sender]++;
      _tokenIDs[i] = tokenIDs[i];
    }

    startTx();
  }

  function withdraw() txConfirmed() external {
    require(_balances[msg.sender] > 0);
    uint256 id;
    for (uint256 i = 0; i < _tokenIDs.length && _balances[msg.sender] > 0; i++) {
      id = _tokenIDs[i];
      if (msg.sender == _tokenOwners[id]) {
        _tokenContract.transferFrom(address(this), msg.sender, id);
        delete(_tokenOwners[id]);
        delete(_shadowTokenOwners[id]);
        _balances[msg.sender]--;
        // delete tokenID.
        _tokenIDs[i] = _tokenIDs[_tokenIDs.length - 1];
        _tokenIDs.length--;
        i--;
      }
    }
  }

  function shadowTransfer(uint256 asset, address sender, address receiver) txStarted(true) internal {
    require(sender == _shadowTokenOwners[asset]);
    _shadowTokenOwners[asset] = receiver;
  }

  function confirmTx() internal {
    if (_secrets.length == _participants.length) {
      address tokenOwner;
      address shadowTokenOwner;
      uint256 id;
      for (uint256 i = 0; i < _tokenIDs.length; i++) {
        id = _tokenIDs[i];
        tokenOwner = _tokenOwners[id];
        shadowTokenOwner = _shadowTokenOwners[id];
        if (tokenOwner != shadowTokenOwner) {
          _balances[shadowTokenOwner]++;
          _balances[tokenOwner]--;
          _tokenOwners[id] = shadowTokenOwner;
        }
      }
    }
  }

}
