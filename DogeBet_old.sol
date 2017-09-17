pragma solidity ^0.4.8;

import "./oraclizeAPI_0.4.sol";
import "./strings.sol";

contract DogeBet {

    address public owner;

    mapping (uint => address) public bets;

    // New Bet Created
    event NewBet(uint matchID, address betAddress);

    function DogeBet() {
        owner = msg.sender;
    }

    /** Create a new bet

        @return the address of the betting contract
       */
    function createBet(uint _match) {

        if(bets[_match] != 0){
            throw;
        }

        // matchID, Id of team
        address newBet = new WinLoseTieBet(_match);
        // save contractaddress in mapping with ID
        bets[_match] = newBet;
    }

    function kill(){
        if (msg.sender == owner) suicide(msg.sender);
    }

}


contract WinLoseTieBet is usingOraclize {
    using strings for *;

    address public creator;
    // ufixed public houseEdge = 0.02; // 2 percent to the house

    uint public matchID;
    string strMatchID;

    bytes32 timeQueryID;
    bytes32 finishedQueryID;
    bytes32 winningQueryID;
    bytes32 scoreTeam1QueryID;
    bytes32 scoreTeam2QueryID;

    // 0 is Tie, 1 is Team 1 wins and 2 is Team 2 wins
    mapping (uint => mapping (address => uint)) bids;
    mapping (bytes32 => bool) validIds;
    address[] betters;

    string public api;
    uint public startTime;
    string public matchTime;
    uint public counter;
    uint winner;
    bool initialized;
    string api1;
    string api2;

    string public scoreTeam1;
    string public scoreTeam2;
    bool finalScore1;
    bool finalScore2;
    string public finished;

    uint public totalBalance1   = 0; // balance of all bets on "win" teamA
    uint public totalBalance2   = 0; // balance of all bets on "win" teamB
    uint public totalBalanceTie = 0; // balance of all bets on ""

    function WinLoseTieBet(uint _matchID) payable {
        // shit doesnt work this way (?) but anyway just testnet yo
        creator = msg.sender;
        OAR = OraclizeAddrResolverI(0x51efaf4c8b3c9afbd5ab9f4bbc82784ab6ef8faa);

        api1 = "json(http://carlfriess.com:3000/api/getmatchdata/";
        matchID = _matchID;
        strMatchID = uint2str(_matchID);
        api = strConcat(api1, strMatchID);

        initialized = false;
    }

    // pay Ether + Fees
    function bid(uint _id) payable{

        // Revert the call if the bidding
        // period is over.

        if (!initialized){
            // Time UTC <MatchDateTimeUTC>2016-11-19T17:30:00Z</MatchDateTimeUTC>
            var str = strConcat(api, ").MatchDateTimeUTC");
            timeQueryID = oraclize_query("URL", str);
            validIds[timeQueryID] = true;

            // Finished?
            finished = "false";
            str = strConcat(api, ").MatchIsFinished");
            finishedQueryID = oraclize_query("URL", str);
            validIds[finishedQueryID] = true;
            initialized = true;
        }else{
            require(now <= startTime);
        }

        // Sanity Check
        if(_id < 0 && 2 < _id && msg.value <= 0.0){
            throw;
        }

        bids[_id][msg.sender] += msg.value;
        betters.push(msg.sender);

        // Bets on tie
        if (_id == 0){
            totalBalanceTie += msg.value;

        // Bets on Team 1
        }else if(_id == 1){
            totalBalance1 += msg.value;

        // Bets on Team 2
        }else{
            totalBalance2 += msg.value;

        }

    }

    function payoff() internal{
        uint totalPayoff;
        uint payoutBalance;
        uint collectedFees;

        address better;
        uint amount;
        uint winAmount;
        uint idx;

        if (winner == 0) {

            totalPayoff = totalBalance1 + totalBalance2;
            payoutBalance = totalPayoff; // * (1 - houseEdge);
            collectedFees = totalPayoff; // * houseEdge;

            for (idx = 0; idx < betters.length; idx += 1) {

                better = betters[idx];
                amount = bids[0][better];
                // what he gave + the his
                winAmount = amount + ((amount / totalBalanceTie) * totalPayoff);
                better.transfer(winAmount);
            }

        } else if (winner == 1){

            totalPayoff = totalBalanceTie + totalBalance2;
            payoutBalance = totalPayoff; // * (1 - houseEdge);
            collectedFees = totalPayoff; // * houseEdge;

            for (idx = 0; idx < betters.length; idx += 1) {

                better = betters[idx];
                amount = bids[1][better];
                // what he gave + the his
                winAmount = amount + ((amount / totalBalance1) * totalPayoff);
                better.transfer(winAmount);
            }

        } else if (winner == 2) {

            totalPayoff = totalBalanceTie + totalBalance2;
            payoutBalance = totalPayoff; // * (1 - houseEdge);
            collectedFees = totalPayoff; // * houseEdge;

            for (idx = 0; idx < betters.length; idx += 1) {

                better = betters[idx];
                amount = bids[1][better];
                // what he gave + the his
                winAmount = amount + ((amount / totalBalance1) * totalPayoff);
                better.transfer(winAmount);
            }

        }

    }


    function __callback(bytes32 id, string result) {
        if (!validIds[id]) throw;
        if (msg.sender != oraclize_cbAddress()) throw;

        if (id == timeQueryID){
            matchTime = result;
            startTime = parseTime(result);
        } else if (id == finishedQueryID){
            finished = result;
            if(sha3(finished) == sha3("false")){
                update();
            }
        } else if (id == scoreTeam1QueryID){
            scoreTeam1 = result;
            finalScore1 = true;
        } else if (id == scoreTeam2QueryID){
            scoreTeam2 = result;
            finalScore1 = true;
        }

        // Game is finished
        if (sha3(finished) == sha3("true") && !finalScore1 && !finalScore2) {

            // PointsTeam1
            var str = strConcat(api, ").MatchResults.1.PointsTeam1");
            scoreTeam1QueryID = oraclize_query("URL", str);
            validIds[scoreTeam1QueryID] = true;
            // PointsTeam2
            str = strConcat(api, ").MatchResults.1.PointsTeam2");
            scoreTeam2QueryID = oraclize_query("URL", str);
            validIds[scoreTeam2QueryID] = true;

        }else if(sha3(finished) == sha3("true") && finalScore1 && finalScore2){
            // Tie
            if (sha3(scoreTeam1) == sha3(scoreTeam2)){
                winner = 0;
            // Team 1 won
            }else if (sha3(scoreTeam1) > sha3(scoreTeam2)){
                winner = 1;
            // Team 2 won
            }else {
                winner = 2;
            }
            // payoff();
        }
        
        delete validIds[id];
    }

    function update() payable{
        counter += 1;
        // Finished?
        var str = strConcat(api, ").MatchIsFinished");
        finishedQueryID = oraclize_query(120, "URL", str);
        validIds[finishedQueryID] = true;
    }


    // ------------- Timestamp Stuff -------------

    function parseTime(string _time) internal returns (uint){

        // uses https://github.com/Arachnid/solidity-stringutils
        var slicedTime = _time.toSlice();

        // slicedTime: 2016-11-19T17:30:00Z
        uint yy = parseInt((slicedTime.split("-".toSlice())).toString());
        // year: 2016, slicedTime: 11-19T17:30:00Z
        uint mm = parseInt((slicedTime.split("-".toSlice())).toString());
        // month: 11, slicedTime: 19T17:30:00Z
        uint dd = parseInt((slicedTime.split("T".toSlice())).toString());
        // day: 19, slicedTime: 17:30:00Z
        uint hh = parseInt((slicedTime.split(":".toSlice())).toString());
        // hour: 17, slicedTime: 30:00Z
        uint min = parseInt((slicedTime.split(":".toSlice())).toString());
        // minutes: 30, slicedTime: 00Z
        uint sec = parseInt((slicedTime.split("Z".toSlice())).toString());
        // seconds: 00, slicedTime: ""

        // convert everything to unix epoch aka "seconds since Jan 01 1970"
        // using https://github.com/pipermerriam/ethereum-datetime
        uint epoch = toTimestamp(yy, mm, dd, hh, min, sec);
        return epoch;
    }

    uint constant ORIGIN_YEAR = 1970;
    uint constant DAY_IN_SECONDS = 86400;
    uint constant YEAR_IN_SECONDS = 31536000;
    uint constant LEAP_YEAR_IN_SECONDS = 31622400;

    uint constant HOUR_IN_SECONDS = 3600;
    uint constant MINUTE_IN_SECONDS = 60;

    function isLeapYear(uint year) internal constant returns (bool) {
                if (year % 4 != 0) {
                        return false;
                }
                if (year % 100 != 0) {
                        return true;
                }
                if (year % 400 != 0) {
                        return false;
                }
                return true;
    }


    function toTimestamp(uint year, uint month, uint day, uint hour, uint minute, uint second) internal constant returns (uint timestamp) {
        uint i;

        // Year
        for (i = ORIGIN_YEAR; i < year; i++) {
                if (isLeapYear(i)) {
                        timestamp += LEAP_YEAR_IN_SECONDS;
                }
                else {
                        timestamp += YEAR_IN_SECONDS;
                }
        }

        // Month
        uint[12] memory monthDayCounts;
        monthDayCounts[0] = 31;
        if (isLeapYear(year)) {
                monthDayCounts[1] = 29;
        }
        else {
                monthDayCounts[1] = 28;
        }
        monthDayCounts[2] = 31;
        monthDayCounts[3] = 30;
        monthDayCounts[4] = 31;
        monthDayCounts[5] = 30;
        monthDayCounts[6] = 31;
        monthDayCounts[7] = 31;
        monthDayCounts[8] = 30;
        monthDayCounts[9] = 31;
        monthDayCounts[10] = 30;
        monthDayCounts[11] = 31;

        for (i = 1; i < month; i++) {
                timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
        }

        // Day
        timestamp += DAY_IN_SECONDS * (day - 1);

        // Hour
        timestamp += HOUR_IN_SECONDS * (hour);

        // Minute
        timestamp += MINUTE_IN_SECONDS * (minute);

        // Second
        timestamp += second;

        return timestamp;
    }

}
