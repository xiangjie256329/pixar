const Gov = artifacts.require("Gov");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");

const Unit = 1000000000000000000n;

module.exports = function (deployer) {
  deployer.deploy(
    Gov,
    "0x4936e6A6A989b4B6101D7Bd70a8e494649853360", //owner
    WrappedPlatformToken.address,
    1000n, //quorum 10% - 最少 参与投票token/总token 比例
    5000n, //threshold 50% - 最少 投Yes/所有投票 的比例
    50n, //提案高度+voting_period为结束投票高度
    50n, //提案投票通过后，允许执行的高度范围
    50n, //提案投票通过后，在expiration_period后可过期
    100n * Unit //提案最少需要抵押的toke
  );
};
