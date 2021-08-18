pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../swap/IPancakeRouter.sol";
import "../token/WrappedToken.sol";
import "../TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/drafts/ERC20PermitUpgradeable.sol";
contract PrizePool is ERC20PermitUpgradeable{
    event send_log(address,address,uint256);
    event swapEthers(uint256);
    event swapErc20(address,uint256);

    struct Config{
        address build_box_address;
        address platform_token;
        address panacke_router;
        address ether_address;
        address gov_address;
    }

    uint256 constant TwoMinute = 1200;
    uint256 constant Zero = 0;

    Config public config;

    constructor(address _build_box_address,
                address _platform_token,
                address _panacke_router,
                address _ether_address,
                uint256 _min_ether,
                address _gov_address)public{
        config = Config(
                        _build_box_address,
                        _platform_token,
                        _panacke_router,
                        _ether_address,
                        _gov_address
                        );
        min_reward[_ether_address] = _min_ether*10**18;
    }

    mapping(address => uint256) public min_reward;

    function ResetMinReward(address token,uint256 amount) onlyGover public{
        min_reward[token] = amount;
    }

    function SwapErc20(address _token,uint256 _account)
        onlyReward(_token)
        checkMinReward(_token)
        public{
        require(_account > 0 ,"PrizePool Err: account cannot be 0");
        uint amount = WrappedToken(config.platform_token).balanceOf(address(this));
        require(amount >= _account,"PrizePool Err:platform not enough");
        WrappedToken(config.platform_token).approve(config.panacke_router,_account);
        address[] memory path = new address[](2);
        path[0]=config.platform_token;
        path[1]=_token;
        uint256 deadline = now+TwoMinute;
        IPancakeRouter01(config.panacke_router).swapExactTokensForTokens(_account,Zero,path,address(this),deadline);
        emit swapErc20(_token,_account);
    }

    function SwapEthers(uint256 _account)
        onlyReward(config.ether_address)
        checkMinReward(config.ether_address)
        public{
        require(_account > 0 ,"PrizePool Err: account cannot be 0");
        uint amount = WrappedToken(config.platform_token).balanceOf(address(this));
        require(amount >= _account,"PrizePool Err:platform not enough");
        WrappedToken(config.platform_token).approve(config.panacke_router,_account);
        address[] memory path = new address[](2);
        path[0] = config.platform_token;
        path[1] = config.ether_address;
        uint256 deadline = now+TwoMinute;
        IPancakeRouter01(config.panacke_router).swapExactTokensForETH(_account,Zero,path,address(this),deadline);
        emit swapEthers(_account);
    }

    receive() external payable {}

    function sender(address payable to,address token,uint256 amount) onlyBuildBox external{
        if (token == address(0)){
            to.transfer(amount);
        }else{
            TransferHelper.safeTransfer(token,to,amount);
        }
        emit send_log(to,token,amount);
    }

    function QueryConfig() view public returns (Config memory){
        return config;
    }

    function QueryMinReward(address token) view public returns (uint256 amount){
        return min_reward[token];
    }

    modifier onlyReward(address token){
        require(min_reward[token] > 0,"PrizePool Err:reward Not Found");
        _;
    }

    modifier checkMinReward(address _token){
        uint256 amount;
        if (_token == config.ether_address){
            amount = address(this).balance;
        }else{
            amount = WrappedToken(_token).balanceOf(address(this));
        }
        require(amount < min_reward[_token],"PrizePool Err: Token greater than the minimum value");
        _;
    }

    modifier onlyBuildBox{
        require(config.build_box_address == msg.sender,"PrizePool Err: Unauthoruzed");
        _;
    }

    modifier onlyGover{
        require(config.gov_address == msg.sender,"PrizePool Err: Unauthoruzed");
        _;
    }

}
