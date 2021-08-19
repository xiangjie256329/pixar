const flip = artifacts.require("flip");
const WrappedPlatformToken = artifacts.require("WrappedPlatformToken");
const nft = artifacts.require("nft");
const BlindBox = artifacts.require("BlindBox");
const Gov = artifacts.require("Gov");
module.exports = function (deployer){
    deployer.deploy(flip,
                    // owner
                    //Gov.address,
                    "0x36b398c09b130b558C23AB94b4146f8911D6a8f1",
                    // platform
                    WrappedPlatformToken.address,
                    // nft
                    nft.address,
                    // blindbox
                    BlindBox.address);
};
