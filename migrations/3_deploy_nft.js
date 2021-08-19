const nft = artifacts.require("nft");
const Gov = artifacts.require("Gov");
module.exports = function (deployer) {
    deployer.deploy(nft,
                    //owner 为 msg.sender
                    //Gov.address,
                    //name
                    "Nnft Token",
                    // symbol
                    "Nnft");

};
