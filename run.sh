#!/bin/bash
set -uex

# assume already install: libgmp-dev nasm nlohmann-json3-dev snarkit plonkit

source ./common.sh
source ./envs/small
export VERBOSE=false
export RUST_BACKTRACE=full

if [[ -v DIRTY ]] && [[ ! -v FORCE ]] ; then
  echo -e "\033[31mDirty workspace, run stop.sh or set env FORCE to continue.\033[0m"
  exit 1
fi

export DIRTY=true

DX_NETWORK=${DX_NETWORK:-geth}
WEB3_URL=${WEB3_URL:-http://localhost:8545}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
STATE_MNGR_DIR=$DIR/rollup-state-manager
CIRCUITS_DIR=$DIR/circuits
BLOCKSCOUT_DIR=$DIR/blockscout
TARGET_CIRCUIT_DIR=$CIRCUITS_DIR/testdata/Block_$NTXS"_"$BALANCELEVELS"_"$ORDERLEVELS"_"$ACCOUNTLEVELS
PROVER_DIR=$DIR/prover-cluster
EXCHANGE_DIR=$DIR/dingir-exchange
REGNBUE_DIR=$DIR/regnbue-bridge
FAUCET_DIR=$DIR/faucet
CONTRACTS_DIR=$DIR/contracts
MISC_DIR=$DIR/misc
LISTENER_DIR=$DIR/eth_listener
ORCHESTRA_DIR=$DIR/orchestra

ROLLUP_DB="postgres://rollup:rollup_AA9944@127.0.0.1:5433/rollup"
LISTENER_DB="postgresql://listener:listener_AA9944@0.0.0.0:5437/eth_listener"

CURRENTDATE=$(date +"%Y-%m-%d")

MNEMONIC="anxiety else floor soap tent sight belt leave top velvet meadow walk intact spice polar"

[[ -v ENVSUB ]] || ENVSUB=envsub

function handle_submodule() {
  git submodule update --init --recursive
  if [ -z ${CI+x} ]; then git pull --recurse-submodules; fi
}

function prepare_circuit() {
  rm -rf $TARGET_CIRCUIT_DIR
  #cd $STATE_MNGR_DIR
  #cargo run --bin gen_export_circuit_testcase
  mkdir -p $TARGET_CIRCUIT_DIR
  CIRCUITS_DIR=$CIRCUITS_DIR $ENVSUB > $TARGET_CIRCUIT_DIR/circuit.circom << EOF
include "${CIRCUITS_DIR}/src/block.circom";
component main = Block(${NTXS}, ${BALANCELEVELS}, ${ORDERLEVELS}, ${ACCOUNTLEVELS});
EOF
  echo 'circuit source:'
  cat $TARGET_CIRCUIT_DIR/circuit.circom

  cd $CIRCUITS_DIR

  npm i
  # TODO: detect and install snarkit
  # if you encounter issues on compile, try using following cmd line instead: 
  # see https://github.com/fluidex/snarkit/issues/14 
  # snarkit compile $TARGET_CIRCUIT_DIR --backend=auto 2>&1 | tee /tmp/snarkit.log
  snarkit2 compile $TARGET_CIRCUIT_DIR --verbose --backend=auto 2>&1 | tee /tmp/snarkit.log

  plonkit setup --power 20 --srs_monomial_form $TARGET_CIRCUIT_DIR/mon.key
  # plonkit dump-lagrange -c $TARGET_CIRCUIT_DIR/circuit.r1cs --srs_monomial_form $TARGET_CIRCUIT_DIR/mon.key --srs_lagrange_form $TARGET_CIRCUIT_DIR/lag.key
  plonkit export-verification-key -c $TARGET_CIRCUIT_DIR/circuit.r1cs --srs_monomial_form $TARGET_CIRCUIT_DIR/mon.key -v $TARGET_CIRCUIT_DIR/vk.bin
}

function prepare_contracts() {
  rm -f $CONTRACTS_DIR/contracts/Verifier.sol
  plonkit generate-verifier -v $TARGET_CIRCUIT_DIR/vk.bin -s $CONTRACTS_DIR/contracts/Verifier.sol
  cd $CONTRACTS_DIR/
  # no need for this
  # git update-index --assume-unchanged $CONTRACTS_DIR/contracts/Verifier.sol
  yarn install
  npx hardhat compile
}

function config_prover_cluster() {
  cd $PROVER_DIR

  PORT=50055 DB=$ROLLUP_DB WITGEN_INTERVAL=2500 N_WORKERS=10 TARGET_CIRCUIT_DIR=$TARGET_CIRCUIT_DIR N_TXS=$NTXS $ENVSUB < $PROVER_DIR/config/coordinator.yaml.template > $PROVER_DIR/config/coordinator.yaml
  TARGET_CIRCUIT_DIR=$TARGET_CIRCUIT_DIR N_TXS=$NTXS $ENVSUB < $PROVER_DIR/config/client.yaml.template > $PROVER_DIR/config/client.yaml
}

# TODO: send different tasks to different tmux windows

function start_docker_compose() {
  dir=$1
  name=$2
  cd $dir
  docker-compose --file docker/docker-compose.yaml --project-name $name up --build --force-recreate --detach
  cd -
}

function run_docker_compose() {
  start_docker_compose $ORCHESTRA_DIR orchestra
  start_docker_compose $REGNBUE_DIR faucet
  if [ $DX_NETWORK == 'geth' ]; then
    start_docker_compose $BLOCKSCOUT_DIR blockscout # geth node & blockscout stuff
  fi
  sleep 10
}

function run_matchengine() {
  cd $EXCHANGE_DIR
  cp /tmp/markets_preset.sql migrations/20210223072038_markets_preset.sql
  git update-index --assume-unchanged migrations/20210223072038_markets_preset.sql
  make startall
  #cargo build --bin matchengine
  #nohup $EXCHANGE_DIR/target/debug/matchengine >> $EXCHANGE_DIR/matchengine.$CURRENTDATE.log 2>&1 &
}

function run_ticker() {
  cd $EXCHANGE_DIR/examples/js/
  npm i
  nohup npx ts-node tick.ts >> $EXCHANGE_DIR/tick.$CURRENTDATE.log 2>&1 &
}

function run_rollup() {
  cd $STATE_MNGR_DIR
  mkdir -p circuits/testdata/persist
  cargo build --release --bin rollup_state_manager
  nohup $STATE_MNGR_DIR/target/release/rollup_state_manager >> $STATE_MNGR_DIR/rollup_state_manager.$CURRENTDATE.log 2>&1 &
}

function run_prove_master() {
  # run coordinator because we need to init db
  cd $PROVER_DIR
  cargo build --release
  nohup $PROVER_DIR/target/release/coordinator >> $PROVER_DIR/coordinator.$CURRENTDATE.log 2>&1 &
}

function run_prove_workers() {
  cd $PROVER_DIR # need to switch into PROVER_DIR to use .env
  if [ ! -f $PROVER_DIR/target/release/client ]; then
    cargo build --release
  fi
  if [[ ! -z ${NO_LOCAL_WORKER+x}  ]]; then
    return
  fi
  if [ $OS = "Darwin" ]; then
    (nice -n 20 nohup $PROVER_DIR/target/release/client >> $PROVER_DIR/client.$CURRENTDATE.log 2>&1 &)
  else
    nohup $PROVER_DIR/target/release/client >> $PROVER_DIR/client.$CURRENTDATE.log 2>&1 &
    sleep 1
    cpulimit -P $PROVER_DIR/target/release/client -l $((50 * $(nproc))) -b -z # -q
  fi
}

function boostrap_contract() {
  cd $CONTRACTS_DIR
  yarn install
}

function deploy_tokens() {
  cd $FAUCET_DIR/layer1/contracts
  yarn install
  npx hardhat run scripts/deploy.js --network $DX_NETWORK
}

function deploy_contracts() {
  cd $CONTRACTS_DIR
  export GENESIS_ROOT=$(cat $STATE_MNGR_DIR/rollup_state_manager.$CURRENTDATE.log | grep "genesis root" | tail -n1 | awk '{print $9}' | sed 's/Fr(//' | sed 's/)//')
  export CONTRACT_ADDR=$(retry_cmd_until_ok npx hardhat run scripts/deploy.ts --network $DX_NETWORK | grep "FluiDexDelegate deployed to:" | awk '{print $4}')
  echo "export CONTRACT_ADDR=$CONTRACT_ADDR" > $CONTRACTS_DIR/contract-deployed.env
}

function run_misc_scripts() {
  cd $MISC_DIR
  yarn install
  npx ts-node index.ts # todo: local network
  npx ts-node gen_config.ts # generate listener config
}

function restore_contracts() {
  source $CONTRACTS_DIR/contract-deployed.env
}

function run_listener {
  cd $LISTENER_DIR
  CONTRACT_FILE=$CONTRACTS_DIR/artifacts/contracts/FluiDex.sol/FluiDexDemo.json DELEGATE_CONTRACT_FILE=$CONTRACTS_DIR/artifacts/contracts/FluiDexDelegate.sol/FluiDexDelegate.json $ENVSUB < $LISTENER_DIR/build-config.toml.template > $LISTENER_DIR/build-config.toml
  cargo build --release
  psql $LISTENER_DB < init.sql 
  nohup "$LISTENER_DIR/target/release/eth_listener" >> $LISTENER_DIR/eth_listener.$CURRENTDATE.log 2>&1 &
}

function run_faucet() {
  cd $REGNBUE_DIR
  cargo build --release --bin faucet
  nohup "$REGNBUE_DIR/target/release/faucet" >> $REGNBUE_DIR/faucet.$CURRENTDATE.log 2>&1 &
}

# TODO: need to fix task_fetcher, gitignore, comfig template & example, contracts...
function run_block_submitter() {
  cd $REGNBUE_DIR
  cargo build --release --bin block_submitter
  DB=$ROLLUP_DB CONTRACTS_DIR=$CONTRACTS_DIR CONTRACT_ADDR=$CONTRACT_ADDR WEB3_URL=$WEB3_URL $ENVSUB < $REGNBUE_DIR/config/block_submitter.yaml.template > $REGNBUE_DIR/config/block_submitter.yaml
  nohup "$REGNBUE_DIR/target/release/block_submitter" >> $REGNBUE_DIR/block_submitter.$CURRENTDATE.log 2>&1 &
}

function run_bin() {
  deploy_tokens
  
  run_matchengine
  run_prove_master
  run_prove_workers
  run_rollup

  sleep 10
  boostrap_contract
  if [ $DX_CLEAN == 'TRUE' ]; then
    deploy_contracts
    sleep 30
    run_misc_scripts
  else
    restore_contracts
  fi
  
  run_listener
  run_faucet
  run_block_submitter
}

function setup() {
  handle_submodule
  prepare_circuit
  prepare_contracts
}

function run_all() {
  config_prover_cluster
  run_docker_compose
  run_bin
  run_ticker
}

if [[ -z ${AS_RESOURCE+x}  ]]; then
  setup
  run_all
fi
