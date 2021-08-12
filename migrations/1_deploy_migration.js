const Migrations = artifacts.require("Migrations");
const ControlledTokenProxyFactory = artifacts.require("ControlledTokenProxyFactory");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const BuildToken = artifacts.require("BuildToken");
module.exports = function (deployer) {
    deployer.deploy(Migrations);
    deployer.deploy(ControlledTokenProxyFactory);
    deployer.deploy(WrappedPlatformToken);
    deployer.deploy(BuildToken,ControlledTokenProxyFactory.address);
};
