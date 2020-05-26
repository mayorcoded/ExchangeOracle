const Web3 = require("web3");
const OracleAbi = require("../build/contracts/Oracle.json");
const web3 = new Web3(
  new Web3.providers.HttpProvider(
    "https://mainnet.infura.io/v3/db0babc871d74cf79895319a8704666c"
  )
);

const OracleAddress = "0x424ab440df8e51ffa145040a12912518a839cb9b";

const Oracle = new web3.eth.Contract(OracleAbi.abi, OracleAddress);

runTests();

async function runTests() {
  try {
    // await getSynthetixData();
    // await getUniswapData();
    // await getBancorData();
    // await getOasisData();
    // await getCurveData();
    await getBalancerData();
  } catch (e) {
    console.log(e);
  }
}

async function getSynthetixData() {
  const synthetixData = await Oracle.methods.getSynthetixData().call();
  console.log("Synthetix: ", synthetixData);
}

async function getUniswapData() {
  let tokens = [
    "0x6b175474e89094c44da98b954eedeac495271d0f",
    "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
    "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "0x0d8775f648430679a709e98d2b0cb6250d2887ef",
    "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    "0x06AF07097C9Eeb7fD685c692751D5C66dB49c215"
  ];
  const uniswapData = await Oracle.methods.getUniswapData(tokens).call();
  console.log("Uniswap");
  for (let i = 0; i < tokens.length; i++) {
    console.log(tokens[i], uniswapData[i]);
  }
}

async function getBancorData() {
  const tokens = [
    "0x6b175474e89094c44da98b954eedeac495271d0f",
    "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
    "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "0x0d8775f648430679a709e98d2b0cb6250d2887ef"
  ];
  const converters = [
    "0xd99b0EFeeA095b87C5aD8BCc8B955eD5Ca5Ba146",
    "0xA2cAF0d7495360CFa58DeC48FaF6B4977cA3DF93",
    "0x220C400bC0a4347276b432843Cf293F1faC6762a",
    "0xBd19F30adDE367Fe06c0076D690d434bF945A8Fc"
  ];
  const bancorData = await Oracle.methods
    .getBancorData(tokens, converters)
    .call();
  console.log("Bancor");
  for (let i = 0; i < tokens.length; i++) {
    console.log(tokens[i], bancorData[i]);
  }
}

async function getCurveData() {
  const ids = ["0", "1", "2", "3"];
  const yTokens = [
    "0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01",
    "0xd6aD7a6750A7593E092a9B218d66C0A814a3436e",
    "0x83f798e925BcD4017Eb265844FDDAbb448f1707D",
    "0x73a052500105205d34Daf004eAb301916DA8190f"
  ];
  const curveData = await Oracle.methods.getCurveData(ids, yTokens).call();
  console.log("Curve");
  for (let i = 0; i < ids.length; i++) {
    console.log(ids[i], curveData[i]);
  }
}

async function getOasisData() {
  const bases = [
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "0x6b175474e89094c44da98b954eedeac495271d0f",
    "0x6b175474e89094c44da98b954eedeac495271d0f",
    "0x6b175474e89094c44da98b954eedeac495271d0f",
    "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  ];
  const quotes = [
    "0x6b175474e89094c44da98b954eedeac495271d0f",
    "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "0x0d8775f648430679a709e98d2b0cb6250d2887ef",
    "0xe41d2489571d322189246dafa5ebde1f4699f498",
    "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "0xe41d2489571d322189246dafa5ebde1f4699f498"
  ];
  console.log("Oasis");
  const oasisData = await Oracle.methods.getOasisData(bases, quotes).call();
  for (let i = 0; i < bases.length; i++) {
    console.log(bases[i], quotes[i], oasisData[i]);
  }
}

async function getBalancerData() {
  const pools = [
    '0x987D7Cc04652710b74Fff380403f5c02f82e290a',
    '0xd59BF8773F89e0DDE3eC745aEBEae0Da2b4AF66f',
    '0xc0b2B0C5376Cb2e6f73b473A7CAA341542F707Ce',
    '0x07d13ED39EE291C1506675Ff42f9B2b6b50E2d3E'
  ];
  console.log("Balancer");
  const balancerData = await Oracle.methods.getBalancerData(pools).call();
  for (let i = 0; i < pools.length; i++) {
    console.log(pools[i], balancerData[i]);
  }
}