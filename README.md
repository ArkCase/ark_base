# ark_base
Base Image for ArkCase Docker Images

When we are ready to switch to RHEL, this image will be replaced with registry.access.redhat.com/ubi8/s2i-core:latest

## How to build:

docker build -t 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest .

docker push 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest
 
## How to run: (Docker)

docker run --name ark_base -d 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest sleep infinity

docker exec -it ark_base /bin/bash

docker stop ark_base

docker rm ark_base

## How to run: (Kubernetes) 

kubectl create -f pod_ark_base.yaml

kubectl exec -it pod/base -- bash

kubectl delete -f pod_ark_base.yaml

