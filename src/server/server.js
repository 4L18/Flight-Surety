import "regenerator-runtime/runtime";
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


const config = Config['localhost'];
const web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
const flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let accounts;
let defaultAccount;
let fee;
var oracles = [];

async function setup() {
  
  accounts = await web3.eth.getAccounts();
  defaultAccount = accounts[0];
  fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  registerOracles();
}

async function registerOracles() {
    
    for(let i = 0; i < accounts.length; i++) {
      
      console.log(accounts[i]);
      await flightSuretyApp.methods.registerOracle().send({ from: accounts[i], value: fee, gas: 3000000 });
      let indexes = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]});;
      oracles.push({
                address: accounts[i],
                indexes: indexes
            });
    }
    console.log('Oracles are registered');
}

setup();


flightSuretyApp.events.OracleRequest({
            //fromBlock: 0
    }, async function (error, event) {
        
        let statusCode = Math.floor(Math.random() * 10);
        let eventValue = event.returnValues;
        console.log('Event ', eventValue);

        oracles.forEach((oracle) => {
            oracle.indexes.forEach(async (index) => {
                if (index !== eventValue.index) {
                    return;
                }

                try {
                    
                    await flightSuretyApp.methods.submitOracleResponse(
                        index,
                        eventValue.airline,
                        eventValue.flight,
                        eventValue.timestamp,
                        statusCode
                    ).call({from: oracle.address});
                    console.log(`Result: ${oracle.address}  Index:  ${index}  StatusCode: ${statusCode}`);
                
                } catch(error) {
                    console.log(`Oracle '${index} was rejected because: "${error.message}"'`);
                }
            
            });
        });
    });

const app = express();

app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
});

export default app;
