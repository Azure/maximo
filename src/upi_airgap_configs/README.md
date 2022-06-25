# Setting up an Openshift cluster with no internet access

## Prereqs

### Network
The openshift cluster requires the following for UPI install to succeed:
- Allow outbound for service tag: `AzureResourceManager`
- Allow outbound for service tag: `AzureActiveDirectory`

If you allow service connectivity to Azure Storage without private endpoints then you can skip the steps for creating the private endpoints for the storage account. If you wish to allow outbound connectivity to storage accounts public interface, you can allow outbound access to: `Storage.Region` or `Storage`.

### Setup Mirror

You will need to mirror the openshift release and the catalogs (catalogs can be done after deployment) to an Azure Container Registry. This registry should have a private endpoint and dns zone link into the VNet where the cluster will be deployed.

#### Release Mirror
```bash
export OCP_RELEASE=4.8.42
export LOCAL_REGISTRY='<registry>.azurecr.io:443'
export LOCAL_REPOSITORY='ocp4/openshift48'
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON='/home/user/pullsecret.json' #openshift pull secret + add azure container registry pull secret wihtout port.
export RELEASE_NAME="ocp-release"
export ARCHITECTURE=x86_64

oc adm release mirror -a ${LOCAL_SECRET_JSON} --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}
```
After this step completes, it will provide you with the imageContentSources details to insert / update inside of your `install-config.yaml` file.

#### Catalog Mirror
This step takes 10 hours so its best to run this in a tmux session using a bash script:
```bash
#!/bin/bash

export OCP_RELEASE=4.8
export LOCAL_REGISTRY='<registry>.azurecr.io:443'
export LOCAL_SECRET_JSON='/home/user/pullsecret.json'

export LOCAL_REPOSITORY='ocp48/redhat-operators'
export SOURCE_CATALOG='registry.redhat.io/redhat/redhat-operator-index:v'${OCP_RELEASE}
oc adm catalog mirror $SOURCE_CATALOG ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} -a ${LOCAL_SECRET_JSON}

export LOCAL_REPOSITORY='ocp48/certified-operators'
export SOURCE_CATALOG='registry.redhat.io/redhat/certified-operator-index:v'${OCP_RELEASE}
oc adm catalog mirror $SOURCE_CATALOG ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} -a ${LOCAL_SECRET_JSON}

export LOCAL_REPOSITORY='ocp48/redhat-marketplace'
export SOURCE_CATALOG='registry.redhat.io/redhat/redhat-marketplace-index:v'${OCP_RELEASE}
oc adm catalog mirror $SOURCE_CATALOG ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} -a ${LOCAL_SECRET_JSON}

export LOCAL_REPOSITORY='ocp48/community-operators'
export SOURCE_CATALOG='registry.redhat.io/redhat/community-operator-index:v'${OCP_RELEASE}
oc adm catalog mirror $SOURCE_CATALOG ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} -a ${LOCAL_SECRET_JSON}

```

After the cluster is deployed, you will need to setup catalog policies to use this mirror.

### ARM Templates
This directory, contains the arm templates required for the steps below. You can download them to your jumpbox to do the install.

## Deploy Cluster

