const ERC20 = artifacts.require("_ERC20")
const ERC721 = artifacts.require("_ERC721")

const EthEscrow = artifacts.require("EthEscrow")
const ERC20Escrow = artifacts.require("ERC20Escrow")
const ERC721Escrow = artifacts.require("ERC721Escrow")

const delta = 1 // seconds
const delay = 1 // seconds
const paths = []
const hashLocks = []

module.exports = function(deployer, network, accounts) {
  deployer.deploy(
    EthEscrow,
    delta,
    delay,
    paths,
    hashLocks,
    accounts,
  )
  deployer.deploy(
    ERC20
  ).then(function () {
    return deployer.deploy(
      ERC20Escrow,
      delta,
      delay,
      ERC20.address,
      paths,
      hashLocks,
      accounts
    )
  })
  deployer.deploy(
    ERC721
  ).then(function () {
    return deployer.deploy(
      ERC721Escrow,
      delta,
      delay,
      ERC721.address,
      paths,
      hashLocks,
      accounts
    )
  })
}
