#!/bin/bash

echo "================ VI DEPLOY START ================"

#USERNAME="admin"
#PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
#ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

# Set up Node Feature Discovery (nfd)
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/nfd/nfd-operator.yaml

# NOTE: Cluster-wide entitement required for certain version of Openshift: See here:
# 

# Set up NVIDIA GPU Operator
wget https://raw.githubusercontent.com/Azure/maximo/main/src/vi/nv-operator.yaml

CHANNEL=$(oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')

CSV=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')

wget https://raw.githubusercontent.com/Azure/maximo/main/src/vi/nv-operator.yaml

sed -i "s/{CHANNEL}/$CHANNEL/" nv-operator.yaml

sed -i "s/{CSV}/$CSV/" nv-operator.yaml

oc apply -f nv-operator.yaml

oc get csv -n nvidia-gpu-operator $CSV -ojsonpath={.metadata.annotations.alm-examples} | jq .[0] > clusterpolicy.json

oc apply -f clusterpolicy.json

# TODO: VI Install Steps