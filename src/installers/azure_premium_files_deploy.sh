#!/bin/bash

export tenantId=$(cat ~/.azure/osServicePrincipal.json | jq -r .tenantId)
export subscriptionId=$(cat ~/.azure/osServicePrincipal.json | jq -r .subscriptionId)
export clientId=$(cat ~/.azure/osServicePrincipal.json | jq -r .clientId)
export clientSecret=$(cat ~/.azure/osServicePrincipal.json | jq -r .clientSecret)

\cp /tmp/OCPInstall/kubectl /usr/bin #overwrite existing version

#Create the azure.json file and upload as secret
wget -nv https://raw.githubusercontent.com/Azure/maximo/main/src/storageclasses/azure.json -O /tmp/OCPInstall/azure.json
envsubst < /tmp/OCPInstall/azure.json > /tmp/OCPInstall/QuickCluster/azure.json
sudo -E /tmp/OCPInstall/oc create secret generic azure-cloud-provider --from-literal=cloud-config=$(cat /tmp/OCPInstall/QuickCluster/azure.json | base64 | awk '{printf $0}'; echo) -n kube-system

#Grant access
sudo -E /tmp/OCPInstall/oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:csi-azurefile-node-sa

#Install CSI Driver
sudo -E /tmp/OCPInstall/oc create configmap azure-cred-file --from-literal=path="/etc/kubernetes/cloud.conf" -n kube-system

driver_version=master
echo "Driver version " $driver_version
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/$driver_version/deploy/install-driver.sh | bash -s $driver_version --

#Deploy premium Storage Class
 wget -nv https://raw.githubusercontent.com/Azure/maximo/main/src/storageclasses/azurefiles-premium.yaml -O /tmp/OCPInstall/azurefiles-premium.yaml
 envsubst < /tmp/OCPInstall/azurefiles-premium.yaml > /tmp/OCPInstall/QuickCluster/azurefiles-premium.yaml
 sudo -E /tmp/OCPInstall/oc apply -f /tmp/OCPInstall/QuickCluster/azurefiles-premium.yaml