```bash
# Copy install-config.yaml file into directory. ENSURE that the pull secret contains your mirror credentials. This version will require the port :443 in the key name otherwise it will error during the deployment. The auth value is the base64 version of user:password from the Azure Container Registry
./openshift-install create install-config

# Manually update Compute Replicas to 0

export CLUSTER_NAME=`yq .metadata.name install-config.yaml`
export AZURE_REGION=`yq .platform.azure.region install-config.yaml`
export BASE_DOMAIN=`yq .baseDomain install-config.yaml`
export BASE_DOMAIN_RESOURCE_GROUP=`yq .platform.azure.baseDomainResourceGroupName install-config.yaml`

./openshift-install create manifests

rm -f openshift/99_openshift-cluster-api_master-machines-*.yaml
rm -f openshift/99_openshift-cluster-api_worker-machineset-*.yaml

nano manifests/cluster-scheduler-02-config.yml
nano manifests/cluster-dns-02-config.yml

# If you do not want to use the resource name from th yaml file below, you can can override these variables with your own
export INFRA_ID=`yq '.status.infrastructureName' manifests/cluster-infrastructure-02-config.yml`
export RESOURCE_GROUP=`yq '.status.platformStatus.azure.resourceGroupName' manifests/cluster-infrastructure-02-config.yml`

# Install pip3 dotmap
# Pull down setup-manifests.py and update the variables inside the file to match your deployment.
python3 setup-manifests.py $RESOURCE_GROUP $INFRA_ID

./openshift-install create ignition-configs

# This step can be skipped if it was done ahead of the install
# Manually grant this identity subnet reader on the Virtual Network where the cluster will be deployed and contributor on the resource group where the cluster will be deployed.
az identity create -g $RESOURCE_GROUP -n ${INFRA_ID}-identity

az storage account create -g $RESOURCE_GROUP --location $AZURE_REGION --name ${CLUSTER_NAME}sa --kind StorageV2 --sku Standard_LRS
# Manually create private endpoint to storage account

export ACCOUNT_KEY=`az storage account keys list -g $RESOURCE_GROUP --account-name ${CLUSTER_NAME}sa --query "[0].value" -o tsv`

az storage container create --name vhd --account-name ${CLUSTER_NAME}sa
export VHD_URL=$(./openshift-install coreos print-stream-json | jq -r '.architectures.x86_64."rhel-coreos-extensions"."azure-disk".url')
az storage blob copy start --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY --destination-blob "rhcos.vhd" --destination-container vhd --source-uri "$VHD_URL"

az storage container create --name files --account-name ${CLUSTER_NAME}sa
az storage blob upload --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -c "files" -f "bootstrap.ign" -n "bootstrap.ign"

az network private-dns zone create -g $RESOURCE_GROUP -n ${CLUSTER_NAME}.${BASE_DOMAIN}

# Manually create private dns link back to vnet

# Check blob upload status:
status="unknown"
while [ "$status" != "success" ]
do
  status=`az storage blob show --container-name vhd --name "rhcos.vhd" --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -o tsv --query properties.copy.status`
  echo $status
done

export VHD_BLOB_URL=`az storage blob url --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -c vhd -n "rhcos.vhd" -o tsv`

az deployment group create -g $RESOURCE_GROUP  --template-file "02_storage.json"  --parameters vhdBlobURL="$VHD_BLOB_URL"  --parameters baseName="$INFRA_ID"

az deployment group create -g $RESOURCE_GROUP  --template-file "03_infra.json"  --parameters privateDNSZoneName="${CLUSTER_NAME}.${BASE_DOMAIN}"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters controlSubnetName="control"

bootstrap_url_expiry=`date -u -d "10 hours" '+%Y-%m-%dT%H:%MZ'`
export BOOTSTRAP_URL=`az storage blob generate-sas -c 'files' -n 'bootstrap.ign' --https-only --full-uri --permissions r --expiry $bootstrap_url_expiry --account-name ${CLUSTER_NAME}sa --account-key $ACCOUNT_KEY -o tsv`
export BOOTSTRAP_IGNITION=`jq -rcnM --arg v "3.1.0" --arg url $BOOTSTRAP_URL '{ignition:{version:$v,config:{replace:{source:$url}}}}' | base64 | tr -d '\n'`

# Ensure the securityGroupName that was set with setup-manifests matches what will be created in this step: ${vnetBaseName}-nsg. This is a dummy NSG so the ingress operator does not error.

# Make sure the identity name matches what was deployed (or created ahead of the deployment)
az deployment group create -g $RESOURCE_GROUP  --template-file "04_bootstrap.json"  --parameters bootstrapIgnition="$BOOTSTRAP_IGNITION"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters controlSubnetName="control" --parameters identityName="devcluster-bwjl4-identity"

export MASTER_IGNITION=`cat master.ign | base64 | tr -d '\n'`

# Make sure the identity name matches what was deployed (or created ahead of the deployment)
az deployment group create -g $RESOURCE_GROUP  --template-file "05_masters.json"  --parameters masterIgnition="$MASTER_IGNITION"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters controlSubnetName="control" --parameters identityName="devcluster-bwjl4-identity"

export WORKER_IGNITION=`cat worker.ign | base64 | tr -d '\n'`

# Make sure the identity name matches what was deployed (or created ahead of the deployment)
az deployment group create -g $RESOURCE_GROUP --template-file "06_workers.json"  --parameters workerIgnition="$WORKER_IGNITION"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters computeSubnetName="workers" --parameters identityName="devcluster-bwjl4-identity"

# Get the cert signing requests
oc get csr -A

# Approve the csrs
oc adm certificate approve csr-8bppf csr-dj2w4 csr-ph8s8 #replace with correct csr #s

export PRIVATE_IP_ROUTER=`oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}'`

az network private-dns record-set a create -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n *.apps --ttl 300

az network private-dns record-set a add-record -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n *.apps -a $PRIVATE_IP_ROUTER

./openshift-install wait-for install-complete --log-level debug

# Wait for cluster to finish upgrading
```