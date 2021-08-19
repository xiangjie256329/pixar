// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../TransferHelper.sol";
import "./BuildToken.sol";
import "../token/TokenControllerInterface.sol";
import "../token/ControlledToken.sol";
import "../token/WrappedToken.sol";
import "../prizePool/PrizePool.sol";
import "../nft/nft.sol";
import "../flip/flip.sol";
import "@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol";


contract BlindBox is ERC20PermitUpgradeable {
    using SafeMath for uint256;
    event mint_box(uint256, string);
    event draw_out(address, uint256, uint256);
    event draw(address, uint256);
    event mix_true(address, uint256, uint256, bool);
    event resetDraw(uint256 ,uint256[]);
    event resetMix(uint256 _series_id, uint256[]);
    event resetReward(uint256 _series_id, Reward);
    event resetLevel(uint256,uint256[]);
    event reset_ratio(uint256);

    uint256 public constant MIN_NAME_LENGTH = 4;
    uint256 public constant MIN_IMAGE_LINK_LENGTH = 8;
    uint256 public constant MAX_IMAGE_LINK_LENGTH = 128;
    uint256 public constant MIX_TRUE_LOW_LEVEL_NUMBER = 5;
    uint256 public constant DEFAUL_DECIMAL_PLACES = 100;
    struct Config {
        address owner;
        address lable_address;
        address platform_token;
        address key_token;
        address payable prize_pool;
        address flip;
        address nft;
    }

    Config public config;

    enum Grade {S, A, B, C, D}

    struct Box {
        string  name;
        uint256 series_id;
        string  image;
        uint256[] level;
        uint256[] draw;
        uint256[] mix;
        Reward reward;
    }

    struct Reward {
        address[] token;
        uint256[] amount;
    }

    BuildToken public controlledTokenBuilder;

    mapping(uint256 => Box) public box_info;

    uint256[] series_ids;

    constructor(address _owner,
                address _lableAddress,
                address platform_token,
                BuildToken _controlledTokenBuilder,
                address _nft) public {
        controlledTokenBuilder = _controlledTokenBuilder;
        config = Config(_owner, _lableAddress,platform_token,address(0),address(0),address(0),_nft);
    }

    function init(BuildToken.ControlledTokenConfig memory _config,address _flip,address  _prize_pool)onlyOwner public {
        require(_flip != address(0) &&
                config.flip == address(0) &&
                config.key_token == address(0),
                "BlindBox Err:Can not be re-initialized");
        ControlledToken token = _createToken(_config.name, _config.symbol, _config.decimals, _config.controller);
        config.key_token = address(token);
        config.flip = _flip;
        flip(_flip).init(config.key_token);
        config.prize_pool = payable(_prize_pool);
    }

    function MintBox(Box memory _box)
        onlyOwner
        checkBox(_box) public {
        box_info[_box.series_id] = _box;
        series_ids.push(_box.series_id);
        emit mint_box(_box.series_id, _box.name);
    }

    //ptoken - > k token ratio default 2 decimal places
    uint256 ratio = 10000;
    function Draw(uint256 _number, address _inviter) public
    onlynumberof(_number)
    {
        //keytoken(_number) * ratio = ptoken
        uint256 drawNumber = _number * 10 ** 18 / DEFAUL_DECIMAL_PLACES * ratio;
        require(_inviter != address(0), "BlindBox Err:inviter cannot equal address(0)");
        WrappedToken platform_token = WrappedToken(config.platform_token);
        uint256 amount = platform_token.allowance(msg.sender, address(this));
        require(amount >= drawNumber , "BlindBox Err:amount cannot than allowance");
        TransferHelper.safeTransferFrom(config.platform_token, msg.sender, address(this), drawNumber);
        platform_token.burn(drawNumber/2, msg.sender);
        TransferHelper.safeTransfer(config.platform_token, config.prize_pool, drawNumber / 10 * 4);
        TransferHelper.safeTransfer(config.platform_token, config.lable_address, drawNumber / 100 * 5);
        TransferHelper.safeTransfer(config.platform_token, _inviter, drawNumber / 100 * 5);
        _mint(msg.sender, _number*10**18, _number);
        emit draw(msg.sender, _number);
    }

    function ResetRatio(uint256 _ratio) onlyOwner public {
        ratio = _ratio;
        emit reset_ratio(_ratio);
    }

    function mintKey(address sender,uint256 number)external onlyFlip{
        if (number == 1){
            _mint(sender, 1*10**18, 1);
        }else{
            _mint(sender, 10*10**18, 1);
        }
    }

    function DrawOut(uint256 _series_id, uint256 _number) public
    onlyBox(_series_id)
    onlynumberof(_number)
    {
        WrappedToken key_token = WrappedToken(config.key_token);
        uint256 amount = key_token.allowance(msg.sender, address(this));
        require(amount == _number * 10 ** 18, "BlindBox Err:amount cannot than allowance");
        Box storage box = box_info[_series_id];
        nft(config.nft).Draw(msg.sender,_number,1,_series_id,box.draw,box.level);
        ControlledToken(config.key_token).controllerBurn(msg.sender,amount);
        emit draw_out(msg.sender, _series_id, _number);
    }

    function MixTrue(uint256 _series_id, uint256 _grade_id,uint256[] memory _tokens_id)
        onlyBox(_series_id)
        onlyGrade(_grade_id)
        checkTokenIdLens(_series_id,_tokens_id)
        public {
        Box storage box = box_info[_series_id];
        nft(config.nft).gradeCompose(msg.sender,_series_id,box.mix,box.level,_grade_id,_tokens_id);
    }

    function Convert(uint256 _series_id,uint256[] memory _token_ids)
        onlyBox(_series_id) public {
        nft(config.nft).cashCheckByTokenID(msg.sender,_series_id,box_info[_series_id].level,_token_ids);
        _sendReward(_series_id);
    }

    receive() external payable{}

    function _sendReward(uint256 _series_id) internal {
        Box storage _box = box_info[_series_id];
        uint256 reward_lens = _box.reward.token.length;
        for (uint i = 0; i < reward_lens; i++) {
            address token = _box.reward.token[i];
            uint256 amount = _box.reward.amount[i];
            PrizePool(config.prize_pool).sender(msg.sender,token, amount);
        }
    }

    event resetOwner(address);
    function ResetOwner(address _owner) onlyOwner public{
        config.owner = _owner;
        emit resetOwner(_owner);
    }

    function ResetDraw(uint256 _series_id, uint256[] memory _draw)
        onlyOwner
        onlyBox(_series_id) public {
        box_info[_series_id].draw = _draw;
        emit resetDraw(_series_id, _draw);
    }

    function ResetMix(uint256 _series_id, uint256[] memory _mix)
        onlyOwner
        onlyBox(_series_id) public {
        box_info[_series_id].mix = _mix;
        emit resetMix(_series_id, _mix);
    }

    function ResetReward(uint256 _series_id, Reward memory _reward)
        onlyOwner
        onlyBox(_series_id)public {
        require(_reward.token.length == _reward.amount.length,
                "BlindBox Err: reward token not equal reward amount");
        box_info[_series_id].reward = _reward;
        emit resetReward(_series_id, _reward);
    }

    function QueryBox(uint256 _series_id) public view returns (Box memory){
        return box_info[_series_id];
    }

    function QueryConfig() public view returns (Config memory){
        return config;
    }

    function QuerySeriesIds() public view returns (uint256[] memory){
        return series_ids;
    }

    function QueryRatio() view public returns (uint256 ,uint256){
        return (1*10**18/DEFAUL_DECIMAL_PLACES*ratio
                ,10*10**18/DEFAUL_DECIMAL_PLACES*ratio);
    }

    function QueryDraws(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].draw;
    }

    function QueryLevels(uint256 _series_id) public view returns (uint256[] memory){
        return box_info[_series_id].level;
    }

    function QueryImage(uint256 _series_id) public view returns (string memory){
        return box_info[_series_id].image;
    }

    function QueryBoxs(
                       uint256 start,
                       uint256 end
                       ) public view returns (Box[] memory, uint256){


        uint256 lens = series_ids.length;
        if (lens <= 0 || start > end || start > lens){
            Box[] memory result;
            return (result, lens);
        }
        uint256 index = end;
        if (end > lens) {
            index = lens;
        }
        if (index - start > 30){
            index = start + 30;
        }
        Box[] memory result = new Box[](index - start);
        uint id;
        for (uint i = start; i < index; i++) {
            result[id] = box_info[series_ids[i]];
            id++;
        }
        return (result, lens);
    }

    function _mint(address to, uint256 amount, uint256 number) internal {
        ControlledToken(config.key_token).controllerMint(to, amount, number);
    }

    function _createToken(
        string memory name,
        string memory token,
        uint8 decimals,
        TokenControllerInterface controller
    ) internal returns (ControlledToken){
        return controlledTokenBuilder.createControlledToken(
            BuildToken.ControlledTokenConfig(name, token, decimals, controller));
    }

    modifier onlyOwner(){
        require(msg.sender == config.owner, "BlindBox Err: Unauthoruzed");
        _;
    }

    modifier onlyFlip(){
        require(msg.sender == config.flip, "BlindBox Err: Unauthoruzed");
        _;
    }

    modifier onlynumberof(uint256 _number){
        require(_number == 1 || _number == 10, "BlindBox Err:draw number can only be equal to 1 or 10");
        _;
    }

    modifier checkBox(Box memory _box){
        uint256 nameLen = bytes(_box.name).length;
        require(nameLen >= MIN_NAME_LENGTH, "BlindBox Err: name length must be less than MIN_NAME_NAME");
        Box storage _box_info = box_info[_box.series_id];
        require(_box_info.series_id == 0, "BlindBox Err: Box already exists");
        uint256 imageLinkLen = bytes(_box.image).length;
        require(imageLinkLen >= MIN_IMAGE_LINK_LENGTH,
                "BlindBox Err: ImageLink length must be less than MIN_IMAGE_LINK_LENGTH");
        require(imageLinkLen <= MAX_IMAGE_LINK_LENGTH,
                "BlindBox Err: ImageLink length must be small than MAX_IMAGE_LINK_LENGTH");
        require(_box.reward.token.length == _box.reward.amount.length,
                "BlindBox Err: reward token not equal reward amount");
        _;
    }

    modifier onlyGrade(uint256 _grade_id){
        require(_grade_id <= 5,"BlindBox  Err:Grade does not exist");
        _;
    }

    modifier checkTokenIdLens(uint256 _series_id,uint256[] memory _tokens_id){
        require(_tokens_id.length ==  MIX_TRUE_LOW_LEVEL_NUMBER,"BlindBox Err: Only receive 5 nft token id");
        _;
    }

    modifier onlyBox(uint256 _series_id){
        Box storage _box_info = box_info[_series_id];
        require(_box_info.series_id != 0, "BlindBox Err: series not found");
        _;
    }
}
