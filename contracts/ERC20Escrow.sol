pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./tokens/_ERC20.sol";

contract ERC20Escrow {
  using SafeMath for uint256;

  struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct TxComponent {
    address sender;
    address receiver;
    uint256 amount;
    Signature sig;
  }

  uint256 public _startTime;
  uint256 public _lastTimeOut;
  uint256 public _delta;
  uint256 public _delay;

  address[] public _participants;
  mapping(address => uint256) public _balances;
  mapping(address => uint256) public _shadowBalances;

  TxComponent[] public _tx;

  bytes32[] public _secrets;
  // Maps secrets to lists of Signatures.
  mapping(bytes32 => Signature[]) public _signatures;
  // Maps hashed paths to hashed secrets (hashLocks).
  mapping(bytes32 => bytes32) public _hashLocks;

  _ERC20 public _tokenContract;
  uint256 public _amountEscrowed;

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

    _tokenContract = _ERC20(tokenContract);

    for (uint256 i = 0; i < paths.length; i++) {
      _hashLocks[paths[i]] = hashLocks[i];
    }

    for (uint256 i = 0; i < participants.length; i++) {
      _participants.push(participants[i]);
    }
  }

  modifier txConfirmed() {
    require(_startTime > 0);
    require(_amountEscrowed > 0);
    require(
      _secrets.length == _participants.length || now > _lastTimeOut
    );
    _;
  }

  modifier txStarted(bool x) {
    require((_startTime > 0) == x);
    require((_amountEscrowed > 0) == x);
    _;
  }

  function escrow(uint256 amount) txStarted(false) external {
    require(amount > 0);
    require(
      _tokenContract.allowance(msg.sender, address(this)) >= amount,
      "Escrow contract has insufficient allowance."
    );

    _amountEscrowed = amount;
    _tokenContract.transferFrom(msg.sender, address(this), amount); // Add check to make sure this worked ??
    _balances[msg.sender] = amount;
    _shadowBalances[msg.sender] = amount;

    _startTime = now;
    _lastTimeOut = calculateTimeOut(_participants.length);
  }

  function withdraw() txConfirmed() external {
    uint256 amount = _balances[msg.sender];
    require(amount > 0);
    _tokenContract.transfer(msg.sender, amount);
    _amountEscrowed = _amountEscrowed.sub(amount);
    delete(_balances[msg.sender]);
  }

  function publishTxComponents(TxComponent[] memory txcs) txStarted(true) public {
    bytes32 data;
    string memory err;
    Signature memory prevSig;
    TxComponent memory txc;
    uint256 startLoop = _tx.length;
    uint256 endLoop = startLoop + txcs.length;
    for (uint256 i = startLoop; i < endLoop; i++) { // Appends to _tx
      txc = txcs[i]; // For readability.
      if (i == 0) { // Origin txc — data does not contain prevSig backpointer.
        data = keccak256(abi.encodePacked(
          txc.sender, txc.receiver, txc.amount
        ));
        err = 'invalid signature: origin txc';
      } else { // derivative txc. msg contains backpointer.
        prevSig = _tx[i-1].sig;
        data = keccak256(abi.encodePacked(
          prevSig.v, prevSig.r, prevSig.s, txc.sender, txc.receiver, txc.amount
        ));
        err = 'invalid signature: derivative txc';
      }
      // Validate signature.
      require(txc.sender == ecrecover(data, txc.sig.v, txc.sig.r, txc.sig.s), err);
      // Save tentative state. Checks balances are enough to cover each txc (with SafeMath).
      _shadowBalances[txc.sender] = _shadowBalances[txc.sender].sub(txc.amount);
      _shadowBalances[txc.receiver] = _shadowBalances[txc.receiver].add(txc.amount);
      // Save log of txcs to storage.
      _tx.push(txc);
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
      address a;
      for(uint256 i = 0; i < _participants.length; i++) {
        a = _participants[i];
        _balances[a] = _shadowBalances[a];
        delete(_shadowBalances[a]);
      }
    }
  }

  /*TODO: What if someone publishes more tx TxComponents after all secrets are published?? */

  function calculateTimeOut(uint256 pathLength) private view txStarted(true) returns(uint256) {
    return _startTime.add(_delay).add(_delta.mul(pathLength.add(1)));
  }

}
