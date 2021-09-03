// SPDX-License-Identifier: MIT
pragma solidity ^0.6.5;

import "../token/WrappedToken.sol";
import "../TransferHelper.sol";
import "../token/ControlledToken.sol";
import "../nft/nft.sol";
import "../blindBox/BlindBox.sol";

contract flip {
    struct Config{
        address owner;  
        address lable_address;
        address platform_token;
        address key_token;
        address prize_pool;
        nft  nft_token;
        BlindBox blind_box;
    }

    Config public config;

    string public lastresult;
    uint public lastblocknumberused;
    bytes32 public lastblockhashused;

    constructor(address _lableAddress,address platform_token, address nft_token, address payable _blind_box, address prize_pool) public
    {
        config.owner = msg.sender;
        config.lable_address = _lableAddress;
        config.platform_token = platform_token;
        config.nft_token = nft(nft_token);
        config.blind_box = BlindBox(_blind_box);
        config.prize_pool = prize_pool;
        lastresult = "no wagers yet";
    }

    function init(address _key_token) public {
        //require( msg.sender == config.owner, "Flip Err:unauthorized");
        require(config.key_token == address(0),"Flip Err:Can not be re-initialized");
        config.key_token = _key_token;
    }

    function _mint(address to,uint256 amount,uint256 number)internal{
        ControlledToken(config.key_token).controllerMint(to,amount,number);
    }

    function sha(uint128 wager) view private returns(uint256)
    {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.coinbase, block.timestamp, lastblockhashused, wager)));
    }

    event betAndFlipLog(string);
    function betAndFlip(uint256 value, uint256 num) public
    {   
        require(msg.sender == tx.origin,"Flip Err:request failed");
        require(value == 10*10**18 ||value == 100*10**18 || value == 1000*10**18, "The amount should be 10 or 100 or 1000");
        require(num == 0 || num == 1, "parameter is incorrect");

        WrappedToken platform_token = WrappedToken(config.platform_token);

        uint256 amount = platform_token.allowance(msg.sender,address(this));
        require(amount >= value,"flip Err:amount cannot than allowance");

        uint256 prizeAmount = value/100*95;
        TransferHelper.safeTransferFrom(config.platform_token,msg.sender,config.prize_pool,prizeAmount);
        
        TransferHelper.safeTransferFrom(config.platform_token,msg.sender,config.lable_address,value-prizeAmount);

        uint128 wager = uint128(value);
        lastblocknumberused = block.number - 1 ;
        lastblockhashused = blockhash(lastblocknumberused);
        uint128 lastblockhashused_uint = uint128(uint(lastblockhashused)) + wager;
        uint hashymchasherton = sha(lastblockhashused_uint);

        uint256 rand = hashymchasherton % 2;

        if( rand == num )
        {
            lastresult = "win";
            TransferHelper.safeTransfer(config.platform_token,msg.sender, value * 95 /100 * 2 );
        }
        else
        {
            lastresult = "loss";
            if (value == 10*10**18)
            {
                uint256[] memory seriesIds = config.blind_box.QuerySeriesIds();
                uint256 randSeridId = hashymchasherton % seriesIds.length;
                config.nft_token.Draw(msg.sender, 1, 0, seriesIds[randSeridId],
                config.blind_box.QueryDraws(seriesIds[randSeridId]),config.blind_box.QueryLevels(seriesIds[randSeridId]));
            }else if (value == 100*10**18)
            {
                config.blind_box.mintKey(msg.sender,1);
            }
            else
            {
                config.blind_box.mintKey(msg.sender,10);
            }
        }
        emit betAndFlipLog(lastresult);
    }

    function getLastBlockNumberUsed() public view returns (uint)
    {
        return lastblocknumberused;
    }

    function getLastBlockHashUsed() public view returns (bytes32)
    {
        return lastblockhashused;
    }

    function getResultOfLastFlip() public view returns (string memory)
    {
        return lastresult;
    }

}
