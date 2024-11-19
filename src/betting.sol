// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts@v4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@v4.9.0/token/ERC20/IERC20.sol";
interface ICallApi {
    function CallApi(string memory link) external view returns (string memory);
}

interface IExtractJsonField {
    function ExtractJsonField(
        string memory jsonStr,
        string memory field
    ) external view returns (string memory);
}
library Uint {
    function trimString(
        string memory _string
    ) public pure returns (string memory) {
        bytes memory b = bytes(_string);
        return string(abi.encodePacked(bytes5(b)));
    }

    function parse(string memory _value) internal pure returns (uint) {
        string memory trimValue = trimString(_value);
        bytes memory _bytes = bytes(trimValue);
        uint _num = 0;
        for (uint i = 0; i < _bytes.length; i++) {
            uint _digit = uint8(_bytes[i]) - 48;
            require(_digit <= 9);
            _num = _num * 10 + _digit;
        }
        return _num;
    }
}

contract Betting is Ownable {
    // Struct
    struct Rate {
        uint8 rate1;
        uint8 rate2;
    }
    struct Time {
        uint lockTime;
        uint futureTime;
    }
    struct Player {
        address owner;
        address participant;
    }
    struct BetInfo {
        address payment;
        uint moneyBet;
        uint BtcPrice;
        uint actualPrice;
        string link;
    }
    struct BetInfoCopy {
        address payment;
        uint moneyBet;
        uint BtcPrice;
        uint actualPrice;
    }
    struct BettingRequest {
        bytes32 id;
        Player players;
        bool ownerBet;
        Rate rate;
        Time time;
        BetInfo info;
        uint pool;
        bool roomPrivacy;
        BettingRequestStatus status;
    }
    struct BettingRequestCopy {
        bytes32 id;
        Player players;
        bool ownerBet;
        Rate rate;
        Time time;
        BetInfoCopy info;
        uint pool;
        bool roomPrivacy;
        BettingRequestStatus status;
    }
    constructor() payable{}

    function convert(
        bytes32 x
    ) internal view returns (BettingRequestCopy memory y) {
        BettingRequest storage bet = mBetting[x];
        y.id = bet.id;
        y.players = bet.players;
        y.ownerBet = bet.ownerBet;
        y.rate = bet.rate;
        y.time = bet.time;
        y.pool = bet.pool;
        y.roomPrivacy = bet.roomPrivacy;
        y.status = bet.status;
        y.info.payment = bet.info.payment;
        y.info.moneyBet = bet.info.moneyBet;
        y.info.BtcPrice = bet.info.BtcPrice;
        y.info.actualPrice = bet.info.actualPrice;
        return y;
    }

    function GetBettingInfo(
        bytes32 _idRoom
    )
        public
        view
        returns (
            bytes32 id,
            Player memory players,
            bool ownerBet,
            Rate memory rate,
            Time memory time,
            BetInfoCopy memory info,
            uint pool,
            bool roomPrivacy,
            BettingRequestStatus status,
            string memory link
        )
    {
        BettingRequest storage x = mBetting[_idRoom];
        BetInfoCopy memory vd = BetInfoCopy({
            payment: x.info.payment,
            moneyBet: x.info.moneyBet,
            BtcPrice: x.info.BtcPrice,
            actualPrice: x.info.actualPrice
        });
        return (
            x.id,
            x.players,
            x.ownerBet,
            x.rate,
            x.time,
            vd,
            x.pool,
            x.roomPrivacy,
            x.status,
            x.info.link
        );
    }

    // Global variable
    uint256 public totalRoom;
    bytes32[] public totalActiveRoom;
    uint8 private returnRIP = 10;
    uint private bettingfee = 1;
    uint public lockTime = 15 minutes;

    enum BettingRequestStatus {
        Open,
        OwnerWin,
        PlayerWin,
        Live
    }

    ICallApi CallApi = ICallApi(0x0000000000000000000000000000000000000101);
    IExtractJsonField ExtractJsonField =
        IExtractJsonField(0x0000000000000000000000000000000000000102);

    // Mapping
    mapping(bytes32 => BettingRequest) public mBetting;
    mapping(address => bytes32[]) public userLive;
    mapping(address => uint) public mTotalUserLive;
    mapping(address => bytes32[]) public userHistory;
    mapping(address => uint8) public mTotalUserHistory;

    mapping(address => uint) lock;

    // Set Function

    function SetPage(uint8 _number) external onlyOwner {
        returnRIP = _number;
    }

    function SetLockTime(uint _lockTime) external onlyOwner {
        lockTime = _lockTime;
    }

    function stringToUint(string memory _value) public pure returns (uint) {
        return Uint.parse(_value);
    }

    event ReceiveMTD(uint value);

    receive() external payable {
        emit ReceiveMTD(msg.value);
    }

    // Main Function
    event CreateBet(address Owner, bytes32 IdRoom);

    function CreateBetBTC(
        uint8 _rate1,
        uint8 _rate2,
        uint _poolAmount,
        uint _betPrice,
        bool _longShortCheck,
        uint _futureTime,
        address token,
        bool _roomPrivacy,
        string calldata _link
    ) public payable returns (bytes32 idRoom) {
        require(block.timestamp >= lock[msg.sender], "MetaBetting: Locked");
        require(
            _futureTime - block.timestamp >= 1 minutes,
            "MetaBetting: Invalid FutureT Time"
        );
        require(_betPrice > 1, "Amount must > 1");
        if (token != address(0)) {
            IERC20(token).transferFrom(
                msg.sender,
                address(this),
                _poolAmount * _rate1
            );
        } else {
            require(msg.value >= _poolAmount * _rate1, "Transfer MTD Required");
        }
        idRoom = keccak256(
            abi.encodePacked(
                _rate1,
                _rate2,
                _poolAmount,
                _betPrice,
                _longShortCheck,
                _futureTime,
                token,
                _link,
                block.timestamp
            )
        );
        BettingRequest storage bet = mBetting[idRoom];
        {
            bet.id = idRoom;
            bet.players.owner = msg.sender;
            bet.info.moneyBet = _poolAmount;
            bet.info.BtcPrice = _betPrice;
            bet.rate.rate1 = _rate1;
            bet.rate.rate2 = _rate2;
            bet.time.lockTime = block.timestamp + lockTime;
            bet.time.futureTime = _futureTime;
            bet.ownerBet = _longShortCheck;
            bet.info.payment = token;
            bet.status = BettingRequestStatus.Open;
            bet.roomPrivacy = _roomPrivacy;
            bet.info.link = _link;
            bet.pool += _poolAmount * _rate1;
        }
        AddRoom(idRoom);
        emit CreateBet(msg.sender, idRoom);
        return idRoom;
    }

    event RaisedPoolForIncreasingTime(address addressRaise, uint minute);

    function IncreasingTime(bytes32 _idRoom, uint minute) external payable {
        BettingRequest storage bet = mBetting[_idRoom];
        {
            require(
                bet.players.owner != address(0) &&
                    bet.players.participant != address(0),
                "Not enough participant"
            );
            require(bet.status == BettingRequestStatus.Open, "Closed");
            require(
                msg.sender == bet.players.owner ||
                    msg.sender == bet.players.participant,
                "You are not the participant"
            );
            require(
                block.timestamp <= bet.time.futureTime,
                "Out of time for raise Bet"
            );
        }
        if (bet.info.payment != address(0)) {
            IERC20(bet.info.payment).transferFrom(
                msg.sender,
                address(this),
                bet.pool * minute
            );
        } else {
            require(msg.value >= bet.pool * minute, "Transfer MTD Required");
        }
        {
            bet.time.futureTime += minute * 60;
            bet.pool += bet.pool * minute;
        }
        emit RaisedPoolForIncreasingTime(msg.sender, minute);
    }

    event Joined(address Joiner, bytes32 IdRoom);

    function JoinBetBTC(bytes32 _idRoom) external payable {
        BettingRequest storage bet = mBetting[_idRoom];
        {
            require(bet.status == BettingRequestStatus.Open, "Closed");
            require(block.timestamp <= bet.time.lockTime, "Bet TimeOut");
            require(bet.players.owner != address(0), "Not Create Yet");
            require(msg.sender != bet.players.owner, "You're the owner");
            require(bet.players.participant == (address(0)), "Fulfilled");
        }
        bet.players.participant = msg.sender;
        if (bet.info.payment != address(0)) {
            IERC20(bet.info.payment).transferFrom(
                msg.sender,
                address(this),
                bet.info.moneyBet * bet.rate.rate2
            );
        } else {
            require(
                msg.value >= bet.info.moneyBet * bet.rate.rate2,
                "Transfer MTD Required"
            );
        }
        {
            bet.pool += bet.info.moneyBet * bet.rate.rate2;
            bet.status = BettingRequestStatus.Live;
        }
        {
            AddLive(_idRoom, bet.players.participant);
            AddLive(_idRoom, bet.players.owner);
            sortForActiveRoom();
            sortForLive(bet.players.participant);
            sortForLive(bet.players.owner);
        }
        emit Joined(msg.sender, _idRoom);
    }

    function setPrice(uint number, bytes32 _idroom) external {
        BettingRequest storage bet = mBetting[_idroom];
        bet.info.actualPrice = number;
    }

    event Winner(address _address);

    function CheckResult(bytes32 _idroom) external returns (address) {
        BettingRequest storage bet = mBetting[_idroom];
        require(
            msg.sender == bet.players.owner ||
                msg.sender == bet.players.participant,
            "You are not the participant"
        );
        require(block.timestamp >= bet.time.futureTime, "Its not time yet!!");
        require(bet.status == BettingRequestStatus.Live, "Invalid status");
        bet.info.actualPrice = getBtcPriceV2(bet.info.link);
        if (bet.info.actualPrice > bet.info.BtcPrice) {
            if (bet.ownerBet == true) {
                if (bet.info.payment != address(0)) {
                    IERC20(bet.info.payment).transfer(
                        bet.players.owner,
                        bet.pool
                    );
                } else {
                    require(
                        bet.pool <= address(this).balance,
                        "Invalid amount"
                    );
                    payable(bet.players.owner).transfer(bet.pool);
                }
                bet.status = BettingRequestStatus.OwnerWin;
                emit Winner(bet.players.owner);
                HandlerOverbet(
                    bet.players.owner,
                    bet.players.participant,
                    _idroom
                );
                return bet.players.owner;
            } else {
                if (bet.info.payment != address(0)) {
                    IERC20(bet.info.payment).transfer(
                        bet.players.participant,
                        bet.pool
                    );
                } else {
                    require(
                        bet.pool <= address(this).balance,
                        "Invalid amount"
                    );
                    payable(bet.players.participant).transfer(bet.pool);
                }
                bet.status = BettingRequestStatus.PlayerWin;
                emit Winner(bet.players.participant);
                HandlerOverbet(
                    bet.players.owner,
                    bet.players.participant,
                    _idroom
                );
                return bet.players.participant;
            }
        } else {
            if (bet.ownerBet == false) {
                if (bet.info.payment != address(0)) {
                    IERC20(bet.info.payment).transfer(
                        bet.players.owner,
                        bet.pool
                    );
                } else {
                    require(
                        bet.pool <= address(this).balance,
                        "Invalid amount"
                    );
                    payable(bet.players.owner).transfer(bet.pool);
                }
                bet.status = BettingRequestStatus.OwnerWin;
                emit Winner(bet.players.owner);
                HandlerOverbet(
                    bet.players.owner,
                    bet.players.participant,
                    _idroom
                );
                return bet.players.owner;
            } else {
                if (bet.info.payment != address(0)) {
                    IERC20(bet.info.payment).transfer(
                        bet.players.participant,
                        bet.pool
                    );
                } else {
                    require(
                        bet.pool <= address(this).balance,
                        "Invalid amount"
                    );
                    (bool sent, ) = payable(bet.players.participant).call{
                        value: bet.pool
                    }("");
                    require(sent, "Failed to send Ether");
                }
                bet.status = BettingRequestStatus.PlayerWin;
                emit Winner(bet.players.participant);
                HandlerOverbet(
                    bet.players.owner,
                    bet.players.participant,
                    _idroom
                );
                return bet.players.participant;
            }
        }
    }

    function HandlerOverbet(
        address _owner,
        address _player,
        bytes32 _idRoom
    ) private {
        sortForLive(_owner);
        sortForLive(_player);
        AddHistory(_idRoom, _owner);
        AddHistory(_idRoom, _player);
    }

    function AddRoom(bytes32 _betRoom) private {
        BettingRequest memory bet = mBetting[_betRoom];
        require(bet.players.owner != address(0), "Cannot Add Room");
        if (bet.roomPrivacy == true) {
            sortForActiveRoom();
            return;
        }
        totalRoom++;
        totalActiveRoom.push(_betRoom);
        sortForActiveRoom();
    }

    function sortForActiveRoom() public {
        for (uint i = 0; i < totalActiveRoom.length; i++) {
            BettingRequest memory bet = mBetting[totalActiveRoom[i]];
            if (
                bet.status != BettingRequestStatus.Open ||
                (block.timestamp > bet.time.lockTime &&
                    bet.players.participant == address(0))
            ) {
                adjustActive(totalActiveRoom[i]);
            }
        }
    }

    function adjustActive(bytes32 _idRoom) private {
        for (uint256 i = 0; i < totalActiveRoom.length; i++) {
            if (totalActiveRoom[i] == _idRoom) {
                totalActiveRoom[i] = totalActiveRoom[
                    totalActiveRoom.length - 1
                ];
                totalActiveRoom.pop();
                totalRoom--;
            }
        }
    }

    function AddLive(bytes32 _betRoom, address _user) private {
        BettingRequest memory bet = mBetting[_betRoom];
        require(
            bet.players.owner == _user || bet.players.participant == _user,
            "Cannot Add Live"
        );
        mTotalUserLive[_user]++;
        userLive[_user].push(_betRoom);
        sortForLive(_user);
    }

    function AddHistory(bytes32 _betRoom, address _user) private {
        BettingRequest memory bet = mBetting[_betRoom];
        require(
            bet.players.owner == _user || bet.players.participant == _user,
            "Cannot Add History"
        );
        mTotalUserHistory[_user]++;
        userHistory[_user].push(_betRoom);
        sortForHistory(_user);
    }

    function sortForHistory(address _user) public {
        if (userHistory[_user].length > 10) {
            adjustHash(0, _user);
            mTotalUserHistory[_user]--;
        }
    }

    function adjustHash(uint256 index, address _user) private {
        require(index < userHistory[_user].length, "Invalid index");
        for (uint256 i = index; i < userHistory[_user].length - 1; i++) {
            userHistory[_user][i] = userHistory[_user][i + 1];
        }
        userHistory[_user].pop();
    }

    function sortForLive(address _user) public {
        for (uint256 i = 0; i < userLive[_user].length; i++) {
            BettingRequest memory bet = mBetting[userLive[_user][i]];
            if (
                bet.status != BettingRequestStatus.Live ||
                (bet.players.owner != _user && bet.players.participant != _user)
            ) {
                userLive[_user][i] = userLive[_user][
                    userLive[_user].length - 1
                ];
                userLive[_user].pop();
                mTotalUserLive[_user]--;
            }
        }
    }

    // Get Function
    function GetActiveRoom(
        uint8 _page
    )
        external
        view
        returns (bool isMore, BettingRequestCopy[] memory arrayBet)
    {
        if (_page * returnRIP > totalActiveRoom.length + returnRIP) {
            return (false, arrayBet);
        } else {
            if (_page * returnRIP <= totalActiveRoom.length) {
                isMore = true;
                arrayBet = new BettingRequestCopy[](returnRIP);
                for (uint i = 0; i < arrayBet.length; i++) {
                    // arrayBet[i] = mBetting[totalActiveRoom[_page*returnRIP - returnRIP +i]];
                    arrayBet[i] = convert(
                        totalActiveRoom[_page * returnRIP - returnRIP + i]
                    );
                }
                return (isMore, arrayBet);
            } else {
                isMore = false;
                arrayBet = new BettingRequestCopy[](
                    returnRIP - (_page * returnRIP - totalActiveRoom.length)
                );
                for (uint i = 0; i < arrayBet.length; i++) {
                    // arrayBet[i] = mBetting[totalActiveRoom[_page*returnRIP - returnRIP +i]];
                    arrayBet[i] = convert(
                        totalActiveRoom[_page * returnRIP - returnRIP + i]
                    );
                }
                return (isMore, arrayBet);
            }
        }
    }

    function GetLiveRoom(
        uint8 _page,
        address _user
    )
        external
        view
        returns (bool isMore, BettingRequestCopy[] memory arrayBet)
    {
        if (_page * returnRIP > userLive[_user].length + returnRIP) {
            return (false, arrayBet);
        } else {
            if (_page * returnRIP <= userLive[_user].length) {
                isMore = true;
                arrayBet = new BettingRequestCopy[](returnRIP);
                for (uint i = 0; i < arrayBet.length; i++) {
                    // arrayBet[i] = mBetting[userLive[_user][_page*returnRIP - returnRIP +i]];
                    arrayBet[i] = convert(
                        userLive[_user][_page * returnRIP - returnRIP + i]
                    );
                }
                return (isMore, arrayBet);
            } else {
                isMore = false;
                arrayBet = new BettingRequestCopy[](
                    returnRIP - (_page * returnRIP - userLive[_user].length)
                );
                for (uint i = 0; i < arrayBet.length; i++) {
                    // arrayBet[i] = mBetting[userLive[_user][_page*returnRIP - returnRIP +i]];
                    arrayBet[i] = convert(
                        userLive[_user][_page * returnRIP - returnRIP + i]
                    );
                }
                return (isMore, arrayBet);
            }
        }
    }

    function GetHistory(
        address _user
    ) external view returns (BettingRequestCopy[] memory arrayBet) {
        arrayBet = new BettingRequestCopy[](userHistory[_user].length);
        for (uint i = 0; i < arrayBet.length; i++) {
            arrayBet[i] = convert(userHistory[_user][i]);
        }
    }

    function getBlockTimestamp() external view returns (uint) {
        return block.timestamp;
    }

    function getBtcPriceV2(string memory link) public view returns (uint) {
        string memory rateField = "bitcoin";
        string memory usdField = "usd";
        string memory response = CallApi.CallApi(link);
        string memory jsonRatesField = ExtractJsonField.ExtractJsonField(
            response,
            rateField
        );
        string memory jsonUsdField = ExtractJsonField.ExtractJsonField(
            jsonRatesField,
            usdField
        );
        return stringToUint(jsonUsdField);
    }
}