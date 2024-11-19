// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Betting} from "../src/betting.sol";
import {USDT} from "../src/usdt.sol";

contract CounterTest is Test {
    Betting public BET;
    USDT public USDT_ERC;
    uint256 ONE_USDT = 1_000_000;
    address public Deployer = address(0x1);
    address public userA = address(0x2);
    address public userB = address(0x3);
    constructor(){
        vm.startPrank(Deployer);
        BET = new Betting();
        USDT_ERC = new USDT();
        USDT_ERC.mintToAddress(userA, 1_000 * ONE_USDT);
        USDT_ERC.mintToAddress(userB, 1_000 * ONE_USDT);
        vm.stopPrank();
    }
    function testBet()public{
        vm.startPrank(userA);
        USDT_ERC.approve(address(BET),1_000*ONE_USDT);
        uint8 _rate1 = 3;
        uint8 _rate2 = 5;
        uint256 _poolAmount = 10*ONE_USDT;
        uint256 _betPrice = 92000;
        bool _longShortCheck = true;
        uint256 _futureTime = 1732010600; //15h53 19/11/2024
        address token = address(USDT_ERC);
        bool _roomPrivacy = false;
        string memory _link = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&date=1679629737";
        bytes32 idRoom = BET.CreateBetBTC(_rate1, _rate2, _poolAmount, _betPrice, _longShortCheck, _futureTime, token, _roomPrivacy, _link);
        uint256 amountAbet = _poolAmount * _rate1;
        assertEq(USDT_ERC.balanceOf(userA),1_000*ONE_USDT - amountAbet,"should be equal");
        bytes memory bytesCodeCall = abi.encodeCall(
            BET.CreateBetBTC,
            (_rate1, _rate2, _poolAmount, _betPrice, _longShortCheck, _futureTime,
             0x1a65e6E37741EEfb7978A8B81AECab8F8dF02dD6, 
             _roomPrivacy, _link)
        );
        console.log("CreateBetBTC:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  

        vm.stopPrank();

        //userB join
        vm.startPrank(userB);
        USDT_ERC.approve(address(BET),1_000*ONE_USDT);
        BET.JoinBetBTC(idRoom);
        uint256 amountBbet = _poolAmount * _rate2;
        assertEq(USDT_ERC.balanceOf(userB),1_000*ONE_USDT - amountBbet,"should be equal");
        bytesCodeCall = abi.encodeCall(
            BET.JoinBetBTC,
            (0x1f9ead741ebe5b2cb30a07e4c145ac64852af581c0de3d4d169ad8d4406c022c)
        );
        console.log("JoinBetBTC:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
        bytesCodeCall = abi.encodeCall(
            BET.CheckResult,
            (0x1f9ead741ebe5b2cb30a07e4c145ac64852af581c0de3d4d169ad8d4406c022c)
        );
        console.log("CheckResult:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
        vm.stopPrank();

    }
}
