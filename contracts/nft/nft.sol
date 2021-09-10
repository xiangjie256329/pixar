// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract nft is ERC721 ,VRFConsumerBase{
     struct Config {
        address  owner;
        address  lockContract;
        address  blindBox;
        address  flip;
    }

    Config public config;

    mapping (uint256 => uint256) private _tokenSerialNumber;
    mapping (uint256 => string) private _tokenTypeNumber;
    mapping (uint256 => string) private _tokenGrade;   
    mapping (uint256 => uint256) private _gradeSymbol;       
    mapping (uint256 => uint256) private _tokenGradeId;     

    mapping (address => uint256[]) private _addrAllTokenId; 
    mapping (uint256 => uint256) private _tokenToIndex;    

    string public lastresult;
    uint public lastblocknumberused; 
    bytes32 public lastblockhashused;
    uint256 max_page;
    uint256 private lastTokenId; 

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 private linkRand;
    uint256 private randNumber;
    
    event DrawCard(address user, uint256 tokenId, uint256 tokenSerialNumber, string tokenTypeNumber);
    event DrawCardForD(address user, uint256 tokenId, uint256 tokenSerialNumber, string tokenTypeNumber);
    constructor (
        string memory name_, 
        string memory symbol_,
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee
        ) VRFConsumerBase(
            _vrfCoordinator, 
            _linkToken 
        )
        public ERC721(name_, symbol_) 
        {
        config.owner = msg.sender;
        config.lockContract = address(0);
        config.blindBox = address(0);
        config.flip = address(0);
        max_page = 50;
        lastTokenId = 0;

        keyHash = _keyHash;
        fee = _fee; 
    }

    modifier authentication(){
        require(
            msg.sender == config.flip || msg.sender ==config.lockContract || msg.sender ==config.blindBox,
            "Nft Err: Unauthoruzed");
        _;
    }

    event initLog(address addrOne, address addrTwo, address addrThree);
    function init(address blindBox,address flip, address lock_contract) public  {
        require(msg.sender == config.owner, "Nft Err: Unauthoruzed");
        require(config.blindBox == address(0) &&
                config.flip == address(0) &&
                config.lockContract == address(0),
                "Nft Err:Can not be re-initialized");
        config.flip = flip;
        config.lockContract = lock_contract;
        config.blindBox = blindBox;
        getRandomNumber();
        emit initLog(blindBox, flip, lock_contract);
    }

    function queryConfig() public view returns(address  blindBox, address flip, address lockContract){
        blindBox = config.blindBox;
        flip = config.flip;
        lockContract = config.lockContract;
    }

    function Draw(address to, uint256 number, uint256 IsDCard, uint256 _seriesId, uint256[] memory _drawPr,
    uint256[] memory _gradeNumber)  authentication public
    {
        uint256 _pecision = _drawPr[0] + _drawPr[1] +_drawPr[2] +_drawPr[3];
        for (uint256 i = 0; i < number; i++) {
            uint256 tokenids = lastTokenId;
            _safeMint(to, lastTokenId);

            if (IsDCard == 0){
                drawCardForD(to, tokenids, _seriesId, _gradeNumber);
            }else {
                drawCard(to,tokenids,_seriesId,_pecision,_drawPr,_gradeNumber);
            }

        }  
    }

    function getAddrTokenId(address _user, uint index) public view returns(uint256)
    {
      return _addrAllTokenId[_user][index];
    }

    function getAddrIndex(uint256 _tokenId) public view returns(uint256)
    {
      return _tokenToIndex[_tokenId];
    }

    function getAddrAllTokenIds(address _user, uint256 _pageSize, uint256 _page) public view 
    returns(uint256[] memory result) 
    {   
        uint256 total =  _addrAllTokenId[_user].length;
        require( _pageSize * (_page - 1)  < total, "Nft Err: No more NFT");
        
        uint256 pageSize = _pageSize;
        uint256 page = _page;
        if (pageSize > max_page) {
            pageSize = max_page;
        }

        uint256 start_index = (page - 1) * pageSize;
        uint256 end_index;

        if ( total-start_index <  pageSize)
        {
            end_index = total; 
        }
        else           
        {
            end_index = start_index + pageSize; 
        }

        result = new uint256[](pageSize);

        uint256 j = 0 ;
        for (uint256 i = start_index; i < end_index ; i++ ){ 
            result[j] = getAddrTokenId(_user,i);
            j++;
        }
        return result;
    }

    function _mint(address to, uint256 tokenId) internal virtual override{
        super._mint(to , tokenId);
        _addrAllTokenId[to].push(tokenId);
        _tokenToIndex[tokenId] = _addrAllTokenId[to].length - 1;
        lastTokenId ++;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override{
        super._transfer(from, to , tokenId);

        uint256 len = _addrAllTokenId[from].length; 
        uint256 tokenId_index = _tokenToIndex[tokenId]; 
        uint256 last_tokeniId = _addrAllTokenId[from][len-1]; 

        _addrAllTokenId[from][tokenId_index] = last_tokeniId; 
        _tokenToIndex[last_tokeniId] = tokenId_index;         

        _addrAllTokenId[from].pop(); 
        uint256 tolen = _addrAllTokenId[to].length;
        _addrAllTokenId[to].push(tokenId);
        _tokenToIndex[tokenId] = tolen;  
    }

    function burn(address user, uint256 tokenId) public { 
        require(user == ownerOf(tokenId), 'Nft Err: tokenId no belong to user');

        delete _tokenSerialNumber[tokenId];
        delete _tokenGrade[tokenId];
        delete _tokenGradeId[tokenId];
        delete _tokenTypeNumber[tokenId];
        delete _gradeSymbol[tokenId];
        
        uint256 len = _addrAllTokenId[user].length; 
        uint256 tokenId_index = _tokenToIndex[tokenId]; 
        uint256 last_tokeniId = _addrAllTokenId[user][len-1];

        _addrAllTokenId[user][tokenId_index] = last_tokeniId; 
        _tokenToIndex[last_tokeniId] = tokenId_index;         

        _addrAllTokenId[user].pop(); 
        delete  _tokenToIndex[tokenId];  
    
        _burn(tokenId);
    }
    
    function sha(uint128 wager) private returns(uint256)
    {
        linkRand = linkRand + randNumber;
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.coinbase, now, lastblockhashused, wager, linkRand)));
    }

    function drawCard(address to, uint256 tokenId, uint256 _seriesId, uint256 _pecision,
    uint256[] memory _drawPr,uint256[] memory _gradeNumber) internal returns(uint){
        uint128 wager = uint128(tokenId);           
        lastblocknumberused = block.number - 1 ;
        lastblockhashused = blockhash(lastblocknumberused);
        uint128 lastblockhashused_uint = uint128(uint(lastblockhashused)) + wager;
        uint256 hashymchasherton = sha(lastblockhashused_uint);

        uint256 rand = hashymchasherton % _pecision;

        if( rand <= _drawPr[0])
            {
                addAttribute(tokenId, _seriesId, "S", 1, _gradeNumber[0], hashymchasherton);
            }else if ( rand <= _drawPr[0] + _drawPr[1])
            {   
                addAttribute(tokenId, _seriesId, "A", 2, _gradeNumber[1], hashymchasherton);
            }else if ( rand <= _drawPr[0] +_drawPr[1] + _drawPr[2])
            {   
                addAttribute(tokenId, _seriesId, "B", 3, _gradeNumber[2], hashymchasherton);
            }else {
                addAttribute(tokenId, _seriesId, "C", 4, _gradeNumber[3], hashymchasherton);
            }
            emit DrawCard(to, tokenId, _tokenSerialNumber[tokenId], _tokenTypeNumber[tokenId]);     
    }

    function addAttribute(uint256 tokenId,uint256 seriesId, string memory tokenGrade, uint256 gradeSymbol,
    uint256 gradeNumber,uint256 hashymchasherton) private
    {
                _tokenSerialNumber[tokenId] = seriesId;
                _tokenGrade[tokenId] = tokenGrade;
                _gradeSymbol[tokenId] = gradeSymbol;
                
                if (gradeNumber == 1){
                    _tokenGradeId[tokenId] = 1;
                    _tokenTypeNumber[tokenId] = strConcat(tokenGrade, "1");
                }else {
                    uint256 randId = hashymchasherton % gradeNumber + 1;
                    _tokenGradeId[tokenId] = randId;
                    _tokenTypeNumber[tokenId] = strConcat(tokenGrade, toString(randId));
                }
    }

    function drawCardForD(address to, uint256 tokenId, uint256 _seriesId,uint256[] memory _gradeNumber) internal {
        uint128 wager = uint128(tokenId);           
        lastblocknumberused = block.number - 1 ;
        lastblockhashused = blockhash(lastblocknumberused);
        uint128 lastblockhashused_uint = uint128(uint(lastblockhashused)) + wager;
        uint256 hashymchasherton = sha(lastblockhashused_uint);

        addAttribute(tokenId, _seriesId, "D", 5, _gradeNumber[4], hashymchasherton);
        emit DrawCardForD(to, tokenId, _tokenSerialNumber[tokenId],_tokenTypeNumber[tokenId]);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++)bret[k++] = _ba[i];
        for (uint j = 0; j < _bb.length; j++) bret[k++] = _bb[j];
        return string(ret);
    }

    function getNftInfo(uint256 tokenId) public view returns(uint256 tSerialNumber,
      string memory tTypeNumber, string memory tGrade, uint256  tGradeId){
        tSerialNumber = _tokenSerialNumber[tokenId];
        tTypeNumber = _tokenTypeNumber[tokenId];
        tGrade = _tokenGrade[tokenId];
        tGradeId = _tokenGradeId[tokenId]; 
    }
    
    function getOwnerAddr() public view returns(address){
        return config.owner;
    }

    function exists(uint256 tokenId) public view returns(bool) {
         return _exists(tokenId);
    }

    event gradeComposelog(string res, uint256 tokenId, uint256 tokenSerialNumber, string tokenTypeNumber);

    function gradeCompose(address user, uint256 seriesId,uint256[] memory _composePrs, uint256[] memory gradeNumbers,
    uint256 _grade,uint256[] memory tokenIds) authentication public 
    {   
        address _user = user;
        uint256 _pecision = 100000;
        uint256 _seriesId = seriesId; 
        uint256 grade = _grade;
        uint256[] memory _gradeNumbers = gradeNumbers;

        require(tokenIds.length == 5, 'Nft Err: []tokenIds quantity not five');

        require(
                  checkSeriesId(_seriesId,_tokenSerialNumber[tokenIds[0]], _tokenSerialNumber[tokenIds[1]], 
                  _tokenSerialNumber[tokenIds[2]], _tokenSerialNumber[tokenIds[3]], _tokenSerialNumber[tokenIds[4]]),
                  'Nft Err: Not all the five nft belonging to the same series'
          );

        require(
                  checkNftOwner(_user, tokenIds[0], tokenIds[1], tokenIds[2], tokenIds[3], tokenIds[4]),
                  'Nft Err: Not all the five nft belong to this address'
          );

        require(  
                  checkNftGrade(grade,_gradeSymbol[tokenIds[0]], _gradeSymbol[tokenIds[1]], _gradeSymbol[tokenIds[2]],
                   _gradeSymbol[tokenIds[3]], _gradeSymbol[tokenIds[4]]),
                  'Nft Err: The grades of the five nft are different'
        );
        
        burn(_user,tokenIds[0]);
        burn(_user,tokenIds[1]);
        burn(_user,tokenIds[2]);
        burn(_user,tokenIds[3]);
        burn(_user,tokenIds[4]);

        uint128 wager = uint128(1);             
        lastblocknumberused = block.number - 1 ;
        lastblockhashused = blockhash(lastblocknumberused);
        uint128 lastblockhashused_uint = uint128(uint(lastblockhashused)) + wager;
        uint256 hashymchasherton = sha(lastblockhashused_uint);
        uint256 rand = hashymchasherton % _pecision;
        
        uint256 ltId = lastTokenId;
        _safeMint(_user, lastTokenId);

        string memory res;
        if ( rand < _composePrs[grade-2])
        {
            res = "win";
            if( grade == 2)
            {   
                addAttribute(ltId, _seriesId, "S", 1, _gradeNumbers[0], hashymchasherton);
            }
            else if ( grade == 3 )
            {   
                addAttribute(ltId, _seriesId, "A", 2, _gradeNumbers[1], hashymchasherton);
            }
            else if ( grade == 4 )
            {   
                addAttribute(ltId, _seriesId, "B", 3, _gradeNumbers[2], hashymchasherton);
            }
            else 
            {
                addAttribute(ltId, _seriesId, "C", 4, _gradeNumbers[3], hashymchasherton);
            }
        }
        else
        {
            res = "loss";
            if( grade == 2)
            {       
                addAttribute(ltId, _seriesId, "A", 2, _gradeNumbers[1], hashymchasherton);
            }
            else if ( grade == 3 )
            {   
                addAttribute(ltId, _seriesId, "B", 3, _gradeNumbers[2], hashymchasherton);
            }
            else if ( grade == 4 )
            {
                addAttribute(ltId, _seriesId, "C", 4, _gradeNumbers[3], hashymchasherton);
            }
            else
            {
                addAttribute(ltId, _seriesId, "D", 5, _gradeNumbers[4], hashymchasherton);
            }
        }
        emit gradeComposelog(res, ltId, _tokenSerialNumber[ltId], _tokenTypeNumber[ltId]);  
    }

    function checkSeriesId(uint256 _seriesId,uint256 _id1, uint256 _id2, uint256 _id3, uint256 _id4,uint256 _id5) public pure returns(bool)
    {
        if (_id1 == _seriesId &&  _id2 == _seriesId && _id3 == _seriesId && _id4 == _seriesId && _id5 == _seriesId)
            {
            return true;
            }else{
            return false;
            }
    }

    function checkNftOwner(address user,uint256 id_1, uint256 id_2, uint256 id_3, 
    uint256 id_4,uint256 id_5) public view returns(bool)
    {
        if (ownerOf(id_1) == user && ownerOf(id_2) == user && ownerOf(id_3) == user && ownerOf(id_4) == user && ownerOf(id_5) == user)
        {
            return true;
        }else{
            return false;
        }
    }

    function checkNftGrade(uint256 _grade, uint256 _id1, uint256 _id2, 
    uint256 _id3, uint256 _id4,uint256 _id5) public pure returns(bool)
    {   
        if (_id1 == _grade &&  _id2 == _grade && _id3 == _grade && _id4 == _grade && _id5 == _grade)
        {
          return true;
        }else{
          return false;
        }
    }

    event cashCheckByTokenIdLog(uint256 _seriesId);
    function cashCheckByTokenID(address _user,uint256 _seriesId,uint256[] memory _gradeNumbers, 
    uint256[] memory _tokenIds) authentication  public 
    {   
        uint256 cardNumber = _gradeNumbers[0] +_gradeNumbers[1] +_gradeNumbers[2] +_gradeNumbers[3] +_gradeNumbers[4];
        require(cardNumber == _tokenIds.length, 'Nft Err: Insufficient number of NFTs');

        address  user = _user;
        uint128 S_res = 0;
        uint128 A_res = 0;
        uint128 B_res = 0;
        uint128 C_res = 0;
        uint128 D_res = 0;

        uint128 start;
        for (uint256 i = 0; i < _tokenIds.length; i++){
            string  memory existLog = strConcat(toString(_tokenIds[i]), " Tokenid does not exist");
            require( exists(_tokenIds[i]), existLog);
            require(_tokenSerialNumber[_tokenIds[i]] == _seriesId, 'Nft Err: Not all nft belonging to the same series');

            if (_gradeSymbol[_tokenIds[i]] == 1){
                start = S_res;
            }else if (_gradeSymbol[_tokenIds[i]] == 2) {
                start = A_res;
            }else if (_gradeSymbol[_tokenIds[i]] == 3) {
                start = B_res;
            }else if (_gradeSymbol[_tokenIds[i]] == 4) {
                start = C_res;
            }else {
                start = D_res;
            }

            if (start & (1 << (_tokenGradeId[_tokenIds[i]] - 1)) == 0 ){
                start = uint128(start | 1 << (_tokenGradeId[_tokenIds[i]] - 1));
                if (_gradeSymbol[_tokenIds[i]] == 1){
                    S_res = start ;
                }else if (_gradeSymbol[_tokenIds[i]] == 2) {
                    A_res = start;
                }else if (_gradeSymbol[_tokenIds[i]] == 3) {
                    B_res = start;
                }else if (_gradeSymbol[_tokenIds[i]] == 4) {
                    C_res = start;
                }else {
                    D_res = start;
                }
                burn(user, _tokenIds[i]);
            }
        }

        uint256[] memory gradeNumbers_ = _gradeNumbers;
        require( 
                checkRet(reckon(gradeNumbers_[0]),S_res,reckon(gradeNumbers_[1]),A_res,reckon(gradeNumbers_[2]),
                B_res,reckon(gradeNumbers_[3]),C_res,reckon(gradeNumbers_[4]),D_res), 
                'Error: failed, Please confirm that all are collected'
        );
        emit cashCheckByTokenIdLog(_seriesId);
    }

    function reckon(uint256 num) public pure returns(uint128 res){
        res = 0;
        uint128 c = 1;
        for (uint256 i = 0; i < num ; i++ ){             
            res = res + (c << uint128(i));
        }
    }

    function checkRet(uint128  S_check, uint128 S_res,uint128  A_check, uint128 A_res,uint128 B_check,
    uint128 B_res,uint128 C_check,uint128 C_res,uint128 D_check,uint128 D_res) public pure returns(bool)
    {
        if (S_check == S_res &&  A_check == A_res && B_check == B_res && C_check == C_res && D_check == D_res)
            {
            return true;
            }else{
            return false;
            }
    }

    function getAddrSeriesTokenIds(address _user, uint256 _seriesId, uint256 _pageSize, uint256 _page) public view 
    returns(uint256[] memory result) 
    {   
        address user = _user;
        uint256 total =  _addrAllTokenId[user].length;
        require( _pageSize * (_page - 1)  < total, "Nft Err: No more NFT");
        
        uint256 pageSize = _pageSize;
        uint256 page = _page;
        if (pageSize > max_page) {
            pageSize = max_page;
        }

        uint256 start_index = (page - 1) * pageSize;
        uint256 end_index;

        if ( total-start_index <  pageSize)
        {
            end_index = total; 
        }
        else           
        {
            end_index = start_index + pageSize; 
        }

        result = new uint256[](pageSize);

        uint256 j = 0 ;
        for (uint256 i = start_index; i < end_index ; i++ ){
            if (_tokenSerialNumber[_addrAllTokenId[user][i]] == _seriesId){
                result[j] = getAddrTokenId(user,i);
                j++;
            }else{
                if (end_index < total){
                    end_index++;
                }
            }
        }
        return result;
    }

    function getAddrTokenNumberForSeries(address _user, uint256 _seriesId) public view returns(uint256)
    {
        uint256 len = _addrAllTokenId[_user].length;
        uint256 num = 0;
        for (uint256 i = 0; i < len ; i ++){
            if (_tokenSerialNumber[_addrAllTokenId[_user][i]] == _seriesId){
                num++;
            }
        }
        return num;
    }

    function transferArray(address from, address to, uint256[] memory tokenIds) public virtual{
        uint256 len = tokenIds.length;
        require( len > 0,'Nft Err: TokenID is Null');
        for (uint256 i = 0; i < len ; i ++){
            require(exists(tokenIds[i]),"Nft Err: Tokenid does not exist");
            transferFrom(from, to, tokenIds[i]);
        }
    }
    
    function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        linkRand = randomness;
    }

    function initRandNumber(uint256 num) public{
        randNumber = num;
    }
}
