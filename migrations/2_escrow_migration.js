const ERC20 = artifacts.require("_ERC20")
const ERC721 = artifacts.require("_ERC721")

const EthTx = artifacts.require("EthTx")
const ERC20Tx = artifacts.require("ERC20Tx")
const ERC721Tx = artifacts.require("ERC721Tx")

const delta = 1 // seconds
const delay = 1 // seconds
const paths = []
const hashLocks = []

module.exports = function(deployer, network, accounts) {
  deployer.deploy(
    EthTx,
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
      ERC20Tx,
      ERC20.address,
      delta,
      delay,
      paths,
      hashLocks,
      accounts
    )
  })
  deployer.deploy(
    ERC721
  ).then(function () {
    return deployer.deploy(
      ERC721Tx,
      ERC721.address,
      delta,
      delay,
      paths,
      hashLocks,
      accounts
    )
  })
}
