import * as fs from 'fs';
import secrets from '../contracts/secrets.json';
import tokens from '/tmp/tokens.json';
import deployed from '/tmp/deployed.json';

async function main() {
    const listener_template = fs.readFileSync('../eth_listener/config.toml.template', 'utf-8');
    const NETWORK = process.env.DX_NETWORK ?? "geth";
    const INFRUA_API_KEY = secrets.infuraApiKey;
    const CONTRACT_ADDRESS = deployed.FluiDexDelegate;
    const INNER_CONTRACT_ADDRESS = deployed.FluiDexDemo;
    const BASE_BLOCK = deployed.baseBlock;
    fs.writeFileSync("../eth_listener/config.toml", eval("`" + listener_template + "`"));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
