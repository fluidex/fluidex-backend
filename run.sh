#!/bin/bash
set -uex

# TODO: detect file and skip

export NTXS=2;
export BALANCELEVELS=3;
export ORDERLEVELS=4;
export ACCOUNTLEVELS=4;
export VERBOSE=false;

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
STATE_MNGR_DIR=$DIR/rollup-state-manager
CIRCUITS_DIR=$STATE_MNGR_DIR/circuits
TARGET_CIRCUIT_DIR=$CIRCUITS_DIR/testdata/Block_$NTXS"_"$BALANCELEVELS"_"$ORDERLEVELS"_"$ACCOUNTLEVELS
PROVER_DIR=$DIR/prover-cluster
EXCHANGE_DIR=$DIR/dingir-exchange

# make sure submodule is correctly cloned!!
git submodule update --init --recursive
if [ -z ${CI+x} ]; then git pull --recurse-submodules; fi

rm $TARGET_CIRCUIT_DIR -rf
cd $STATE_MNGR_DIR
cargo run --bin gen_export_circuit_testcase

cd $CIRCUITS_DIR
npm i
# TODO: detect and install snarkit
snarkit compile $TARGET_CIRCUIT_DIR --force_recompile --backend=native

cd $PROVER_DIR

PORT=50055
export DB_URL=postgres://coordinator:coordinator_AA9944@127.0.0.1:5433/prover_cluster
printf 'port: %d
db: "%s"
witgen:
  interval: 10000
  n_workers: 5
  circuits:
    block: "%s/circuit.fast"
' $PORT $DB_URL $TARGET_CIRCUIT_DIR > $PROVER_DIR/config/coordinator.yaml

# docker-compose --file $EXCHANGE_DIR/docker/docker-compose.yaml --project-name exchange up --force-recreate --detach
docker-compose --file $EXCHANGE_DIR/docker/docker-compose.yaml up --force-recreate --detach
docker-compose --file $PROVER_DIR/docker/docker-compose.yaml --project-name cluster up --force-recreate --detach

