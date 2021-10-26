#!/bin/bash

echo "Deploy Openshift Container Storage"
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/ocs/ocs-operator.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/ocs/ocs-create-cluster.yaml