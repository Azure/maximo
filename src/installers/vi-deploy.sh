#!/bin/bash

echo "================ VI DEPLOY START ================"

#USERNAME="admin"
#PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
#ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

#Setup VI Tesla MachineSet
wget -nv https://raw.githubusercontent.com/Azure/maximo/$branchName/src/machinesets/worker-vi-tesla.yaml -O /tmp/OCPInstall/worker-vi-tesla.yaml

#Setup Zone 1
export zone=1
#Setup Number of Machines per Zone
export numReplicas=2
envsubst < /tmp/OCPInstall/worker-vi-tesla.yaml > /tmp/OCPInstall/QuickCluster/worker-vi-tesla.yaml
sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/worker-vi-tesla.yaml

# Set up Node Feature Discovery (nfd)
oc apply -f https://raw.githubusercontent.com/Azure/maximo/$branchName/src/nfd/nfd-operator.yaml

# NOTE: Cluster-wide entitement required for certain version of Openshift: See here:
# 

# Set up NVIDIA GPU Operator
wget https://raw.githubusercontent.com/Azure/maximo/$branchName/src/vi/nv-operator.yaml

#We've set the current known working version and channel service version of the operator, but if you want to have the script pull the most recent version, you can uncomment these lines
#nvidiaOperatorChannel=$(oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')
#nvidiaOperatorCSV=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')

sed -i "s/{CHANNEL}/$nvidiaOperatorChannel/" nv-operator.yaml

sed -i "s/{CSV}/$nvidiaOperatorCSV/" nv-operator.yaml

oc apply -f nv-operator.yaml

oc get csv -n nvidia-gpu-operator $nvidiaOperatorCSV -ojsonpath={.metadata.annotations.alm-examples} | jq .[0] > clusterpolicy.json

oc apply -f clusterpolicy.json

# TODO: VI Install Steps