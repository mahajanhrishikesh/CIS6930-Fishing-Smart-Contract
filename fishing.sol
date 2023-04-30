// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/master/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract FishTracer is ChainlinkClient, ConfirmedOwner {
    using Strings for uint256;
    using Chainlink for Chainlink.Request;

    // Data Structures
    struct FishBatch {
        uint32 id;
        string name;
        uint weight;
        uint latitude;
        uint longitude;
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

    struct TimeStamp{
        uint year;
        uint month;
        uint day;
        uint hour;
        uint minute;
        uint second; 
    }

    //Relevant Events
    event RequestInvolvement(bytes32 indexed requestId, bool iuuInvolvement);
    event RequestVesselInfo(bytes32 indexed requestId, uint mmsi);
    event RequestLocationConfirmation(bytes32 indexed requestId, bool locationCheck);
    event IncorrectLocationMarked(uint indexed mmsi, bool locationCheck, string sentLat, string sentLon, string actualLat, string actualLon);
    event Certification(uint indexed mmsi, FishBatch[] catchHistory, uint timeStamp, bool indexed sustainable);


    //State Variables
    Vessel monitoredVessel;
    uint confirmationMMSI;
    TimeStamp public start;
    TimeStamp public end;
    string public startTimeString;
    string public endTimeString;
    string public BASE_URL = "https://civic-genre-325102.ue.r.appspot.com/";
    string public generatedEncounterURL;
    bool public iuuInvolvement=true;
    bool public shipExists = false;
    bool public leftPort = true;
    FishBatch[] public catchHistory;


    bytes32 private jobId;
    bytes32 private boolJobId;
    uint256 private fee;
    constructor() ConfirmedOwner(msg.sender) payable{
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        boolJobId = "c1c5e92880894eb6b27d3cae19670aa3";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    // Data Entry Points for Ship Operators
    function setVesselInformation(uint32 ID, string memory v_type, string memory name, string memory country, string memory flag, uint MMSI) public {
        //require(address(this).balance >= 0.0000005 ether, "Send the contract atleast 0.5 ether to start the process.");
        monitoredVessel = Vessel(ID, v_type, name, country, flag, MMSI);
    }

    function registerBatch(uint32 id, string memory name, uint weight, uint latitude, uint longitude) public {
        catchHistory.push(FishBatch(id, name, weight, latitude, longitude));
        requestLocationConfirmation(latitude, longitude);
    }

    // Timestamp Generation Functions
    function setStart () public {
        (uint ty, uint tm, uint td, uint th, uint tmi, uint ts) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(block.timestamp);
        start = TimeStamp(ty, tm, td, th, tmi, ts);
        startTimeString = formatTimeStamp(start);
    }

    function setEnd () public {
        (uint ty, uint tm, uint td, uint th, uint tmi, uint ts) = BokkyPooBahsDateTimeLibrary.timestampToDateTime(block.timestamp);
        end = TimeStamp(ty, tm, td, th, tmi, ts);
        endTimeString = formatTimeStamp(end);
        generatedEncounterURL = string(abi.encodePacked(
                BASE_URL, "encounter/",
                monitoredVessel.MMSI.toString(), "/",
                startTimeString, "/",
                endTimeString
            ));
    }

    // Formatting and helper functions
    function formatTimeStamp(TimeStamp memory ts) public pure returns (string memory) {
        return string(abi.encodePacked(
            padLeft(ts.month.toString(), 2, "0"), "-",
            padLeft(ts.day.toString(), 2, "0"), "-",
            padLeft((ts.year % 100).toString(), 2, "0"), " ",
            padLeft(ts.hour.toString(), 2, "0"), ":",
            padLeft(ts.minute.toString(), 2, "0"), ":",
            padLeft(ts.second.toString(), 2, "0")
        ));
    }
    
    function padLeft(string memory str, uint len, string memory chr) internal pure returns (string memory) {
        if (bytes(str).length >= len) return str;
        string memory padding = "";
        for (uint i = bytes(str).length; i < len; i++) {
            padding = string(abi.encodePacked(padding, chr));
        }
        return string(abi.encodePacked(padding, str));
    }

    /**************CHAINLINK SECTION START****************/

    /**********************FIRST REQUEST START************/
    function requestVolumeData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        req.add(
            "get",
            string.concat(
                string.concat(BASE_URL, "data/"), 
                Strings.toString(monitoredVessel.MMSI)
            )
        );

        req.add("path", "mmsi");

        int256 timesAmount = 1;
        req.addInt("times", timesAmount);

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    function fulfill(
        bytes32 _requestId,
        uint256 _mmsi
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestVesselInfo(_requestId, _mmsi);
        confirmationMMSI = _mmsi;
        if(confirmationMMSI == monitoredVessel.MMSI)
        {
            shipExists = true;
        }
    }
    /**********************FIRST REQUEST END************/

    /**********************SECOND REQUEST START************/
    function requestLocationConfirmation(uint lat, uint lon) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            boolJobId,
            address(this),
            this.fulfillLC.selector
        );

        string memory generatedLocationURL = string(abi.encodePacked(
                BASE_URL, "location/",
                monitoredVessel.MMSI.toString(), "/",
                lat.toString(), "/",
                lon.toString()
            ));

        req.add(
            "get",
            generatedLocationURL
        );

        req.add("path", "iuuInvolved");
        return sendChainlinkRequest(req, fee);
    }

    function fulfillLC(
        bytes32 _requestId,
        bool _nearby
    ) public recordChainlinkFulfillment(_requestId) {
        if(_nearby == true)
        {
            emit RequestLocationConfirmation(_requestId, _nearby);
        }
    }
    /**********************SECOND REQUEST END************/

    /**********************THIRD REQUEST START*******************/
    function requestInvolvementData() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            boolJobId,
            address(this),
            this.fulfillIVR.selector
        );

        req.add(
            "get",
            generatedEncounterURL
        );

        req.add("path", "iuuInvolved");
        return sendChainlinkRequest(req, fee);
    }

    function fulfillIVR(
        bytes32 _requestId,
        bool _iuuInvolvement
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestInvolvement(_requestId, _iuuInvolvement);
        iuuInvolvement = _iuuInvolvement;
    }
    /**********************THIRD REQUEST END*******************/

    /**************CHAINLINK SECTION END****************/

    function enterPort() public {
        require(shipExists, "Ship details are invalid.");
        require(leftPort, "Leave the port first.");
        setEnd();
        requestInvolvementData();
    }

    function leavePort() private {
        require(shipExists, "Ship details are invalid.");
        leftPort = true;
        setStart();
    }

    function approveSustainability() public {
        require(shipExists, "Ship details are invalid.");
        require(leftPort, "Leave the port first.");
        if((shipExists == true) && (iuuInvolvement == false))
        {
            emit Certification(monitoredVessel.MMSI, catchHistory, block.timestamp, true);
        }
        else
        {
            emit Certification(monitoredVessel.MMSI, catchHistory, block.timestamp, false);
        }
    } 
}
