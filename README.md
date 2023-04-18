# arkcase/base
Base Image for ArkCase Docker Images

When we are ready to switch to RHEL, this image will be replaced with registry.access.redhat.com/ubi8/s2i-core:latest

## How to build:

docker build -t public.ecr.aws/arkcase/base:latest .

docker push public.ecr.aws/arkcase/base:latest
 
## How to run: (Docker)

docker run --name arkcase\_base -d public.ecr.aws/arkcase/base:latest sleep infinity

docker exec -it arkcase\_base /bin/bash

docker stop arkcase\_base

docker rm arkcase\_base

## How to run: (Kubernetes) 

kubectl create -f pod-arkcase-base.yaml

kubectl exec -it arkcase-base -- bash

kubectl delete -f pod-arkcase-base.yaml
