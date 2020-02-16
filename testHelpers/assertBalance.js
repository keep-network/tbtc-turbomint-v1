const { expect } = require('chai');

class AssertBalance {
  constructor(tbtc) {
    this.tbtcInstance = tbtc
  }

  async tbtc(account, amount) {
    const balance = await this.tbtcInstance.balanceOf(account)
    expect(balance).to.bignumber.equal(amount)
  }

  async eth(account, amount) {
    const balance = await web3.eth.getBalance(account)
    expect(balance).to.equal(amount)
  }
}
module.exports.AssertBalance = AssertBalance