let accounts = require("fs").readFileSync("./accounts.jsonl", "utf-8").split("\n").filter(Boolean).map(JSON.parse);

interface Account {
  account_id: number,
  mnemonic: string,
  priv_key: string,
  eth_addr: string,
}

export function getTestAccount(id: number): Account {
  let a = accounts[id];
  return a;
}
