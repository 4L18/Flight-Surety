var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;

  // Watch contract events
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;


  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
  });


  it('can register oracles', async () => {
    
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    for(let a=0; a < TEST_ORACLES_COUNT; a++) {
      console.log(accounts[a]);    
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can request flight status', async () => {
    
    await config.flightSuretyApp.fetchFlightStatus(config.firstAirline, config.flight, config.timestamp);
          let successCount = 0;

    for(let a=0; a<TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {

        try {
          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, config.flight, config.timestamp, STATUS_CODE_ON_TIME, { from: accounts[a] });
          console.log('\nSuccess', idx, oracleIndexes[idx].toNumber(), config.flight, config.timestamp);
          successCount++;
        }
        catch(e) {
          // Enable this when debugging
           console.log('\nError', idx, oracleIndexes[idx].toNumber(), config.flight, config.timestamp);
           console.log(e.message);
        }
      }
    }

          console.log('\nSuccess cases: ' + successCount);
  });
});