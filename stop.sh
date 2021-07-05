#!/bin/bash
set -uex

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
EXCHANGE_DIR=$DIR/dingir-exchange
PROVER_DIR=$DIR/prover-cluster
STATE_MNGR_DIR=$DIR/rollup-state-manager
HEIMDALLR_DIR=$DIR/Heimdallr

function kill_tasks() {
	# kill last time running tasks:
	#kill $(ps aux | grep 'demo_utils' | grep -v grep | awk '{print $2}')
	kill -9 $(ps aux | grep 'demo_utils' | grep -v grep | awk '{print $2}')
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
  sudo rm $dir/docker/data -rf
}

function stop_docker_composes() {
  stop_docker_compose $EXCHANGE_DIR docker
  stop_docker_compose $PROVER_DIR cluster
  stop_docker_compose $STATE_MNGR_DIR rollup
  stop_docker_compose $HEIMDALLR_DIR heimdallr
}

function main() {
	kill_tasks
	stop_docker_composes
}
main
