const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const [ owner, user ] = accounts;
const { expect } = require('chai');
const { createSnapshot, restoreSnapshot } = require('../testHelpers/snapshot.js')
const { BN, expectRevert } = require('@openzeppelin/test-helpers')
const { AssertBalance } = require('../testHelpers/assertBalance.js')

const Turbomint = contract.fromArtifact('Turbomint');
const TBTCTokenStub = contract.fromArtifact('TBTCTokenStub');
const FeeRebateTokenStub = contract.fromArtifact('FeeRebateTokenStub');
const TBTCDepositTokenStub = contract.fromArtifact('TBTCDepositTokenStub');
const DepositStub = contract.fromArtifact('DepositStub');

describe('Turbomint', function () {
const turbomintFee = 20
  before(async () => {
    tbtcToken = await TBTCTokenStub.new()
    feeRebateToken = await FeeRebateTokenStub.new()
    TBTCDepositToken = await TBTCDepositTokenStub.new()
    deposit = await DepositStub.new()

    assertBalance = new AssertBalance(tbtcToken)

    turbomint = await Turbomint.new(
      tbtcToken.address,
      feeRebateToken.address,
      TBTCDepositToken.address,
      turbomintFee,
      { from: owner }
    );
    tdtId = await web3.utils.toBN(deposit.address)
    await TBTCDepositToken.mint(owner, tdtId)
  })

  beforeEach(async () => {
    await createSnapshot()
  })

  afterEach(async () => {
    await restoreSnapshot()
  })

  describe('requestTurbomint', function () {
    beforeEach(async () => {
      await createSnapshot()
    })
    
    afterEach(async () => {
      await restoreSnapshot()
    })

    it('Requests turbomint and correctly transfers TDT', async function () {
      await TBTCDepositToken.approve(turbomint.address, tdtId, { from: owner })
      await turbomint.requestTurbomint(tdtId, { from: owner })

      expect(await TBTCDepositToken.ownerOf(tdtId)).to.equal(turbomint.address);
    });

    it('reverts if TDT is not approved', async function () {
      await expectRevert(
        turbomint.requestTurbomint(tdtId, { from: owner }),
        'ERC721: transfer caller is not owner nor approved'
      )
      });
  });

  describe('nopeOut', function () {
    beforeEach(async () => {
      await createSnapshot()
    })
    
    afterEach(async () => {
      await restoreSnapshot()
    })

    it('Nopes out and transfers TDT back to original owner', async function () {
      await TBTCDepositToken.approve(turbomint.address, tdtId, { from: owner })
      await turbomint.requestTurbomint(tdtId, { from: owner })
      await turbomint.nopeOut(tdtId, { from: owner })

      expect(await TBTCDepositToken.ownerOf(tdtId)).to.equal(owner);
    });

    it('Reverts if there is no open order for the giver TDT', async function () {
        await expectRevert(
          turbomint.nopeOut(235243, { from: owner }),
          'No open order for the given TDT id.'
        )
     });

     it('Reverts if the caller is not the original TDT owner', async function () {
      await TBTCDepositToken.approve(turbomint.address, tdtId, { from: owner })
      await turbomint.requestTurbomint(tdtId, { from: owner })
      await expectRevert(
        turbomint.nopeOut(tdtId),
        'Only original TDT holder can nope out.'
      )
     });
  });
  
  describe('provideTurbomint', function () {
    beforeEach(async () => {
      await createSnapshot()
    })
    
    afterEach(async () => {
      await restoreSnapshot()
    })

    it('Nopes out and transfers TDT back to original owner', async function () {
      await TBTCDepositToken.approve(turbomint.address, tdtId, { from: owner })
      await turbomint.requestTurbomint(tdtId, { from: owner })
      await turbomint.nopeOut(tdtId, { from: owner })

      expect(await TBTCDepositToken.ownerOf(tdtId)).to.equal(owner);
    });
  });

  describe('getTbtcToFill', function () {
    it('Returns correct value', async function () {
      const lotSize = await deposit.lotSizeTbtc.call()
      const signerFee = await deposit.signerFee.call()
      const fillFee = lotSize.div( new BN (turbomintFee))
      const TbtcToFill = lotSize.sub(signerFee).sub(fillFee)
      expect(await turbomint.getTbtcToFill(tdtId)).to.bignumber.equal(TbtcToFill);
    });
  });

  describe('provideTurbomint', function () {
    beforeEach(async () => {
      await createSnapshot()
    })
    
    afterEach(async () => {
      await restoreSnapshot()
    })

    it('pays the requester and receives TDT', async function () {
      await tbtcToken.zeroBalance({ from: owner })

      await TBTCDepositToken.approve(turbomint.address, tdtId, { from: owner })
      await turbomint.requestTurbomint(tdtId, { from: owner })
      const tbtcToFill = await turbomint.getTbtcToFill(tdtId)
      await tbtcToken.mint(user, tbtcToFill)
      await tbtcToken.approve(turbomint.address, tbtcToFill, { from: user })

      await turbomint.provideTurbomint(tdtId, { from: user })

      await assertBalance.tbtc(owner, tbtcToFill)
      expect(await TBTCDepositToken.ownerOf(tdtId)).to.equal(user);
    });

    it('Reverts if there is no open order', async function () {
        await expectRevert(
          turbomint.provideTurbomint(454654, { from: user }),
          'No open order for the given TDT id.'
        )
    });

    it('Reverts with insufficient approved balance', async function () {
        await TBTCDepositToken.approve(turbomint.address, tdtId, { from: owner })
        await turbomint.requestTurbomint(tdtId, { from: owner })
        const tbtcToFill = await turbomint.getTbtcToFill(tdtId)
        await tbtcToken.mint(user, tbtcToFill)

        await expectRevert(
          turbomint.provideTurbomint(tdtId, { from: user }),
          'ERC20: transfer amount exceeds allowance'
        )
    });
  });
});