#!/bin/bash

 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/machinesets/db2.yaml -O /tmp/OCPInstall/db2.yaml
 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/machinesets/ocs.yaml -O /tmp/OCPInstall/ocs.yaml


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

 #Configure Azure Files
 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/storageclasses/azurefiles-standard.yaml -O /tmp/OCPInstall/azurefiles-standard.yaml
 envsubst < /tmp/OCPInstall/azurefiles-standard.yaml > /tmp/OCPInstall/QuickCluster/azurefiles-standard.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/azurefiles-standard.yaml

 wget -nv https://raw.githubusercontent.com/Azure/maximo/4.6/src/storageclasses/azurefiles-premium.yaml -O /tmp/OCPInstall/azurefiles-premium.yaml
 envsubst < /tmp/OCPInstall/azurefiles-premium.yaml > /tmp/OCPInstall/QuickCluster/azurefiles-premium.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/azurefiles-premium.yaml

 sudo -E /tmp/OCPInstall/oc apply -f https://raw.githubusercontent.com/Azure/maximo/4.6/src/storageclasses/persistent-volume-binder.yaml

 echo "================ OCP DEPLOY COMPLETE ================"