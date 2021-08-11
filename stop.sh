#!/bin/bash
set -uex

source ./common.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
EXCHANGE_DIR=$DIR/dingir-exchange
STATE_MNGR_DIR=$DIR/rollup-state-manager
FAUCET_DIR=$DIR/regnbue-bridge
ORCHESTRA_DIR=$DIR/orchestra

function kill_tasks() {
  # kill last time running tasks:
  ps aux | grep 'fluidex-backend' | grep -v grep | awk '{print $2 " " $11}'
  kill -9 $(ps aux | grep 'fluidex-backend' | grep -v grep | awk '{print $2}') || true
  # tick.ts
  # matchengine
  # rollup_state_manager
  # coordinator
  # prover
}

function stop_docker_compose() {
  dir=$1
  name=$2
  docker-compose --file $dir/docker/docker-compose.yaml --project-name $name down
  docker_rm $dir/docker/data -rf
}

function stop_docker_composes() {
  stop_docker_compose $ORCHESTRA_DIR orchestra
  stop_docker_compose $FAUCET_DIR faucet
}

function clean_data() {
  rm -rf rollup-state-manager/circuits/testdata/persist/
}

kill_tasks
stop_docker_composes
clean_data
