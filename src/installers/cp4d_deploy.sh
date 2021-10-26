#!/bin/bash

wget -nv https://github.com/IBM/cpd-cli/releases/download/v3.5.6/cpd-cli-linux-EE-3.5.6.tgz -O cpd-cli-linux-EE-3.5.6.tgz
tar -xvzf cpd-cli-linux-EE-3.5.6.tgz

echo "Setup CP4D Project"
#Setup CP4D
oc new-project cp4d
ENTITLEMENT_KEY="$ENTITLEMENT_KEY"
oc -n cp4d create secret docker-registry ibm-registry --docker-server=cp.icr.io --docker-username=cp  --docker-password=$ENTITLEMENT_KEY

echo "Install CP4D"
#Install CP4D
./cpd-cli adm --accept-all-licenses --repo ./repo.yaml --assembly lite --namespace cp4d --latest-dependency --apply
./cpd-cli install --accept-all-licenses --repo ./repo.yaml --assembly lite --namespace cp4d --storageclass ocs-storagecluster-cephfs --override-config ocs --latest-dependency

echo "Install db2wh"
#Install db2wh
./cpd-cli adm --accept-all-licenses --repo ./repo.yaml --assembly db2wh --namespace cp4d --latest-dependency --apply
./cpd-cli install --accept-all-licenses --repo ./repo.yaml --assembly db2wh --namespace cp4d --storageclass ocs-storagecluster-cephfs --latest-dependency