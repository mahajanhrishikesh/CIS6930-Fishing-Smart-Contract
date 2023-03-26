// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FishTraceability is ChainlinkClient, ConfirmedOwner {

    using Chainlink for Chainlink.Request;

    // Data from internet variables
    bool public iuuInvolvement = false;
    uint public trueVesselMMSI;
    bool public locationCheck = true;

    // For sanity checks and auditing purposes
    event RequestInvolvement(bytes32 indexed requestId, bool iuuInvolvement);
    event RequestVesselInfo(bytes32 indexed requestId, uint mmsi);
    event RequestLocationConfirmation(bytes32 indexed requestId, bool locationCheck);
    event IncorrectLocationMarked(uint indexed mmsi, bool locationCheck, string sentLat, string sentLon, string actualLat, string actualLon);

    // Data Structures
    struct FishBatch {
        uint32 id;
        string name;
        uint weight;
        string latitude;
        string longitude;
    }

    struct Vessel {
        uint32 ID;
        string v_type;
        string name;
        string country;
        string flag;
        uint MMSI;
    }

    struct Port {
        uint32 ID;
        string country;
        string name;
        uint32 latitude;
        uint32 longitude;
    }

    // State Variables
    Vessel public monitoredVessel;
    FishBatch[] public catchHistory;
    string public departureTime;
    string public arrivalTime;
    bytes32 private jobId;
    uint256 private fee;
    uint public balance=1000;
    address public penaltyAddress;
    string public BASE_URL = "https://civic-genre-325102.ue.r.appspot.com/";

    // Control Variables
    bool private shipExists;
    bool private leftPort;
    

    constructor(address _penaltyAddress) ConfirmedOwner(msg.sender) payable {
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10;
        penaltyAddress = _penaltyAddress;
    }

    function setVesselInformation(uint32 ID, string memory v_type, string memory name, string memory country, string memory flag, uint MMSI) public {
        require(address(this).balance >= 0.5 ether, "Send the contract atleast 0.5 ether to start the process.");
        monitoredVessel = Vessel(ID, v_type, name, country, flag, MMSI);
    }

    function registerBatch(uint32 id, string memory name, uint weight, string memory latitude, string memory longitude) public {
        catchHistory.push(FishBatch(id, name, weight, latitude, longitude));
        requestLocationConfirmation(latitude, longitude);
    }


    /********** INTERNET CHAIN LINK START **********/

    // FIRST INTERNET REQUEST TO CHAINLINK
    function requestVesselData() public returns (bytes32 requestId){
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillVD.selector
        );

        req.add(
            "get",
            string.concat(
                string.concat(BASE_URL, "data/"), 
                Strings.toString(monitoredVessel.MMSI)
            )
        );

        req.add("path", "mmsi");

        return sendChainlinkRequest(req, fee);
    }

    function fulfillVD(
        bytes32 _requestId,
        uint _mmsi
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestVesselInfo(_requestId, _mmsi);
        trueVesselMMSI = _mmsi;
        if(trueVesselMMSI == monitoredVessel.MMSI) {
            shipExists = true;
            leavePort();
        }
        else
        {
            payable(penaltyAddress).transfer(balance);
            balance -= balance;
        }
    }

    // SECOND INTERNET REQUEST TO CHAINLINK
    function requestLocationConfirmation(string memory lat, string memory lon) public returns (bytes32 requestId){
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillLC.selector
        );
        string memory reqData = string.concat(lat, string.concat("/", lon));
        req.add(
            "get",
            string.concat(
                string.concat(BASE_URL, "location/"), 
                reqData
            )
        );

        req.add("path", "sentLat");
        req.add("path", "sentLon");
        req.add("path", "actualLat");
        req.add("path", "actualLon");
        req.add("path", "nearby");

        return sendChainlinkRequest(req, fee);
    }

    function fulfillLC(
        bytes32 _requestId,
        string memory _sentLat,
        string memory _sentLon,
        string memory _actualLat,
        string memory _actualLon,
        bool _nearby
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestLocationConfirmation(_requestId, _nearby);
        locationCheck = _nearby;
        if(locationCheck == false)
        {
            emit IncorrectLocationMarked(monitoredVessel.MMSI, locationCheck, _sentLat, _sentLon, _actualLat, _actualLon);
        }
    }

    // THIRD INTERNET REQUEST TO CHAINLINK
    function requestInvolvementData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillIVR.selector
        );

        req.add(
            "get",
            string.concat(
                string.concat(BASE_URL, "encounter/"), 
                Strings.toString(monitoredVessel.MMSI)
            )
        );

        req.add("path", "involved");

        return sendChainlinkRequest(req, fee);
    }

    function fulfillIVR(
        bytes32 _requestId,
        bool _iuuInvolvement
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestInvolvement(_requestId, _iuuInvolvement);
        iuuInvolvement = _iuuInvolvement;
    }

    /********** INTERNET CHAIN LINK END **********/


    function enterPort() public {
        require(shipExists, "Ship details are invalid.");
        require(leftPort, "Leave the port first.");
        requestInvolvementData();
    }

    function leavePort() private {
        require(shipExists, "Ship details are invalid.");
        leftPort = true;
    }

    function approveSustainability() public returns (bool){
        require(shipExists, "Ship details are invalid.");
        require(leftPort, "Leave the port first.");
        if((shipExists == true) && (iuuInvolvement == false))
        {
            return true;
        }
        else
        {
            return false;
        }
    } 
}
