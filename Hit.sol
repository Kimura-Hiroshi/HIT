// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract H2 is ERC1155 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;

    event ELOG(uint256, string);

    uint256 immutable birthtime;
    address immutable owner;
    uint256 private gBlkNum;
    uint256 private lastMintBlk = gBlkNum;

    address public constant OPADDR = 0x80D9438a6d8FEBfA3c2743524037f6192Ba99d76 ;
    address[3] GREAT3 = [0x765Af9d14CD9Db7636F2A5d7b3512239ECe13cE2,
        0x5cE1DC0983923894E9dE1D60d01670935D2662E3,
        0x981296fd459C0dD3c029e8Bb87429940791265C4];

    mapping(address => tokenInfo) public myToken; //your token created
    mapping(address => tokenHolding[]) public myHoldings; // all your holding tokens
    mapping(uint256 => address) public tokenOwners;
    mapping(uint256 => address[]) public tokenAddresses; // addresses who use this token

    struct tokenHolding {
        uint256 id;
        uint256 amount;
    }

    struct tokenInfo {
        uint256 id;
        string name;
        uint256 supplyQuant;
        string uri;
        uint8 vatality; // Nil or 0 for unwakened; 0 for freezing; 1+ for alive;
    }

    //token mass
    mapping(uint256 => tm) private _tms;  
    struct tm {
        uint256 activeUserNum;
        uint256 txNum;
    }
    mapping(uint256 => uint256) tmPrices; //exchange rate for Ght

    constructor() ERC1155("") {
        _mint(msg.sender, 0, 10**9, "HIT");
        birthtime = block.timestamp;
        owner = msg.sender;

        myToken[msg.sender].id = 0;
        myToken[msg.sender].name = string("HIT");
        myToken[msg.sender].supplyQuant = 10**9;
        myToken[msg.sender].uri = "ipfs://bafybeihlawxv66rywzskydeuu7p5n2z6rlz2gfhhaq2r64cuigmrluwzmu";
        myToken[msg.sender].vatality = 1;

        safeTransferFrom(msg.sender, OPADDR, 0, 9e8, "");
        setApprovalForAll(OPADDR, true);

        tokenOwners[0] = msg.sender;

        tokenAddresses[0] = new address[](1);
        tokenAddresses[0].push(msg.sender);
    }

    // "Mint ONLY Once" and less than 1**10
    function mintMine( string memory strname, uint256 _a,  string memory _uri ) public returns (uint256) {
        require(_a < 1e10, "Too Big Quantity to be minted");
        // "Mint ONLY Once"
        // require(myToken[msg.sender].vatality < 1, "Mint ONLY Once");

        bytes memory _name = stringToBytes(strname);
        _tokenId.increment();
        uint256 _id = _tokenId.current();
        _mint(msg.sender, _id, _a, _name);

        myToken[msg.sender].id = _id;
        myToken[msg.sender].name = string(_name);
        myToken[msg.sender].supplyQuant = _a;
        myToken[msg.sender].uri = _uri;
        myToken[msg.sender].vatality = 1;

        emit ELOG(_id, "New User Mint");

        myHoldings[msg.sender].push(tokenHolding(_id, _a));
        tokenOwners[_id] = msg.sender;
        tokenAddresses[_id] = new address[](1);
        tokenAddresses[_id].push(msg.sender);

        // update token mass
        _tms[_id].activeUserNum = tokenAddresses[_id].length + 1;
        _tms[_id].txNum += 1;
        tmPrices[_id] = tm_price(_tms[_id].activeUserNum, _tms[_id].txNum, _a);

        return _id;
    }

    // Usage Part in Usage Part, Hit Part, Util Part
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function tokenId() public view returns (uint256) {
        require(msg.sender != address(0));
        if (myToken[msg.sender].vatality >= 1) {
            return myToken[msg.sender].id;
        }
        return 0;
    }

    function payByMyToken(
        address dest,
        uint256 _amount,
        string memory notes
    ) public {
        uint256 _tid = tokenId();
        // require(_tid>= 1, "Wrong Token ID");
        uint256 _balance = balanceOf(msg.sender, _tid);
        require(_balance >= _amount, "Not enough balance");
        require(!isContract(dest), "Contract Address not supported");

        uint256 _afterTax = taxAndTransfer(_amount, _tid);
        safeTransferFrom(msg.sender, dest, _tid, _afterTax, bytes(notes));

        myHoldings[dest].push(tokenHolding(_tid, _amount));
        tokenAddresses[_tid].push(dest);

        prizeAndTransfer(_tid, _amount);
        emit ELOG(_amount, "payByMyToken");
    }

    function payByHIT(
        address dest,
        uint256 _amount,
        string memory notes
    ) public {
        require(!isContract(dest), "Contract Address not supported");
        uint256 _balance = balanceOf(msg.sender, 0);
        require(_balance >= _amount, "Not enough balance");

        uint256 _afterTax = taxAndTransfer(_amount, 0);
        safeTransferFrom(msg.sender, dest, 0, _afterTax, bytes(notes));

        myHoldings[dest].push(tokenHolding(0, _amount));
        tokenAddresses[0].push(dest);

        prizeAndTransfer(0, _amount);
        emit ELOG(_amount, "payByHIT");
    }

    function payByOtherToken(
        address dest,
        uint256 _tid,
        uint256 _amount,
        string memory notes
    ) public {
        require(_tid >= 0 && _tid <= _tokenId.current(), "Wrong Token ID");
        uint256 _balance = balanceOf(msg.sender, _tid);
        require(_balance >= _amount, "Not enough balance");
        require(!isContract(dest), "Contract Address not supported");

        uint256 _afterTax = taxAndTransfer(_amount, _tid);
        safeTransferFrom(msg.sender, dest, _tid, _afterTax, bytes(notes));

        myHoldings[dest].push(tokenHolding(_tid, _amount));
        tokenAddresses[_tid].push(dest);

        prizeAndTransfer(_tid, _amount);
        emit ELOG(_amount, "payByOtherToken");
    }

    // @notice override safeTransferFrom with updates of tokens
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);

        updateTokenAddresses(id, to);
        _tms[id].txNum += 1;

        // update toke mass , every 5 block
        if (block.number.mod(5) == 0) {
            _tms[id].activeUserNum = tokenAddresses[id].length + 1;
            tmPrices[id] = tm_price(
                _tms[id].activeUserNum,
                _tms[id].txNum,
                myToken[tokenOwners[id]].supplyQuant
            );
        }
    }

    // query categary
    function myTokenBalance() public returns (uint256) {
        uint256 _tid = tokenId();
        require(_tid >= 0, "Wrong Token ID");
        _tms[_tid].txNum += 1;

        uint256 _b = balanceOf(msg.sender, _tid);
        emit ELOG(_b, "myTokenBalance");
        return _b;
    }

    function myTokenById(uint256 _tid) public returns (uint256) {
        require(_tid >= 0 && _tid <= _tokenId.current(), "Wrong Token ID");
        _tms[_tid].txNum += 1;
        return balanceOf(msg.sender, _tid);
    }

    function myTokenOfHIT() public view returns (uint256) {
        return balanceOf(msg.sender, 0);
    }

    // all balance quoted in HIT, total value returned.
    function myAssetsInHIT() public returns (uint256) {
        tokenHolding[] memory _tks = myHoldings[msg.sender];
        if (_tks.length < 1) return 0;
        uint256 _total;
        for (uint256 i = 0; i < _tks.length; i++) {
            uint256 _tempid = _tks[i].id;
            uint256 _value = _tks[i].amount * tmPrices[_tempid];
            _total += _value;
        }
        emit ELOG(_total, "myAssetsInHIT");
        return _total;
    }

    // update tokenAddresses
    function updateTokenAddresses(uint256 _tid, address _addr)
        private 
        returns (bool)
    {
        require(_tid >= 0 && _tid <= _tokenId.current(), "Wrong Token ID");
        for (uint256 index = 0; index < tokenAddresses[_tid].length; index++) {
            if (tokenAddresses[_tid][index] == _addr) return true;
        }
        tokenAddresses[_tid].push(_addr);
        return false;
    }

    // @notice disable the function safeBatchTransferFrom(from, to, ids, amounts, data);
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public view override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        require(to == address(0));
        require(ids.length > 0);
        require(amounts.length > 0);
        require(data.length > 0);
        revert();
    }

    function tm_price(
        uint256 activeUserNum,
        uint256 txNum,
        uint256 supplyQuant
    ) private pure returns (uint256 tmPrice) {
        // uint256 _usage = ( activeUserNum +1 ).mul * ( txNum + 1 );
        uint256 _usage = activeUserNum.add(1);
        _usage = _usage.mul(txNum + 1).mul(1e9); // Ght
        tmPrice = _usage.div(supplyQuant); //big dinominator 1 - 1e9
        tmPrice = (tmPrice > 1e15) ? 1e15 : tmPrice;
        tmPrice = (tmPrice < 1e6) ? 1e6 : tmPrice;
        return tmPrice;
    }

    // @return amount after taxing
    // tax rate = 7%%
    function taxAndTransfer(uint256 _amount, uint256 _tid)
        private
        returns (uint256)
    {
        uint256 tax;
        if (_amount < 1e4) {
            tax = 0;
        } else {
            tax = _amount.mul(7).div(1e4);
            uint8 _r = uint8(getRand().mod(3));
            _safeTransferFrom(msg.sender, GREAT3[_r], _tid, tax, "Taxing");
        }
        return _amount - tax;
    }

    // Prize for each transaction, 7%% from Operator's account
    function prizeAndTransfer(uint256 _tid, uint256 _amount) private {
        uint256 _price = getPrice(_tid);
        uint256 _prize;
        if (_amount < _price) {
            _prize = 0;
        } else {
            _prize = _amount.mul(7).div(1e4).mul(_price); // Ght
            _safeTransferFrom(OPADDR, msg.sender, 0, _prize * 1e9, "Prize");
        }
    }

    // update _tms first
    function getPrice(uint256 _tid) private view returns (uint256) {
        if (_tid == 0) return 1;
        require(_tid <= _tokenId.current(), "Wrong Token ID");
        return tmPrices[_tid];
    }

    // 4 blocks a minute, 4 * 60 * 24 * 365 = 2,102,400 blocks per year
    // Missing rate: 5%% of the circulation
    function newMint() private returns (uint256 _newMint) {
        require(block.number >= lastMintBlk + 2e6);
        lastMintBlk = block.number;
        uint256 circulation = 1e9 - balanceOf(OPADDR, 0);
        if (circulation > 5000) {
            _newMint = circulation.mul(5).div(10000);
        } else {
            return 0;
        }

        // new mint
        _mint(OPADDR, 0, _newMint, "New Mint");
        // distributing to active accounts
        uint256 _activeNum;
        for (uint256 ii = 0; ii < _tokenId.current(); ii++) {
            _activeNum += tokenAddresses[ii].length;
        }
        uint256 _amountEach;
        if (_newMint > _activeNum) {
            _amountEach = _newMint.div(_activeNum);
            for (uint256 ii = 0; ii < _tokenId.current(); ii++) {
                for (uint256 _i = 0; _i < tokenAddresses[ii].length; _i++) {
                    safeTransferFrom(
                        OPADDR,
                        tokenAddresses[ii][_i],
                        0,
                        _amountEach,
                        "Replenishing to each"
                    );
                }
            }
        }
        emit ELOG(_newMint, "circulation newMint");
        return _newMint;
    }

    // Shares will be paid via HIT
    receive() external payable {
        // starter address;
        address payable starter;
        starter = payable(address(0xee3d8dFe01180ba60fa4a32193AeEdf167a6F49E));
        starter.transfer(msg.value);

        uint256 _wei = msg.value;
        _wei = _wei.mul(25).div(1e15); //0.025

        // reward via HIT
        payByHIT(payable(msg.sender), _wei, "");

        newMint();
        emit ELOG(msg.value, "SharesPaid");
    }

    fallback() external {}

    /////////////////////////////////
    function stringToBytes(string memory source)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 result;
        assembly {
            result := mload(add(source, 32))
        }
        return abi.encodePacked(result);
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function getRand() private view returns (uint256) {
        uint256 _r1 = block.timestamp - 1632455555;
        bytes memory _b = abi.encodePacked(block.coinbase);
        uint256 _r2 = uint256(keccak256(_b));

        _r1 = (block.number + 1 - gBlkNum) + _r1; // blk nums + some seconds
        uint256 _ts = block.timestamp + 1 - birthtime;
        _ts = _ts.mod(_r1); // blk generating time
        return _r2.mod(_ts);
    }
}

/** ################# */
library Counters {
    struct Counter {
        uint256 _value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }
}
