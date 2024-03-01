#!/bin/sh

pushd ..

printf "\nInstall Keycloak ...\n"
# Create Keycloak namespace if it does not yet exist
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -
kubectl -n keycloak apply -f keycloak/keycloak.yaml


printf "\nWait for Keycloak readiness ...\n"
kubectl -n keycloak rollout status deploy/keycloak

printf "\Deploy HTTPBin service ...\n"
kubectl apply -f apis/httpbin.yaml

printf "\Deploy OAuth AuthConfig ...\n"
kubectl apply -f policies/extauth/auth-config-oauth.yaml

printf "\Deploy VirtualServices ...\n"
kubectl apply -f virtualservices/api-example-com-vs.yaml
kubectl apply -f virtualservices/keycloak-example-com-vs.yaml

popd