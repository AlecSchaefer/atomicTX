pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract EthEscrow {
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

  struct SignedSecret {
    uint256 secret;
    Signature[] sigs;
  }

  struct HashLock {
    bytes32 hashedSecret;
    bool unlocked;
  }

  struct Path {
    uint256 index;
    uint256 timeOut;
    uint256 hashLockIndex;
  }

  HashLock[] public _hashLocks;

  bytes32[] public _hashedPaths;
  mapping(bytes32 => Path) public _paths;

  SignedSecret[] public _publishedSecrets;

  TxComponent[] public _txComponents;

  mapping(address => uint256) public _balances;
  mapping(address => uint256) public _shadowBalances;

  constructor(
    Path[] calldata paths,
    bytes32[] calldata hashedPaths
  ) external payable {
    require(msg.value > 0);

    _balances[msg.sender] = msg.value;
    _shadowBalances[msg.sender] = msg.value;

    for (uint256 i = 0; i < paths.length; i++) {
      _hashedPaths[paths[i].index] = hashedPaths[paths[i].index];
      _paths[hashedPaths[paths[i].index]] = paths[i];
    }

  }

  function withdraw() external {
    require(_balances[msg.sender] > 0);

    uint256 numLocks = _hashLocks.length;
    for (uint256 i = 0; i < numLocks; i++) {
      require(_hashLocks[i].unlocked);
    }

    msg.sender.transfer(_balances[msg.sender]);
    delete(_balances[msg.sender]);
  }

  function publishTxComponents(TxComponent[] calldata txComponents) external { // Size limit on parameters?
    TxComponent memory txc;
    bytes memory data;
    string memory err;
    for (uint256 i = _txComponents.length; i < txComponents.length; i++) { // Appends to _txComponents
      txc = txComponents[i]; // For readability.
      // Save log of txcs to storage. Log will persist if no iteration of this loop reverts.
      _txComponents.push(txc);
      if (i == 0) { // origin txc. msg does not contain backpointer.
        data = abi.encodePacked(txc.sender, txc.receiver, txc.amount);
        err = 'invalid signature: origin txc';
      } else { // derivative txc. msg contains backpointer.
        data = abi.encodePacked(
          _txComponents[i-1], txc.sender, txc.receiver, txc.amount
        );
        err = 'invalid signature: derivative txc';
      }
      // Validate signature
      require(
        txc.sender == ecrecover(data, txc.sig.v, txc.sig.r, txc.sig.s), err
      );
      // Save tentative state. Checks balances are enough to cover each txc (with SafeMath).
      _shadowBalances[txc.sender] = _shadowBalances[txc.sender].sub(txc.amount);
      _shadowBalances[txc.receiver] = _shadowBalances[txc.receiver].add(txc.amount);
    }
  }

  function publishSecret(uint256 secret, Signature[] calldata sigs) external {

    SignedSecret memory ss; // Or can we just pass this directly in as parameter?
    ss.secret = secret;

    // Get path.
    address[] memory addressPath = new address[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      ss.sigs[i] = sigs[i];
      if (i == 0) { // original reveal. Should be signed by owner of secret.
        addressPath.push(ecrecover(secret, sigs[i].v, sigs[i].r, sigs[i].s));
        //ss.secret = secret;
      } else {
        addressPath.push(ecrecover(sigs[i-1], sigs[i].v, sigs[i].r, sigs[i].s));
      }
    }

    bytes32 hashedPath = keccak256(abi.encodePacked(addressPath));
    Path memory path = _paths[hashedPath];

    require(path != 0);
    require(path.timeOut > now);

    HashLock storage hashLock = _hashLocks[path.hashLockIndex];

    //require(!hashLock.unlocked);
    require(hashLock.hashedSecret == keccak256(abi.encodePacked(secret)));

    hashLock.unlocked = true;

    _publishedSecrets.push(ss);
  }

}
