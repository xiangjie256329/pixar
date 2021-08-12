const nft = artifacts.require("nft");
const Gov = artifacts.require("Gov");
module.exports = function (deployer) {
    deployer.deploy(nft,
                    //owner 为 msg.sender todo 先预设. lcc
                    //Gov.address,
                    //name
                    "nft token",
                    // symbol
                    "nft");

};
