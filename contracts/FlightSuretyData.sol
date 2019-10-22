pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    bool private operational = true;
    mapping(address => bool) private authorizedCallers;
    mapping(address => uint) private fundsLedger;
    uint private raisedFunds= 0;

    struct Airline {
        uint id;
        bool registered;
        mapping(address => bool) votedBy;
        uint votes;
    }
    mapping(address => Airline) private airlines;
    uint private airlinesCount = 0;

    mapping(bytes32 => bool) private insurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event OperationalStatus(bool mode);
    event Authorized(address addr);
    event Unauthorized(address caller);
    event AirlineHasBeenCreated(address airline);
    event AirlineHasBeenVoted(address airline);
    event AirlineHasBeenRegistered(address airline);
    event FundsRaised(uint raisedFunds);
    event InsuranceHasBeenBought();
    event Payment();
    
    /********************************************************************************************/
    /*                                       CONSTRUCTOR & FALLBACK                             */
    /********************************************************************************************/
    
    constructor(address firstAirline) 
    public 
    {
        contractOwner = msg.sender;
        authorizedCallers[contractOwner] = true;
        
        airlinesCount = airlinesCount.add(1);
        airlines[firstAirline] = Airline({
                                    id: airlinesCount,
                                    registered: true,
                                    votes: 0
                                    });
        emit AirlineHasBeenRegistered(firstAirline);
        
        raisedFunds = raisedFunds.add(10);
        fundsLedger[firstAirline] = 10;
        emit FundsRaised(raisedFunds);
        
        authorizedCallers[firstAirline] = true;
        emit Authorized(firstAirline);
    }

    function()
    external
    payable 
    {
        fund(msg.sender, msg.value);
    }


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;
    }

    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedCaller(address _address)
    {
        require(msg.sender == _address, "The caller can not invoke this operation.");
        _;
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

    function setOperatingStatus(bool mode)
    external
    requireAuthorizedCaller(msg.sender)
    {
        require(mode != operational, "New mode must be different from existing mode");
        operational = mode;
        emit OperationalStatus(operational);
    }
    
    function isAuthorized(address addr)
    public
    view
    requireIsOperational
    returns(bool)
    {
        return authorizedCallers[addr];
    }

    function authorizeCaller(address addr)
    requireAuthorizedCaller(msg.sender)
    requireIsOperational
    {
        require(!isAuthorized(addr), "Caller is already authorized");
        authorizedCallers[addr] = true;
        emit Authorized(addr);
    }

    function unauthorizeCaller(address addr)
    requireAuthorizedCaller(msg.sender)
    requireIsOperational
    {
        require(isAuthorized(addr), "Caller is already unathorized");
        authorizedCallers[addr] = false;
        emit Unauthorized(addr);
    }

    function isAirlineCreated(address airlineAddress)
    public
    view
    requireIsOperational
    returns(bool)
    {
        return airlines[airlineAddress].id != 0;
    }

    function isAirlineRegistered(address airlineAddress)
    public
    view
    requireIsOperational
    returns(bool)
    {
        return airlines[airlineAddress].registered;
    }

    function isFunded(address addr)
    public
    view
    requireIsOperational
    returns(bool)
    {
        return fundsLedger[addr] > 0;
    }

    function getFunds(address addr)
    public
    view
    requireIsOperational
    returns(uint)
    {
        return fundsLedger[addr];
    }

    function getAirlinesCount()
    view
    requireIsOperational
    returns(uint)
    {
        return airlinesCount;
    }

    function getAirlineVotes(address airline)
    view
    requireIsOperational
    returns(uint)
    {
        return airlines[airline].votes;
    }

    function insuranceExists(bytes32 key)
    view
    requireIsOperational
    returns(bool)
    {
        return insurances[key];
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function createAirline(address airline)
    external
    requireIsOperational
    requireAuthorizedCaller(msg.sender)
    {
        airlinesCount = airlinesCount.add(1);
        airlines[airline] = Airline({
                                    id: airlinesCount,
                                    registered: false,
                                    votes: 0
                                    });
        emit AirlineHasBeenCreated(airline);
    }

    function voteAirline(address airline, address voter)
    external
    requireIsOperational
    requireAuthorizedCaller(msg.sender)
    {

        require(isAirlineCreated(airline), "Airline must be created before");
            
        airlines[airline].votes = airlines[airline].votes.add(1);
        airlines[airline].votedBy[voter] = true;
        emit AirlineHasBeenVoted(airline);
    }

    function registerAirline(address airline)
    external
    requireIsOperational
    requireAuthorizedCaller(msg.sender)
    {
        require(isAirlineCreated(airline), "Airline must be created before");
        airlines[airline].registered = true;
        emit AirlineHasBeenRegistered(airline);
    }
   
    function fund(address funder, uint amount)   
    requireAuthorizedCaller(msg.sender)
    payable
    {
        fundsLedger[funder] = fundsLedger[funder].add(amount);
        raisedFunds = raisedFunds.add(amount);
        emit FundsRaised(raisedFunds);

        if(fundsLedger[funder] > 10) {
            authorizedCallers[funder] = true;
            emit Authorized(funder);
        }
    }


    function buyInsurance(address passenger, uint amount, bytes32 key)
    external
    requireAuthorizedCaller(msg.sender)
    payable
    {
        fundsLedger[passenger] = fundsLedger[passenger].add(amount);
        raisedFunds.add(amount);
        emit FundsRaised(raisedFunds);

        insurances[key] = true;
        emit InsuranceHasBeenBought();
    }

    function creditInsurees(address passenger, uint credit, bytes32 key)
    external
    {
        fundsLedger[passenger] = 0;
        raisedFunds.sub(credit);
        insurances[key] = false;
        pay(passenger, credit);
    }
    
    function pay(address passenger, uint credit)
    internal
    {
        passenger.transfer(credit);
        emit Payment();
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp)
    pure
    internal
    returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
}

