pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";

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
    Signature sig;
  }

  uint256 public _startTime;
  uint256 public _lastTimeOut;
  uint256 public _delta;
  uint256 public _delay;

  address[] public _participants;
  //mapping(address => uint256) public _balances;
  //mapping(address => uint256) public _shadowBalances;
  address public _tokenOwner;
  address public _shadowTokenOwner;

  TxComponent[] public _tx;

  bytes32[] public _secrets;
  // Maps secrets to lists of Signatures.
  mapping(bytes32 => Signature[]) public _signatures;
  // Maps hashed paths to hashed secrets (hashLocks).
  mapping(bytes32 => bytes32) public _hashLocks;

  ERC721 public _tokenContract;
  uint256 public _escrowedTokenID;

  constructor(
    uint256 delta,
    uint256 delay,
    address tokenContract,
    uint256 escrowedTokenID,
    bytes32[] memory paths,
    bytes32[] memory hashLocks,
    address[] memory participants
  ) public {
    require(paths.length == hashLocks.length);

    //add check to number of participants / array length??

    _tokenContract = ERC721(tokenContract);
    _escrowedTokenID = escrowedTokenID;

    require(_tokenContract.getApproved(escrowedTokenID) == address(this));

    _tokenContract.transferFrom(msg.sender, address(this), escrowedTokenID); // Add check to make sure this worked ??

    _tokenOwner = msg.sender;
    _shadowTokenOwner = msg.sender;

    for (uint256 i = 0; i < paths.length; i++) {
      _hashLocks[paths[i]] = hashLocks[i];
    }

    for (uint256 i = 0; i < participants.length; i++) {
      _participants[i] = participants[i];
    }

    _startTime = now;
    _lastTimeOut = now.add(delay).add(delta.mul(participants.length.add(1)));
    _delta = delta;
    _delay = delay;

  }

  modifier txConfirmed() {
    require(
      _secrets.length == _participants.length || now > _lastTimeOut
    );
    _;
  }

  function withdraw() txConfirmed() external {
    _tokenContract.transferFrom(address(this), _tokenOwner, _escrowedTokenID);
    delete(_tokenOwner);
    delete(_shadowTokenOwner);
    delete(_escrowedTokenID);
  }

  function publishTxComponents(TxComponent[] memory txcs) public {
    bytes32 data;
    string memory err;
    Signature memory prevSig;
    TxComponent memory txc;
    uint256 startLoop = _tx.length;
    uint256 endLoop = startLoop + txcs.length;
    for (uint256 i = startLoop; i < endLoop; i++) { // Appends to _tx
      txc = txcs[i]; // For readability.
      require(txc.sender == _shadowTokenOwner);
      if (i == 0) { // Origin txc — data does not contain prevSig backpointer.
        data = keccak256(abi.encodePacked(txc.sender, txc.receiver));
        err = 'invalid signature: origin txc';
      } else { // derivative txc. msg contains backpointer.
        prevSig = _tx[i-1].sig;
        data = keccak256(abi.encodePacked(
          prevSig.v, prevSig.r, prevSig.s, txc.sender, txc.receiver
        ));
        err = 'invalid signature: derivative txc';
      }
      // Validate signature.
      require(txc.sender == ecrecover(data, txc.sig.v, txc.sig.r, txc.sig.s), err);
      _shadowTokenOwner = txc.receiver;
      _tx.push(txc);// Save log of txcs to storage.
    }
  }

  function publishSecret(Signature[] memory sigs, bytes32 secret) public {
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
      _tokenOwner = _shadowTokenOwner;
    }
  }

  function calculateTimeOut(uint256 pathLength) private view returns(uint256) {
    return _startTime.add(_delay).add(_delta.mul(pathLength.add(1)));
  }

}
