
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = config.testAddresses[2];
    let isRegistered = await config.flightSuretyData.isAirlineRegistered(newAirline);
    assert.equal(isRegistered, false, "Account should not be registered");
    
    let callerAccount = config.testAddresses[2];
    let isFunded = await config.flightSuretyData.isFunded(callerAccount);
    assert.equal(isFunded, false, "Account should not be authorized");

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: callerAccount});
    }
    catch(e) {
    }

    // ASSERT
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");
  });

  /****************************************************************************************/
  /* Added tests                                                                          */
  /****************************************************************************************/

  // Airlines
  it('First airline is registered when contract is deployed', async () => {
      
    try {
        let isRegistered = await config.flightSuretyData.isAirlineRegistered(config.firstAirline, { from: config.firstAirline});
        assert(isRegistered, "First airline is not registered");
        let isAuthorized = await config.flightSuretyData.isAuthorized(config.firstAirline, { from: config.firstAirline});
        assert(isAuthorized, "First airline is not authorized");

    } catch (error) {
        console.log(error);
    }
  });

  it('Airline can be registered, but does not participate in contract until it submits funding of 10 ether', async () => {
    
    await config.flightSuretyApp.registerAirline(accounts[2], { from: config.firstAirline});
    let isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[2]);
    assert(isRegistered, "This account should be registered");

    try {
        let isParticipant = await config.flightSuretyData.isAirlineParticipant(accounts[2]);
        await config.createAirline(config.testAddresses[3], { from: accounts[2]});
    } catch(error) {
        assert(error, "Address should not be authorized to call");
    }

    await config.flightSuretyApp.fundAirline({ from: accounts[2], value: 10 });
    isParticipant = await config.flightSuretyData.isAirlineParticipant(accounts[2]);
    assert(isParticipant, "This account should be a participant");
    await config.flightSuretyApp.registerAirline(accounts[3], { from: accounts[2]});
    isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[3]);
    assert(isRegistered, true, "This airline should be registered");
  });

  it('Only existing airline may register a new airline until there are at least four airlines registered', async () => {

    try {
        await config.flightSuretyApp.registerAirline(accounts[4], { from: accounts[6] });
    } catch(error) {
        assert(error, "4th airline should not be registered");
    }

    let participants = await config.flightSuretyData.getParticipantsCount();
    assert(participants < 5, "There are more than 4 airlines participating");

    await config.flightSuretyApp.fundAirline({ from: accounts[3], value: 10 });
    isParticipant = await config.flightSuretyData.isAirlineParticipant(accounts[3]);
    assert(isParticipant, "3rd should be a participant");
    
    await config.flightSuretyApp.registerAirline(accounts[4], { from: accounts[2] });
    let isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[4]);
    assert(isRegistered, "4th airline should be registered");

    await config.flightSuretyApp.fundAirline({ from: accounts[4], value: 10 });
    isParticipant = await config.flightSuretyData.isAirlineParticipant(accounts[4]);
    assert(isParticipant, "4th account should be a participant");

    await config.flightSuretyApp.registerAirline(accounts[5], { from: accounts[2] });
    isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[5]);
    assert(isRegistered, "5th airline should be registered");

    await config.flightSuretyApp.fundAirline({ from: accounts[5], value: 10 });
    isParticipant = await config.flightSuretyData.isAirlineParticipant(accounts[5]);
    assert(isParticipant, "5th account should be a participant");

    airlinesRegistered = await config.flightSuretyData.getParticipantsCount();
    assert(airlinesRegistered == 5, "Should be 5 airlines registered");
    
    await config.flightSuretyApp.registerAirline(accounts[6], { from: accounts[2] });
    isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[6]);
    assert(!isRegistered, "6th airline should not be registered");
  });

  it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {
    
    let airlinesRegistered = await config.flightSuretyData.getParticipantsCount();
    assert(airlinesRegistered == 5, "There are less than 5 airlines registered");

    try {
        await config.flightSuretyApp.registerAirline(accounts[6], { from: accounts[2] });
    } catch(error) {
        assert(error, "2nd airline should not be able to vote 6th again");
    }
    await config.flightSuretyApp.registerAirline(accounts[6], { from: config.firstAirline });
    isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[6]);
    assert(!isRegistered, "6th airline should not be registered");

    await config.flightSuretyApp.registerAirline(accounts[6], { from: accounts[3] });
    isRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[6]);
    assert(isRegistered, "6th airline should be registered");
  });

  it('Passengers may pay up to 1 ether for purchasing flight insurance', async () => {

    let passenger = accounts[7];
    await config.flightSuretyApp.registerFlight(config.flight, config.firstAirline, config.timestamp, { from: config.firstAirline });
    await config.flightSuretyApp.buyInsurance(config.flight, config.timestamp, { from: passenger, value: 1 });

    let key = await config.flightSuretyApp.generateInsuranceKey.call(passenger, config.flight, config.timestamp);
    let exists = await config.flightSuretyData.insuranceExists(key);
    assert(exists, "Passenger could not purchaise flight insurance");
    
    let funds = await config.flightSuretyData.getFunds(passenger);
    assert(funds == 1, "No funds added after purchase");
  });
});
