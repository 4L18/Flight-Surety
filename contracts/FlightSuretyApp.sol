pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint constant QUORUM = 100/50;
    uint constant FIRST_LEVEL_QUORUM = 5;
    uint constant MAX_INSURANCE = 1 ether;

    address private contractOwner;
    bool private operational = true;
    FlightSuretyData flightSuretyData;

    struct Flight {
        string flight;
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    uint private flightsCount = 0;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event FlightRegistered(string flightNumber);
    event InsurancePurchased(bytes32 key);
    event CompensationtWithdrawn(bytes32 key);
    

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() 
    {
        require(true, "Contract is currently not operational");  
        _;
    }

    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }


    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    constructor(address dataContract)
    public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        operational = true;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
    public 
    view 
    returns(bool) 
    {
        return operational;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function registerAirline(address airline)
    requireIsOperational
    {
        require(flightSuretyData.isAirlineParticipant(msg.sender), "Msg.sender is not a participant");
        require(!flightSuretyData.isAirlineRegistered(airline), "Airline already registered");

        if(!flightSuretyData.isAirlineCreated(airline)) {
            flightSuretyData.createAirline(airline);
        }
        flightSuretyData.voteAirline(airline, msg.sender);           
        
        uint participants = flightSuretyData.getParticipantsCount();            
        if(participants < FIRST_LEVEL_QUORUM) {

            flightSuretyData.registerAirline(airline);

        } else {

            uint quorum = participants/QUORUM;
            if(participants%QUORUM != 0) {
                quorum.add(1);
            }
            uint votes = flightSuretyData.getAirlineVotes(airline);
            bool consensus = (votes > quorum);
            if(consensus) {
                flightSuretyData.registerAirline(airline);
            }
        }
    }

    function fundAirline()
    requireIsOperational
    payable
    {
        require(flightSuretyData.isAirlineRegistered(msg.sender), "Airline not registered");
        flightSuretyData.fund(msg.sender, msg.value);
    }

    function registerFlight(string flight, address airlineAddr, uint256 timestamp)
    external
    requireIsOperational
    {
        bytes32 flightKey = keccak256(abi.encodePacked(flight, timestamp));
        flightsCount = flightsCount.add(1);
        flights[flightKey] = Flight({
                flight: flight,
                isRegistered: true,
                statusCode: 0,
                updatedTimestamp: timestamp,
                airline: airlineAddr
            });
        emit FlightRegistered(flight);
    }
    
    function processFlightStatus(address airline, string flight, uint256 timestamp, uint8 statusCode)
    internal
    requireIsOperational
    {
        require(flightSuretyData.isAirlineParticipant(msg.sender));
        bytes32 fligthKey = generateFlightKey(flight, timestamp);
        flights[fligthKey].statusCode = statusCode;
        flights[fligthKey].updatedTimestamp = timestamp;
        emit OracleReport(airline, flight, timestamp, statusCode);
        
    }

    function fetchFlightStatus(address airline, string flight, uint256 timestamp)
    requireIsOperational
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    function buyInsurance(string flight, uint256 timestamp)
    external
    requireIsOperational
    payable
    {
        require(msg.value <= MAX_INSURANCE, "Up to 1 ether for purchasing flight insurance");
        
        bytes32 flightKey = generateFlightKey(flight, timestamp);
        require(flights[flightKey].isRegistered, "This code does not match any flight");
        
        bytes32 insuranceKey = generateInsuranceKey(msg.sender, flight, timestamp);
        require(!flightSuretyData.insuranceExists(insuranceKey), "Already bought this insurance");

        flightSuretyData.buyInsurance(msg.sender, msg.value, insuranceKey);
        emit InsurancePurchased(insuranceKey);
    }

    function withdrawCompensation(string flight, uint256 timestamp)
    external
    requireIsOperational
    {
        bytes32 insuranceKey = generateInsuranceKey(msg.sender, flight, timestamp);
        require(flightSuretyData.insuranceExists(insuranceKey), "Insurance does not exist");

        bytes32 flightKey = generateFlightKey(flight, timestamp);
        require(flights[flightKey].statusCode == 20, "Causes of the delay are not due airline's fault");
        
        uint credit = flightSuretyData.getFunds(msg.sender);
        credit = credit.mul(15);
        credit = credit.div(10);

        flightSuretyData.creditInsurees(msg.sender, credit, insuranceKey);
        emit CompensationtWithdrawn(flightKey);
    }

    function generateFlightKey(string flight, uint256 timestamp)
    requireIsOperational
    returns(bytes32)    
    {
        return keccak256(abi.encodePacked(flight, timestamp));
    }

    function generateInsuranceKey(address passenger, string flight, uint256 timestamp)
    requireIsOperational
    returns(bytes32)    
    {
        return keccak256(abi.encodePacked(passenger, flight, timestamp));
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
