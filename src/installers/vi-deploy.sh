#!/bin/bash

echo "================ VI DEPLOY START ================"

#USERNAME="admin"
#PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)
#ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
#CLUSTER_URL="apps.newcluster.maximoonazure.com"

#Setup VI Tesla MachineSet
wget -nv https://raw.githubusercontent.com/haavape/maximo/$branchName/src/machinesets/worker-vi-tesla.yaml -O /tmp/OCPInstall/worker-vi-tesla.yaml

#Setup Zone 1
export zone=1
#Setup Number of Machines per Zone
export numReplicas=1
envsubst < /tmp/OCPInstall/worker-vi-tesla.yaml > /tmp/OCPInstall/QuickCluster/worker-vi-tesla.yaml
sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/worker-vi-tesla.yaml

# Set up Node Feature Discovery (nfd)
sudo -E /tmp/OCPInstall/oc apply -f https://raw.githubusercontent.com/haavape/maximo/$branchName/src/nfd/nfd-operator.yaml

# Set up NVIDIA GPU Operator
# We've set the current known working version and channel service version of the operator, but if you want to have the script pull the most recent version, you can uncomment these lines
# nvidiaOperatorChannel=$(oc get packagemanifest gpu-operator-certified -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')
# nvidiaOperatorCSV=$(oc get packagemanifests/gpu-operator-certified -n openshift-marketplace -ojson | jq -r '.status.channels[] | select(.name == "'$CHANNEL'") | .currentCSV')

wget -nv -qO- https://raw.githubusercontent.com/haavape/maximo/$branchName/src/vi/nv-operator.yaml | envsubst | sudo -E /tmp/OCPInstall/oc apply -f -

#wait for operator to be created

echo "Waiting for NVidia Operators to come online"

#check NVidia Operator
while [ true ]
do
    status=$(oc get Operator gpu-operator-certified.nvidia-gpu-operator -n nvidia-gpu-operator -o json | jq -r '.status[].refs[] | select(.kind=="ClusterServiceVersion").conditions[].type')
    if [ ! "$status" == "Succeeded" ]
    then
        sleep 2
    else
        break
     fi
done

sudo -E /tmp/OCPInstall/oc get csv -n nvidia-gpu-operator $nvidiaOperatorCSV -ojsonpath={.metadata.annotations.alm-examples} | jq .[0] > /tmp/OCPInstall/clusterpolicy.json

sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/clusterpolicy.json

# TODO: VI Install Steps