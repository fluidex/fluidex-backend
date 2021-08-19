'use strict'
//const fs=require('fs')
const env = process.env

const imageData = {
  host: env.IMAGE_HOST_ALIAS || env.IMAGE_HOST,
  repo: env.IMAGE_REPO,
}

if (env.IMAGE_AUTH_USER) imageData.auth = {
  "user_name": env.IMAGE_AUTH_USER,
  password: env.IMAGE_AUTH_PASSWORD || "",
}

const deploy = {replica: env.CLIENT_REPLICAS || 1 }

if (env.CLUSTER_NS) deploy.namespace = env.CLUSTER_NS

if (env.CLUSTER_DEPLOYNAME) deploy.name = env.CLUSTER_DEPLOYNAME

const data = {
  stage: env.STAGE,
  "coordinator_endpoint": env.COORDINATOR_SERV,
  coordinator: {
    endpoint: env.COORDINATOR_EP,
    port: env.COORDINATOR_PORT || 50055,
  },
  "circuit_name": env.CIRCUIT || "block",
  image: imageData,
  deploy
  
}

console.log(JSON.stringify(data, null, '\t'))
