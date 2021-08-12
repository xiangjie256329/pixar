const { utils } = require("ethers");
const { Contract, getDefaultProvider, Wallet, BigNumber } = require("ethers");
const provider = getDefaultProvider(
  "https://data-seed-prebsc-1-s1.binance.org:8545/"
);
let private_key =
  "0x6271102e8b770eea39b241054fb793fb94a22c24ab949af01c9c661d53445ccc";
let private_key_new =
  "0x6271102e8b770eea39b241054fb793fb94a22c24ab949af01c9c661d53445ccc";
const wallet = new Wallet(private_key, provider);
const wallet_new = new Wallet(private_key_new, provider);

let json = require("../../build/contracts/Lock.json");
const abi = json.abi;
const contractAddr = "0xadEbfd5C61d5E5b07B9bBA1d4B74B1A52b133d73";
const contractHandler = new Contract(contractAddr, abi, wallet);
const contractHandler_new = new Contract(contractAddr, abi, wallet_new);

let jsonToken = require("../../build/contracts/WrappedToken.json");
const abiToken = jsonToken.abi;
//Platform token
const contractPlatformTokenAddr = "0x68Fa60737e8Fef9B478d0d253818FA9be307649C";
const contractPlatformTokenHandler = new Contract(
  contractPlatformTokenAddr,
  abiToken,
  wallet
);
//Usdt token
const contractUsdtTokenAddr = "0x95d3eeeD6949bBe5Bca8a35F7e39CA0eAd3ECC15";
const contractUsdtTokenHandler = new Contract(
  contractUsdtTokenAddr,
  abiToken,
  wallet
);

const Unit = 1000000000000000000n;
const PriceUnit = 10000000000n;

const GasLimit = 10500000;

async function sleep(ms = 0) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, ms);
  });
}

async function aprovePlatform(amount) {
  try {
    await contractPlatformTokenHandler.approve(contractAddr, amount, {
      gasLimit: GasLimit,
    });
    console.log("✓---------- aprovePlatform -----------");
  } catch (e) {
    console.log("❌================ aprovePlatform ====================");
    console.log(e.message);
  }
}

async function aproveUsdt(amount) {
  try {
    await contractUsdtTokenHandler.approve(contractAddr, amount, {
      gasLimit: GasLimit,
    });
    console.log("✓---------- aproveUsdt -----------");
  } catch (e) {
    console.log("❌================ aproveUsdt ====================");
    console.log(e.message);
  }
}

async function Test_QueryConfig() {
  try {
    console.log("----------- Test_QueryConfig start -----------");
    let config = await contractHandler.QueryConfig();
    // console.log("owner:", config.owner)
    console.log("platform_token(平台通证合约地址):", config.platform_token);
    console.log(
      "periodDuration(周期时间长度，同一个周期内的奖励会放到同一个奖金池):",
      config.periodDuration
    );
    console.log("rewardsDuration(奖励时间长度):", config.rewardsDuration);
    console.log("lockDuration(锁仓时间长度):", config.lockDuration);
    // console.log("periodNumber:", config.periodNumber)
    // console.log("donate:", config.donate)
    console.log("✓---------- Test_QueryConfig end   -----------");
  } catch (e) {
    console.log("❌================ Test_QueryConfig ====================");
    console.log(e.message);
  }
}

async function Test_QueryConfig() {
  try {
    console.log("----------- Test_QueryConfig start -----------");
    let config = await contractHandler.QueryConfig();
    console.log("owner:", config.owner);
    console.log("platform_token:", config.platform_token);
    console.log(
      "periodDuration:",
      config.periodDuration
    );
    console.log("rewardsDuration:", config.rewardsDuration);
    console.log("lockDuration:", config.lockDuration);
    console.log("periodNumber:", config.periodNumber);
    console.log("donate:", config.donate);
    console.log("✓---------- Test_QueryConfig end   -----------");
  } catch (e) {
    console.log("❌================ Test_QueryConfig ====================");
    console.log(e.message);
  }
}

async function Test_rewardData() {
  try {
    console.log("----------- rewardData start -----------");
    let idx = await contractHandler.GetPeriodInd();
    let ret = await contractHandler.rewardData(idx);
    console.log("reward：", ret);
    console.log("✓---------- rewardData end   -----------");
  } catch (e) {
    console.log("❌================ rewardData ====================");
    console.log(e.message);
  }
}

async function Test_ClaimableRewards() {
  try {
    console.log("----------- ClaimableRewards start -----------");
    let account = "0x9768c749d17EC7F7C3a2efA368920BcE3a02166c";
    let ret = await contractHandler.ClaimableRewards(account);
    console.log("Total Awards:", ret.total);
    for (let i = 0; i < ret.claRewards.length; i++) {
      console.log(i + 1, "//////////////////////////////");
      console.log("Reward cycle:", ret.claRewards[i].idx);
      console.log("Number of awards:", ret.claRewards[i].amount);
    }
    console.log("✓---------- ClaimableRewards end   -----------");
  } catch (e) {
    console.log("❌================ ClaimableRewards ====================");
    console.log(e.message);
  }
}

async function Test_GetStakeAmounts() {
  try {
    console.log("----------- GetStakeAmounts start -----------");
    let account = "0x9768c749d17EC7F7C3a2efA368920BcE3a02166c";
    let ret = await contractHandler.GetStakeAmounts(account);
    console.log("Total mortgage:", ret.total);
    console.log("Desirable mortgage:", ret.unlockable);
    console.log("No mortgage:", ret.locked);
    for (let i = 0; i < ret.lockData.length; i++) {
      console.log(i + 1, "//////////////////////////////");
      console.log("Reward cycle:", ret.lockData[i].idx);
      console.log("Number of awards:", ret.lockData[i].amount);
    }
    console.log("✓---------- GetStakeAmounts end   -----------");
  } catch (e) {
    console.log("❌================ GetStakeAmounts ====================");
    console.log(e.message);
  }
}

async function Test_RewardToken() {
  try {
    let ret = await contractHandler.RewardToken({ gasLimit: GasLimit });
    console.log(ret);
    console.log("✓---------- Test_RewardToken end   -----------");
  } catch (e) {
    console.log("❌================ Test_RewardToken ====================");
    console.log(e.message);
  }
}

async function Test_LockToken() {
  try {
    let ret = await contractHandler.Stake({ gasLimit: GasLimit });
    console.log(ret);
    console.log("✓---------- Test_RewardToken end   -----------");
  } catch (e) {
    console.log("❌================ Test_RewardToken ====================");
    console.log(e.message);
  }
}

async function main() {
  console.log("contractAddr:", contractAddr);
  // await Test_QueryConfig();
  // await Test_ClaimableRewards();
  // await Test_GetStakeAmounts();
  // await Test_rewardData()
  // await aprovePlatform(1000n * Unit);
  // await aproveUsdt(100n * Unit);
  await Test_LockToken();
  // await Test_RewardToken();
}

main().catch((err) => {
  console.log("error", err);
});
