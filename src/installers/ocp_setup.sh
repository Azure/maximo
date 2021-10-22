#!/bin/bash

 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/machinesets/db2.yaml -O /tmp/OCPInstall/db2.yaml
 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/machinesets/ocs.yaml -O /tmp/OCPInstall/ocs.yaml
 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/machinesets/worker.yaml -O /tmp/OCPInstall/worker.yaml


#Setup Zone 1
 export zone=1

#Setup DB2 MachineSet
 export numReplicas=1
 envsubst < /tmp/OCPInstall/db2.yaml > /tmp/OCPInstall/QuickCluster/db2.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/db2.yaml

#Setup OCS MachineSet
 export numReplicas=2
 envsubst < /tmp/OCPInstall/ocs.yaml > /tmp/OCPInstall/QuickCluster/ocs.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/ocs.yaml

#Setup Worker MachineSet
 export numReplicas=3
 envsubst < /tmp/OCPInstall/worker.yaml > /tmp/OCPInstall/QuickCluster/worker.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/worker.yaml
 sudo -E /tmp/OCPInstall/oc scale --replicas=0 machineset $(grep -A3 'name:' /tmp/OCPInstall/QuickCluster/worker.yaml | head -n1 | awk '{ print $2}') -n openshift-machine-api
 sudo -E /tmp/OCPInstall/oc scale --replicas=3 machineset $(grep -A3 'name:' /tmp/OCPInstall/QuickCluster/worker.yaml | head -n1 | awk '{ print $2}') -n openshift-machine-api
 

 #Setup Zone 2
 export zone=2

 #Setup DB2 MachineSet
 export numReplicas=1
 envsubst < /tmp/OCPInstall/db2.yaml > /tmp/OCPInstall/QuickCluster/db2.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/db2.yaml

 #Setup OCS MachineSet
 export numReplicas=1
 envsubst < /tmp/OCPInstall/ocs.yaml > /tmp/OCPInstall/QuickCluster/ocs.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/ocs.yaml

 #Setup Worker MachineSet
 export numReplicas=3
 envsubst < /tmp/OCPInstall/worker.yaml > /tmp/OCPInstall/QuickCluster/worker.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/worker.yaml
 sudo -E /tmp/OCPInstall/oc scale --replicas=0 machineset $(grep -A3 'name:' /tmp/OCPInstall/QuickCluster/worker.yaml | head -n1 | awk '{ print $2}') -n openshift-machine-api
 sudo -E /tmp/OCPInstall/oc scale --replicas=3 machineset $(grep -A3 'name:' /tmp/OCPInstall/QuickCluster/worker.yaml | head -n1 | awk '{ print $2}') -n openshift-machine-api
 

 #Setup Zone 3
 export zone=3
 
 #Setup Worker MachineSet
 export numReplicas=3
 envsubst < /tmp/OCPInstall/worker.yaml > /tmp/OCPInstall/QuickCluster/worker.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/worker.yaml
 sudo -E /tmp/OCPInstall/oc scale --replicas=0 machineset $(grep -A3 'name:' /tmp/OCPInstall/QuickCluster/worker.yaml | head -n1 | awk '{ print $2}') -n openshift-machine-api
 sudo -E /tmp/OCPInstall/oc scale --replicas=3 machineset $(grep -A3 'name:' /tmp/OCPInstall/QuickCluster/worker.yaml | head -n1 | awk '{ print $2}') -n openshift-machine-api

 #Configure Azure Files
 sudo -E /tmp/OCPInstall/oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/storageclasses/azurefiles.yaml
 sudo -E /tmp/OCPInstall/oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/storageclasses/persistent-volume-binder.yaml