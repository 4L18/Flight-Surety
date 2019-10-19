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
        fund();
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

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
}

