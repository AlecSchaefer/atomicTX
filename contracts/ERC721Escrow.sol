pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./tokens/_ERC721.sol";

contract ERC721Escrow {
  using SafeMath for uint256;

  struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct TxComponent {
    address sender;
    address receiver;
    uint256 tokenID;
    Signature sig;
  }

  uint256 public _startTime;
  uint256 public _lastTimeOut;
  uint256 public _delta;
  uint256 public _delay;

  address[] public _participants;
  uint256[] public _tokenIDs;

  mapping(uint256 => address) public _tokenOwners;
  mapping(uint256 => address) public _shadowTokenOwners;
  mapping(address => uint256) public _balances;

  TxComponent[] public _tx;

  bytes32[] public _secrets;
  // Maps secrets to lists of Signatures.
  mapping(bytes32 => Signature[]) public _signatures;
  // Maps hashed paths to hashed secrets (hashLocks).
  mapping(bytes32 => bytes32) public _hashLocks;

  ERC721 public _tokenContract;

  constructor(
    uint256 delta,
    uint256 delay,
    address tokenContract,
    bytes32[] memory paths,
    bytes32[] memory hashLocks,
    address[] memory participants
  ) public {
    require(paths.length == hashLocks.length);

    //add check to number of participants / array length??

    _delta = delta;
    _delay = delay;

    _tokenContract = _ERC721(tokenContract);


    for (uint256 i = 0; i < paths.length; i++) {
      _hashLocks[paths[i]] = hashLocks[i];
    }

    for (uint256 i = 0; i < participants.length; i++) {
      _participants.push(participants[i]);
    }

  }

  modifier txConfirmed() {
    require(_startTime > 0);
    require(
      _secrets.length == _participants.length || now > _lastTimeOut
    );
    _;
  }

  modifier txStarted(bool x) {
    require((_startTime > 0) == x);
    _;
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

    _startTime = now;
    _lastTimeOut = calculateTimeOut(_participants.length);
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

  function publishTxComponents(TxComponent[] memory txcs) txStarted(true) public {
    bytes32 data;
    string memory err;
    Signature memory prevSig;
    TxComponent memory t;
    uint256 startLoop = _tx.length;
    uint256 endLoop = startLoop + txcs.length;
    for (uint256 i = startLoop; i < endLoop; i++) { // Appends to _tx
      t = txcs[i]; // For readability.
      require(t.sender == _shadowTokenOwners[t.tokenID]);
      if (i == 0) { // Origin txc — data does not contain prevSig backpointer.
        data = keccak256(abi.encodePacked(t.sender, t.receiver, t.tokenID));
        err = 'invalid signature: origin txc';
      } else { // derivative txc. msg contains backpointer.
        prevSig = _tx[i-1].sig;
        data = keccak256(abi.encodePacked(
          prevSig.v, prevSig.r, prevSig.s, t.sender, t.receiver, t.tokenID
        ));
        err = 'invalid signature: derivative txc';
      }
      // Validate signature.
      require(t.sender == ecrecover(data, t.sig.v, t.sig.r, t.sig.s), err);
      _shadowTokenOwners[t.tokenID] = t.receiver;
      _tx.push(t);// Save log of txcs to storage.
    }
  }

  function publishSecret(Signature[] memory sigs, bytes32 secret) txStarted(true) public {
    require(calculateTimeOut(sigs.length) > now);

    require(_signatures[secret].length == 0); //require that secret has not already been published.

    // Get path.
    bytes32 data; // The data that is signed to create the given signature.
    bytes32 path;
    address vertex;
    for (uint256 i = 0; i < sigs.length; i++) {
      if (i == 0) {
        data = secret;
      } else {
        data = keccak256(abi.encodePacked(
          sigs[i-1].v, sigs[i-1].r, sigs[i-1].s
        ));
      }
      vertex = ecrecover(data, sigs[i].v, sigs[i].r, sigs[i].s);
      path = keccak256(abi.encodePacked(vertex, path));
      _signatures[secret].push(sigs[i]);
    }

    bytes32 hashLock = _hashLocks[path];
    require(hashLock != 0);// Confirm path exists / is defined.
    require(hashLock == keccak256(abi.encodePacked(secret))); // Validate secret

    _secrets.push(secret);

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

  function calculateTimeOut(uint256 pathLength) private view txStarted(true) returns(uint256) {
    return _startTime.add(_delay).add(_delta.mul(pathLength.add(1)));
  }

}
