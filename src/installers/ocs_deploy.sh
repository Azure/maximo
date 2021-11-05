#!/bin/bash

echo "================ OCS DEPLOY START ================"

oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/ocs/ocs-operator.yaml
oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/ocs/ocs-create-cluster.yaml

#check Cluster
while [ true ]
do
    status=$(oc get StorageCluster ocs-storagecluster -n openshift-storage --output='json' | jq -r .status.phase)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

echo "================ OCS DEPLOY COMPLETE ================"