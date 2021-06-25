#!/bin/bash
set -uex

# assume already install: libgmp-dev nasm nlohmann-json3-dev snarkit plonkit

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
plonkit setup --power 20 --srs_monomial_form $TARGET_CIRCUIT_DIR/mon.key
plonkit dump-lagrange -c $TARGET_CIRCUIT_DIR/circuit.r1cs --srs_monomial_form $TARGET_CIRCUIT_DIR/mon.key --srs_lagrange_form $TARGET_CIRCUIT_DIR/lag.key
plonkit export-verification-key -c $TARGET_CIRCUIT_DIR/circuit.r1cs --srs_monomial_form $TARGET_CIRCUIT_DIR/mon.key -v $TARGET_CIRCUIT_DIR/vk.bin

cd $PROVER_DIR

PORT=50055
printf 'port: %d
db: postgres://coordinator:coordinator_AA9944@127.0.0.1:5433/prover_cluster
witgen:
  interval: 10000
  n_workers: 5
  circuits:
    block: "%s/circuit.fast"
' $PORT $TARGET_CIRCUIT_DIR > $PROVER_DIR/config/coordinator.yaml

printf '
prover_id: 1
upstream: "http://[::1]:50055"
poll_interval: 10000
circuit: "block"
r1cs: "%s/circuit.r1cs"
srs_monomial_form: "%s/mon.key"
srs_lagrange_form: "%s/lag.key"
vk: "%s/vk.bin"
' $TARGET_CIRCUIT_DIR $TARGET_CIRCUIT_DIR $TARGET_CIRCUIT_DIR $TARGET_CIRCUIT_DIR > $PROVER_DIR/config/client.yaml

# TODO: send different tasks to different tmux windows 

docker-compose --file $EXCHANGE_DIR/docker/docker-compose.yaml down
sudo rm $EXCHANGE_DIR/docker/data -rf
docker-compose --file $EXCHANGE_DIR/docker/docker-compose.yaml up --force-recreate --detach
docker-compose --file $PROVER_DIR/docker/docker-compose.yaml --project-name cluster down
sudo rm $PROVER_DIR/docker/data -rf
docker-compose --file $PROVER_DIR/docker/docker-compose.yaml --project-name cluster up --force-recreate --detach

cd $EXCHANGE_DIR
cargo build --bin matchengine
nohup $EXCHANGE_DIR/target/debug/matchengine >> $EXCHANGE_DIR/matchengine.log 2>&1 &

# run coordinator because we need to init db
cd $PROVER_DIR
cargo build --release
nohup $PROVER_DIR/target/release/coordinator >> $PROVER_DIR/coordinator.log 2>&1 &

cd $STATE_MNGR_DIR
cargo build --release --bin rollup_state_manager
nohup $STATE_MNGR_DIR/target/release/rollup_state_manager >> $STATE_MNGR_DIR/rollup_state_manager.log 2>&1 &

cd $EXCHANGE_DIR/examples/js/
npm i
nohup npx ts-node tick.ts >> $EXCHANGE_DIR/tick.log 2>&1 &

cd $PROVER_DIR
$PROVER_DIR/target/release/client
