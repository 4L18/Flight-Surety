
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  const PREFIX = "VM Exception while processing transaction: ";
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
  /* Added tests                                                              */
  /****************************************************************************************/

  // Airlines
  it('First airline is registered when contract is deployed', async () => {
      
    let isRegistered = await config.flightSuretyData.isAirlineRegistered(config.firstAirline, { from: config.flightSuretyApp.address});
    assert.equal(isRegistered, true, "First airline is not registered");
  });

  it('Only existing airline may register a new airline until there are at least four airlines registered', async () => {

    let isAuthorized;
    let airlinesRegistered = await config.flightSuretyData.getAirlinesCount();
    assert(airlinesRegistered < 5, "There are more than 4 airlines registered");

    try {
        
        isAuthorized = await config.flightSuretyData.isAuthorized(config.testAddresses[2]);
        assert(isAuthorized, false, "Address not authorized to call");
        
        await config.flightSuretyApp.registerAirline(config.testAddresses[2], { from: accounts[2]});
    
    } catch (error) {
        assert(error, error.message);
    }

    try {
        
        isAuthorized = await config.flightSuretyData.isAuthorized(config.firstAirline);
        assert(isAuthorized, true, "First airline is not authorized to call");
        
        await config.flightSuretyApp.registerAirline(config.testAddresses[2], { from: config.firstAirline });
        let isRegistered = await config.flightSuretyData.isAirlineRegistered(config.testAddresses[2], { from: config.firstAirline});
        assert.equal(isRegistered, true, "First airline can register airline");
    
    } catch (error) {
        console.log(error.message);
    }
  });

  it('Airline can be registered, but does not participate in contract until it submits funding of 10 ether', async () => {
    
        let isRegistered;
        for(let i = 3; i < 6; i++) {
            await config.flightSuretyApp.registerAirline(config.testAddresses[i], { from: config.firstAirline });
            isRegistered = await config.flightSuretyData.isRegistered(config.testAddresses[i]);
            assert(isRegistered, "Airline has not been registered");
        }

        try {
            await config.flightSuretyApp.registerAirline(config.testAddresses[6], { from: testAddresses[3] });
        } catch (error) {
            assert(error, error.message);
        }

        let isAuth;
        for(let i = 2; i < 6; i++) {
            await config.flightSuretyApp.fund({ from: config.testAddresses[i], value: 10 });        
            isAuth = config.flightSuretyData.isAuthorized(config.testAddresses[i]);
            assert(isAuth, "Submit 10 ether does not authorize airline");
        }
        
        try {
            await config.flightSuretyApp.registerAirline(config.testAddresses[6], { from: testAddresses[3] });
        } catch (error) {
            console.log(error.message);
        }
        
  });

  it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {
    
    let isRegistered = true;

    try {
        
        let airlinesRegistered = await config.flightSuretyData.getAirlinesCount();
        assert(airlinesRegistered >= 5, "There are less than 5 airlines registered");

        await config.flightSuretyApp.registerAirline(config.testAddresses[7], { from: config.firstAirline });
        await config.flightSuretyApp.registerAirline(config.testAddresses[7], { from: config.testAddresses[2] });

        isRegistered = await config.flightSuretyData.isAirlineRegistered(config.testAddresses[6]);
        assert.equal(isRegistered, false, "6th airline should not be registered");

        await config.flightSuretyApp.registerAirline(config.testAddresses[7], { from: config.testAddresses[3] });
        await config.flightSuretyApp.registerAirline(config.testAddresses[7], { from: config.testAddresses[4] });
        await config.flightSuretyApp.registerAirline(config.testAddresses[7], { from: config.testAddresses[5] });
        
        isRegistered = await config.flightSuretyData.isAirlineRegistered(config.testAddresses[6]);
        assert(isRegistered, "6th airline should be registered");

    } catch (error) {
        assert(error, error.message);
    }
  });

  // Passengers
  it('Passengers may pay up to 1 ether for purchasing flight insurance', async () => {
      
    try {

        await config.flightSuretyApp.buyInsurance(config.flight, config.timestamp, { from: accounts[3] });
        
        let isFunded = await config.flightSuretyData.isFunded(accounts[3]);
        assert(isFunded, "No funds added after purchase")

        let key = config.flightSuretyApp.generateInsuranceKey(accounts[3], config.flight, config.timestamp);
        let exists = await config.flightSuretyData.insuranceExists(key);
        assert(exists, "Passenger could not purchaise flight insurance");

    }  catch (error) {
        console.log(error);
    }
  });

  it('If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid', async () => {
  });

  it('Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout', async () => {
  });

  it('Insurance payouts are not sent directly to passenger’s wallet', async () => {
  });
});
