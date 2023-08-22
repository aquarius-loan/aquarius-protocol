const { default: BigNumber } = require('bignumber.js');
const ethers = require('ethers');

const {
  makeStaking,
} = require('../Utils/Aquarius');

const {address} = require('../Utils/Ethereum');

function etherUnsigned(num) {
  return ethers.utils.bigNumberify(new BigNumber(num).toFixed());
}

async function aquariusBalance(staking, user) {
  return etherUnsigned(await call(staking.ars, 'balanceOf', [user]))
}

describe('Staking', () => {
  let root, accounts;
  let staking;
  const aquariusMinted = etherUnsigned(1e18).mul(1000);
  const withdrawAmount = etherUnsigned(1e18).mul(100);
  const estimatedLeftAmount = etherUnsigned(1e18).mul(400);
  const estimatedLeftPenaltyAmount = etherUnsigned(1e18).mul(400);
  const deltaTimestamp = 10000;

  beforeEach(async () => {
    [root, ...accounts] = saddle.accounts;
    staking = await makeStaking();

    expect(await call(staking, 'owner')).toEqual(root);
    expect(await call(staking, 'admin')).toEqual(root);

    await send(staking, 'initialize', [staking.ars._address, [root]], {from: root});

    expect(await call(staking, 'stakingToken')).toEqual(staking.ars._address);

    expect(await aquariusBalance(staking, staking._address)).toEqualNumber(0);
    await send(staking.ars, 'transfer', [staking._address, aquariusMinted], {from: root});
    expect(await aquariusBalance(staking, staking._address)).toEqualNumber(aquariusMinted);
  });

  describe('constructor', () => {
    it("on success it sets admin to creator and pendingAdmin is unset", async () => {
      expect(await call(staking, 'admin')).toEqual(root);
      expect(await call(staking, 'pendingAdmin')).toEqualNumber(0);
    });
  });

  describe('stake', () => {
    it("can not initialize multiple times", async () => {
      await expect(
        send(staking, 'initialize', [staking.ars._address, [root]], {from: root})
      ).rejects.toRevert('revert AquariusStaking:initialize: Already initialized');
    });

    it("only minters can mint", async () => {
      await expect(
        send(staking, 'mint', [root, aquariusMinted], {from: accounts[1]})
      ).rejects.toRevert('revert MultiFeeDistribution::mint: Only minters allowed');

      await send(staking, 'mint', [root, aquariusMinted], {from: root});
      expect(await call(staking, 'totalSupply')).toEqualNumber(aquariusMinted);
      expect(await call(staking, 'totalBalance', [root])).toEqualNumber(aquariusMinted);
    });

    it("minter can mint", async () => {
      await send(staking, 'mint', [root, aquariusMinted], {from: root});
      expect(await call(staking, 'totalSupply')).toEqualNumber(aquariusMinted);
      expect(await call(staking, 'totalBalance', [root])).toEqualNumber(aquariusMinted);

      const lockedBalances = await call(staking, 'lockedBalances', [root]);
      expect(lockedBalances.total).toEqualNumber(0);
      expect(lockedBalances.unlockable).toEqualNumber(0);
      expect(lockedBalances.locked).toEqualNumber(0);
      expect(lockedBalances.lockData.length).toEqualNumber(0);

      const withdrawableBalance = await call(staking, 'withdrawableBalance', [root]);
      const aquariusMintedBN = new BigNumber(aquariusMinted);

      expect(withdrawableBalance.amount).toEqualNumber(aquariusMintedBN.dividedBy(2));
      expect(withdrawableBalance.penaltyAmount).toEqualNumber(aquariusMintedBN.dividedBy(2));
    });

    it("can not stake less than zero, only lock enabled", async () => {
      await expect(
        send(staking, 'stake', [0, true])
      ).rejects.toRevert('revert MultiFeeDistribution::stake: Cannot stake 0');

      await expect(
        send(staking, 'stake', [aquariusMinted, false])
      ).rejects.toRevert('revert Only lock enabled');
    });

    it("user able to stake", async () => {
      await send(staking.ars, 'approve', [staking._address, aquariusMinted], {from: root});
      await send(staking, 'stake', [aquariusMinted, true], {from: root});

      expect(await call(staking, 'totalSupply')).toEqualNumber(aquariusMinted);
      expect(await call(staking, 'totalBalance', [root])).toEqualNumber(aquariusMinted);

      const lockedBalances = await call(staking, 'lockedBalances', [root]);
      expect(lockedBalances.total).toEqualNumber(aquariusMinted);
      expect(lockedBalances.unlockable).toEqualNumber(0);
      expect(lockedBalances.locked).toEqualNumber(aquariusMinted);
      expect(lockedBalances.lockData[0].amount).toEqualNumber(aquariusMinted);

      const withdrawableBalance = await call(staking, 'withdrawableBalance', [root]);
      expect(withdrawableBalance.amount).toEqualNumber(0);
      expect(withdrawableBalance.penaltyAmount).toEqualNumber(0);
    });

    it("user able to withdraw after mint", async () => {
      await send(staking, 'mint', [root, aquariusMinted], {from: root});
      
      const preBalance = new BigNumber(await aquariusBalance(staking, root));
      await send(staking, 'withdraw', [withdrawAmount], {from: root});
      const postBalance = new BigNumber(await aquariusBalance(staking, root));

      const withdrawnAmount = postBalance.minus(preBalance);

      expect(withdrawnAmount).toEqualNumber(withdrawAmount);
      
      const lockedBalances = await call(staking, 'lockedBalances', [root]);
      expect(lockedBalances.total).toEqualNumber(0);
      expect(lockedBalances.unlockable).toEqualNumber(0);
      expect(lockedBalances.locked).toEqualNumber(0);
      expect(lockedBalances.lockData.length).toEqualNumber(0);

      const withdrawableBalance = await call(staking, 'withdrawableBalance', [root]);
      expect(withdrawableBalance.amount).toEqualNumber(estimatedLeftAmount);
      expect(withdrawableBalance.penaltyAmount).toEqualNumber(estimatedLeftPenaltyAmount);

    });
  });

  describe('_acceptAdminInImplementation()', () => {
    it('should fail when pending admin is zero', async () => {
      await expect(send(staking, '_acceptAdminInImplementation')).rejects.toRevert('revert ACCEPT_ADMIN_PENDING_ADMIN_CHECK');

      // Check admin stays the same
      expect(await call(staking, 'admin')).toEqual(root);
      expect(await call(staking, 'pendingAdmin')).toBeAddressZero();
    });

    it('should fail when called by another account (e.g. root)', async () => {
      expect(await send(staking, '_setPendingAdmin', [accounts[0]])).toSucceed();
      await expect(send(staking, '_acceptAdminInImplementation')).rejects.toRevert('revert ACCEPT_ADMIN_PENDING_ADMIN_CHECK');

      // Check admin stays the same
      expect(await call(staking, 'admin')).toEqual(root);
      expect(await call(staking, 'pendingAdmin')).toEqual(accounts[0]);
    });

    it('should succeed and set admin and clear pending admin', async () => {
      expect(await send(staking, '_setPendingAdmin', [accounts[0]])).toSucceed();
      expect(await send(staking, '_acceptAdminInImplementation', [], {from: accounts[0]})).toSucceed();

      // Check admin stays the same
      expect(await call(staking, 'admin')).toEqual(accounts[0]);
      expect(await call(staking, 'pendingAdmin')).toBeAddressZero();
    });

    it('should emit log on success', async () => {
      expect(await send(staking, '_setPendingAdmin', [accounts[0]])).toSucceed();
      const result = await send(staking, '_acceptAdminInImplementation', [], {from: accounts[0]});
      expect(result).toHaveLog('NewAdmin', {
        oldAdmin: root,
        newAdmin: accounts[0],
      });
      expect(result).toHaveLog('NewPendingAdmin', {
        oldPendingAdmin: accounts[0],
        newPendingAdmin: address(0),
      });
    });
  });
});
