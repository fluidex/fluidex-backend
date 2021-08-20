# Connect backend with a prover cluster

It is possible to build a cluster of prove-clients and connect it to the backend so the compuational heavy task could be assigned to mutiple power machines

## Prerequisite

Currently we can only deploy clients on a running kubernetes cluster. You should own required access privileges including create and update any kinds of resources in at least a specified namespace in that cluster.

You can deploy only one prove-client clusters inside a namespace.

## Configuration

You must make correct configurations to ensure the deployment script run as expected.

### image service

Kubernete pods will pull a docker image for running and you must configure an image service (like dockerhub) to deliver your working image and accessible to the kubernete pod. Following envirment variables must be set:

+ IMAGE_REPO: the path of image reposity that working image will be delivered to and pull by kubernete pod. like `fluidex.com/prover-cluster`

+ IMAGE_HOST: for any image service beyond dockerhub, the host of the service has to be specified so you can deliver the working image into this service

+ IMAGE_HOST_ALIAS: the host of image service which kubernete pod would pull from. In some case it may different from the IMAGE_HOST, which you use to deliver the image. For example, you can deliver the image from a intranet endpoint of the image service while kubernete pod pull them from a public entry on internet, vice versa. 

+ IMAGE_AUTH_USER/IMAGE_AUTH_PASSWORD: specify the access credential of the image service, and image would be deliver and pull with that

Our deployment script would build a working image which is unique with the current git commit of fluidex-backend, tagging it and deliver to the image service you have configured.

### access endpoint

After deployment, prove cluster had to access its coordinator which is running outside of the kubernetes cluster. A endpoint IP has to be known by the prove client so it can contact with the coordinator

+ COORDINATOR_EP: the IP of the machine which coordinator is running on, any kubernetes node must be able to access this IP and the service port of coordinator

+ COORDINATOR_PORT: you can (optionally) specify the service port of coordinator, by defaut it is 50055

### namespace

Set CLUSTER_NS to deploy prove cluster in the corresponding namespace of kubernetes, it is not recommend to deploy it in the default namespace (when CLUSTER_NS is not set)

### stage

Deployment scripts generate a unique tag from the current git commit of backend it is running on, and use this tag to make all stuffs required by deployment (images, kubernetes resources, etc). You can also set the STAGE enviroment variant to setup a deployment belong to yourself.

## cluster-client.sh

Use cluster-client.sh to deploy, update and release the cluster. It must be run under the same enviroment also work for run.sh, and additionaly require `kubectl` avaiable. The script use kubectl to access the kubernete cluster you wish to deploy prove cluster on.

cluser-client.sh is a 'resource' script which prove a series of functions but never running it inside itself. To use the script commonly we should import (`source`) the code to bash and execute some function expilicitily, like:

```bash

$ bash -c "source ./cluster-client.sh && <some function> [&& <another function>]*
```

cluster-client.sh also import all code inside run.sh

The functions cluster-client.sh has provided include:

+ run_all: setup the whole backend, deploy prove cluster and start running like calling run.sh

+ setup_all: do everything in run_all except for run_ticker in run.sh, so no simulating data would be generated. If there is no external request, everything would be just lauched and nothing for them to do.

+ reset_endpoint: when there is a prove cluster being deployed and the endpoint coordinator is changed, you can configure the new endpoing IP from enviroment and call this function to notify prove cluster using the new IP

+ scale_cluster: scale or unscale the number of clients, set the number as parameter of the function, like: `bash -c "source ./cluster-client.sh" && scale_cluster 50`. Notice it do not scale the kubernetes node so you must ensure enough working nodes for the number you has sepecified.

+ tear_down: remove the deployed clients from kubernetes

### Node affinities and taints

Prove client make heavy computational works and each of its instance should be run exclusively on a single host (node) with enough computing ability (64 cores or more, huge RAM). Commonly you have to configure these resources in advance so they can be used by the prove cluster.

To specializate and isolate a group of nodes in kubernetes you need to tag (so some workload can be assigned to run on them) and taint (other workload would not run on them) them. Our deployment require following confgiurations:

+ client pod prone to be run on node which is tagged as `fluidexnode/computation` (affinity)

+ client pod can tolerate taint excatly being `dedicated/compuation` (taint the node with this tag so other workload would not be running on it)

+ client pod is excluding any node has another client running on (anti-affinity), so we need node as more as the number of running clients

