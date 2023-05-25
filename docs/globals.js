const ADDRESS0 = "0x0000000000000000000000000000000000000000";
const generateRange = (start, stop, step) => Array.from({ length: (stop - start) / step + 1}, (_, i) => start + (i * step));
const delay = ms => new Promise(res => setTimeout(res, ms));
function handleErrors(response) {
  if (!response.ok) {
    throw Error(response.statusText);
  }
  return response;
}

const TRANSFER = 1;

const UNISWAPV2MINT = 21;
const UNISWAPV2SWAP = 22;
const UNISWAPV2BURN = 23;

const UNISWAPV3MINT = 31;
const UNISWAPV3SWAP = 32;
const UNISWAPV3BURN = 33;
const UNISWAPV3COLLECT = 34;
