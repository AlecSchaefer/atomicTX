pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Escrow.sol";

contract EthTx is Escrow {

  constructor(
    uint256 delta,
    uint256 delay,
    bytes32[] memory paths,
    bytes32[] memory hashLocks,
    address[] memory participants
  ) Escrow(delta, delay, paths, hashLocks, participants) public {}

  function escrow() payable txStarted(false) external {
    super.escrow(msg.value, msg.sender);
  }

  function withdraw() txConfirmed() external {
    require(_balances[msg.sender] > 0);

    msg.sender.transfer(_balances[msg.sender]);
    delete(_balances[msg.sender]);
  }

}
