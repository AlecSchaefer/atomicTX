pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract EthEscrow {
  using SafeMath for uint256;

  //Do we need a variable to keep track of amount escrowed?

  //Do we need to worry about fallback function?

  struct TimeOut {
    uint256 time, // Should we use block number or block timestamp (now)?
    bytes32 hashedSecret,
  }

  struct TxComponent {
    address sender,
    address receiver,
    uint256 amount,
    // Signature
    uint8 v,
    bytes32 r,
    bytes32 s,
  }

  mapping(address => uint256) public _balances;
  mapping(bytes32 => TimeOut) public _timeOuts;
  TxComponent[] public _txs;

  constructor(TimeOut[] memory timeOuts) external payable { //Not sure how to encode this parameter.
    require(msg.value > 0);
    _balances[msg.sender] = msg.value;
    _timeOuts = timeOuts;
  }

  function withdraw() external {
    require(_balances[msg.sender] > 0);
    /* TODO: check to make sure all secrets were revealed on time */
    msg.sender.transfer(_balances[msg.sender]);
    delete(_balances[msg.sender]);
  }

  function publishTxComponents(TxComponent[] memory txs) external { // Size limit on parameters?
    if (_txs.length != 0) {
      /* TODO: Check if tx is more recent than _tx */
    }

    // Validate signature
    require(tx.sender == )





    _txs.push(tx);


  }

  function publishSecret() external {
    /* TODO */
  }

}
