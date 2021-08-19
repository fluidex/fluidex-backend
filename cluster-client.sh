#!/bin/bash
set -uex

# assume already install: libgmp-dev nasm nlohmann-json3-dev snarkit plonkit
AS_RESOURCE=yes source ./run.sh

IMAGE_AUTH_USER=beatrix@163.com
IMAGE_AUTH_PASSWORD=1yhq8tvrcv44AlC
IMAGE_HOST=registry.cn-wulanchabu.aliyuncs.com
IMAGE_HOST_ALIAS=registry-vpc.cn-wulanchabu.aliyuncs.com
IMAGE_REPO=fluidex-demo/prover

COORDINATOR_EP=10.18.68.177
#COORDINATOR_PORT=50055
#COORDINATOR_SERV="http://cluster-coordinator:50055"
CLIENT_REPLICAS=2
CLUSTER_NS=test

CLUSTER_ORCHESTRA_DIR=$DIR/cluster-orchestra/prover-cluster

[[ -v STAGE ]]
if [ ! $? -eq 0 ]; then
  STAGE=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)
fi

function cluster_submodule() {
  git submodule init cluster-orchestra
}

function prepare_image() {

  cd $CLUSTER_ORCHESTRA_DIR/images
  docker build -f prover.docker -t prover .

  TARGET_IMAGE=${IMAGE_HOST}/${IMAGE_REPO}:client-${STAGE}
 
  echo "Will create and push image ${TARGET_IMAGE}"

  cd ${TARGET_CIRCUIT_DIR}
  docker build --no-cache -f $CLUSTER_ORCHESTRA_DIR/images/cluster_client_externalbuild.docker -t ${TARGET_IMAGE} .

  if [[ -n $IMAGE_AUTH_USER ]]; then
    docker login --username ${IMAGE_AUTH_USER} -p ${IMAGE_AUTH_PASSWORD} ${IMAGE_HOST}
  fi

  docker push ${TARGET_IMAGE}
}


function prepare_cluster() {

  which ejs
  if [ ! $? -eq 0 ]; then
    sudo npm i -g ejs
  fi

  mkdir -p $WORK_DIR
  set +u
  STAGE=${STAGE} IMAGE_HOST=${IMAGE_HOST} IMAGE_REPO=${IMAGE_REPO} IMAGE_HOST_ALIAS=${IMAGE_HOST_ALIAS} IMAGE_AUTH_USER=${IMAGE_AUTH_USER} \
  IMAGE_AUTH_PASSWORD=${IMAGE_AUTH_PASSWORD} CLIENT_REPLICAS=${CLIENT_REPLICAS} CLUSTER_NS=${CLUSTER_NS} CLUSTER_DEPLOYNAME=${CLUSTER_DEPLOYNAME} CIRCUIT=${CIRCUIT}\
  COORDINATOR_EP=${COORDINATOR_EP} COORDINATOR_PORT=${COORDINATOR_PORT} COORDINATOR_SERV=${COORDINATOR_SERV} \
  node cluster-data-gen.js > ${WORK_DIR}/data.json
  set -u

  template_dir=${CLUSTER_ORCHESTRA_DIR}/commonk8s
  ejs ${template_dir}/0_configmaps.yaml.template -f ${WORK_DIR}/data.json -o ${WORK_DIR}/0_configmaps.yaml

if [[ -n $IMAGE_AUTH_USER ]]; then
  ejs ${template_dir}/0_secrets_image.yaml.template -f ${WORK_DIR}/data.json -o ${WORK_DIR}/0_secrets_image.yaml
fi

  ejs ${template_dir}/1_coordinator_ep.yaml.template -f ${WORK_DIR}/data.json -o ${WORK_DIR}/1_coordinator_ep.yaml
  ejs ${template_dir}/2_services_external.yaml.template -f ${WORK_DIR}/data.json -o ${WORK_DIR}/2_services_external.yaml
  ejs ${template_dir}/3_client.yaml.template -f ${WORK_DIR}/data.json -o ${WORK_DIR}/3_client.yaml

# kubectl apply -f ${WORK_DIR}/0_secrets_image.yaml

}

#test k8s
which kubectl
if [ ! $? -eq 0 ]; then
  echo "we need kubectl and config it to access an k8s cluster"
  exit 1
fi

kubectl cluster-info
if [ ! $? -eq 0 ]; then
  echo "k8s cluster can not be accessed normally"
  exit 1
fi


WORK_DIR=/tmp/clibuild-${STAGE}


#function test_k8s() {
#}


