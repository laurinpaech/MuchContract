pragma solidity ^0.4.8;

import "./oraclizeAPI_0.4.sol";
import "./strings.sol";
import "./DateTime.sol";

contract DogeBet {

    address public owner;

    mapping (uint256 => address) public bets;

    // New Bet Created
    event NewBet(uint matchID, address betAddress);

    function DogeBet() {
        owner = msg.sender;
    }

    /** Create a new bet

        @return the address of the betting contract
       */
    function createBet() returns (address) {

        if(bets[msg.value] != 0){
            throw;
        }
        // return is contractaddress?
        address newBet = new WinLoseTieBet(msg.value); // matchID, Id of team
        // save contractaddress in mapping with ID
        bets[msg.value] = newBet;
        NewBet(msg.value, newBet);
    }

    function kill(){
        if (msg.sender == owner) suicide(msg.sender);
    }

}


contract WinLoseTieBet is usingOraclize {
    using strings for *;

    address public creator;
    uint public houseEdge = 0.02; // 2 percent to the house
    uint public matchID;

    bytes32 timeQueryID;
    bytes32 finishedQueryID;
    bytes32 winningQueryID;
    bytes32 scoreTeam1QueryID;
    bytes32 scoreTeam2QueryID;

    // 0 is Tie, 1 is Team 1 wins and 2 is Team 2 wins
    mapping (uint => mapping (address => uint)) bids;
    address[] betters;

    uint startTime;
    uint winner;

    string scoreTeam1;
    string scoreTeam2;
    bool finalScore1;
    bool finalScore2;
    string finished;

    uint public totalBalance1   = 0; // balance of all bets on "win" teamA
    uint public totalBalance2   = 0; // balance of all bets on "win" teamB
    uint public totalBalanceTie = 0; // balance of all bets on ""

    function WinLoseTieBet(uint _matchID) {
        // shit doesnt work this way (?) but anyway just testnet yo
        creator = msg.sender;
        OAR = OraclizeAddrResolverI(0x51efaf4c8b3c9afbd5ab9f4bbc82784ab6ef8faa);
        // api_address = _api_address;

        matchID = _matchID;
        // does first bet work?

        initialize();
    }

    // check internal keyword
    function initialize() internal {
        // Time UTC <MatchDateTimeUTC>2016-11-19T17:30:00Z</MatchDateTimeUTC>
        timeQueryID    = oraclize_query("URL", "json(https://www.openligadb.de/api/getmatchdata/39738).Match.MatchDateTimeUTC");
        // Finished?
        // finishedQueryID = oraclize_query("URL", "json(https://www.openligadb.de/api/getmatchdata/39738).Match.MatchIsFinished");
    }

    function parseTime(string time) returns (uint){

        // uses https://github.com/Arachnid/solidity-stringutils
        var slicedTime = time.toSlice();
        /*
        // slicedTime: 2016-11-19T17:30:00Z
        uint16 years = parseInt((slicedTime.split("-".toSlice())).toString());
        // year: 2016, slicedTime: 11-19T17:30:00Z
        uint8 months = parseInt((slicedTime.split("-".toSlice())).toString());
        // month: 11, slicedTime: 19T17:30:00Z
        uint8 days = parseInt((slicedTime.split("T".toSlice())).toString());
        // day: 19, slicedTime: 17:30:00Z
        uint8 hours = parseInt((slicedTime.split(":".toSlice())).toString());
        // hour: 17, slicedTime: 30:00Z
        uint8 minutes = parseInt((slicedTime.split(":".toSlice())).toString());
        // minutes: 30, slicedTime: 00Z
        uint8 seconds = parseInt((slicedTime.split("Z".toSlice())).toString());
        // seconds: 00, slicedTime: ""

        // convert everything to unix epoch aka "seconds since Jan 01 1970"
        // using https://github.com/pipermerriam/ethereum-datetime
        return toTimestamp(years, months, days, hours, minutes, seconds);
        */
    }

    // pay Ether + Fees
    function bid(uint _id) payable{

        // Revert the call if the bidding
        // period is over.
        require(now <= startTime);

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
            payoutBalance = totalPayoff * (1 - houseEdge);
            collectedFees = totalPayoff * houseEdge;

            for (idx = 0; idx < betters.length; idx += 1) {

                better = betters[idx];
                amount = bids[0][better];
                // what he gave + the his
                winAmount = amount + ((amount / totalBalanceTie) * totalPayoff);
                better.send(winAmount);
            }

        } else if (winner == 1){

            totalPayoff = totalBalanceTie + totalBalance2;
            payoutBalance = totalPayoff * (1 - houseEdge);
            collectedFees = totalPayoff * houseEdge;

            for (idx = 0; idx < betters.length; idx += 1) {

                better = betters[idx];
                amount = bids[1][better];
                // what he gave + the his
                winAmount = amount + ((amount / totalBalance1) * totalPayoff);
                better.send(winAmount);
            }

        } else if (winner == 2) {

            totalPayoff = totalBalanceTie + totalBalance2;
            payoutBalance = totalPayoff * (1 - houseEdge);
            collectedFees = totalPayoff * houseEdge;

            for (idx = 0; idx < betters.length; idx += 1) {

                better = betters[idx];
                amount = bids[1][better];
                // what he gave + the his
                winAmount = amount + ((amount / totalBalance1) * totalPayoff);
                better.send(winAmount);
            }

        }

    }


    function __callback(bytes32 id, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;

        if (id == timeQueryID){
            startTime = parseTime(result);
        } else if (id == finishedQueryID){
            finished = result;
        } else if (id == scoreTeam1QueryID){
            scoreTeam1 = result;
            finalScore1 = true;
        } else if (id == scoreTeam2QueryID){
            scoreTeam2 = result;
            finalScore1 = true;
        }

        // Game is finished
        if (finished == "true" && !finalScore1 && !finalScore2) {

            // PointsTeam1
            scoreTeam1QueryID = oraclize_query("URL", "json(https://www.openligadb.de/api/getmatchdata/39738).Match.MatchResults.1.PointsTeam1");
            // PointsTeam2
            scoreTeam2QueryID = oraclize_query("URL", "json(https://www.openligadb.de/api/getmatchdata/39738).Match.MatchResults.1.PointsTeam2");

        }else if(finished == "true" && finalScore1 && finalScore2){
            // Tie
            if (scoreTeam1 == scoreTeam2){
                winner = 0;
            // Team 1 won
            }else if (scoreTeam1 > scoreTeam2){
                winner = 1;
            // Team 2 won
            }else {
                winner = 2;
            }
        }else{
            update();
        }

    }

    function update() payable internal{

        // Finished?
        finishedQueryID = oraclize_query(900, "URL", "json(https://www.openligadb.de/api/getmatchdata/39738).Match.MatchIsFinished");
    }
}
