const Staking = artifacts.require("Staking");
const Lock = artifacts.require("Lock");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const Unit = 1000000000000000000n;

module.exports = function(deployer){
    deployer.deploy(
        Staking,
        //owner
        "",
        WrappedPlatformToken.address,
        Lock.address,
        1n,
    );
};
