#!/bin/bash
set -uex

export NTXS=2;
export BALANCELEVELS=3;
export ORDERLEVELS=4;
export ACCOUNTLEVELS=4;
export VERBOSE=false;

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
STATE_MNGR_DIR=$DIR/rollup-state-manager
CIRCUITS_REPO_DIR=$STATE_MNGR_DIR/circuits
TARGET_CIRCUIT_DIR=$CIRCUITS_REPO_DIR/testdata/Block_$NTXS"_"$BALANCELEVELS"_"$ORDERLEVELS"_"$ACCOUNTLEVELS

# make sure submodule is correctly cloned!!
git submodule update --init --recursive
if [ -z ${CI+x} ]; then git pull --recurse-submodules; fi

cd $STATE_MNGR_DIR
cargo run --bin gen_export_circuit_testcase

cd $CIRCUITS_REPO_DIR
npm i
snarkit compile $TARGET_CIRCUIT_DIR --force_recompile --backend=native

