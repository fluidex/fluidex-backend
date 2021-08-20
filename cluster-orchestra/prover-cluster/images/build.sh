#!/bin/bash

docker build -f setup.docker . -t setup
#fast build plonkit from the first stage of setup
docker build --target plonkit -f setup.docker . -t plonkit
docker build -f prover.docker . -t prover
docker build -f cluster_client.docker . -t cluster_client
docker build -f cluster_client_test.docker . -t cluster_client_test
docker build -f cluster_coordinator.docker . -t cluster_coordinator
