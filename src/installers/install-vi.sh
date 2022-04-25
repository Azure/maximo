#!/bin/bash

echo "================ VI DEPLOY START ================"

#USERNAME="admin"
#PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
#ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

# Set up Node Feature Discovery (nfd)
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/nfd/nfd-namespace.yaml

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/nfd/nfd-operatorgroup.yaml

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/nfd/nfd-sub.yaml


# NOTE: Cluster-wide entitement required for certain version of Openshift: See here:
# 

# Set up NVIDIA GPU Operator
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/vi/nvop-namespace.yaml

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/vi/nvop.yaml

CHANNEL=$(oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')

CSV=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')

wget https://raw.githubusercontent.com/Azure/maximo/main/src/vi/nvop-sub.yaml

sed -i "s/{CHANNEL}/$CHANNEL/" nvop-sub.yaml

sed -i "s/{CSV}/$CSV/" nvop-sub.yaml

oc apply -f nvop-sub.yaml

INSTALL_PLAN=$(oc get installplan -n nvidia-gpu-operator -oname)

oc patch $INSTALL_PLAN -n nvidia-gpu-operator --type merge --patch '{"spec":{"approved":true }}'

oc get csv -n nvidia-gpu-operator $CSV -ojsonpath={.metadata.annotations.alm-examples} | jq .[0] > clusterpolicy.json

oc apply -f clusterpolicy.json

# TODO: VI Install Steps