#!/bin/bash

echo "================ OCS DEPLOY START ================"

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/ocs/ocs-operator.yaml

#check API Kind is avaliable
while [ true ]
do
    status=$(oc get StorageCluster -A -o json 2>&1 >/dev/null | grep error)
    if [ ! -z "$status" ]
    then
        sleep 2
    else
        break
     fi
done

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/ocs/ocs-create-cluster.yaml

#check Cluster
while [ true ]
do
    status=$(oc get StorageCluster ocs-storagecluster -n openshift-storage --output='json' 2>/dev/null | jq -r .status.phase)
    if [ ! "$status" == "Ready" ]
    then
        sleep 2
    else
        break
     fi
done

echo "================ OCS DEPLOY COMPLETE ================"