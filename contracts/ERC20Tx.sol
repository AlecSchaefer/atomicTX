pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Escrow.sol";
import "./tokens/_ERC20.sol";

contract ERC20Tx is Escrow {
  using SafeMath for uint256;

  _ERC20 public _tokenContract;
  uint256 public _amountEscrowed;

  constructor(
    address tokenContract,
    uint256 delta,
    uint256 delay,
    bytes32[] memory paths,
    bytes32[] memory hashLocks,
    address[] memory participants
  ) Escrow(delta, delay, paths, hashLocks, participants) public {
    _tokenContract = _ERC20(tokenContract);
  }

  function escrow(uint256 amount) txStarted(false) external {
    require(
      _tokenContract.allowance(msg.sender, address(this)) >= amount,
      "Escrow contract has insufficient allowance."
    );
    _tokenContract.transferFrom(msg.sender, address(this), amount); // Add check to make sure this worked ??
    _amountEscrowed = amount;
    super.escrow(amount, msg.sender);
  }

  function withdraw() txConfirmed() external {
    uint256 amount = _balances[msg.sender];
    require(amount > 0);
    _tokenContract.transfer(msg.sender, amount);
    _amountEscrowed = _amountEscrowed.sub(amount);
    delete(_balances[msg.sender]);
  }

}
