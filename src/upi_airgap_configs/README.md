# Setting up an Openshift cluster with no internet access (Airgap)

## Introduction

The steps below will walk through the UPI (User Provisioned Infrastructure) method of deploying an Openshift Cluster on Azure into a virtual network with no outbound internet access (Airgapped Cluster). It includes an Azure Container Registry and steps to mirror the Openshift images into the registry from a JumpBox with internet connectivity. Your clusters network will need outbound access to Azure AD and ARM for authentication and resource management.

## Prereqs

### Network
The openshift cluster requires the following for UPI install to succeed:
- Allow outbound for service tag: `AzureResourceManager`
- Allow outbound for service tag: `AzureActiveDirectory`

To verify connectivity, you can run the following commands from inside your restricted network and confirm you get a response back:

```bash
curl -i https://management.azure.com #Should get a response code 400
curl -i https://login.microsoftonline.com/common/oauth2/v2.0/authorize #Should get a response code 200
```

If you allow service connectivity to Azure Storage without private endpoints then you can skip the steps for creating the private endpoints for the storage account. If you wish to allow outbound connectivity to storage accounts public interface, you can allow outbound access to: `Storage.Region` or `Storage`.

### Setup Mirror

You will need to mirror the openshift release and the catalogs (catalogs can be done after deployment) to an Azure Container Registry. This registry should have a private endpoint and dns zone link into the VNet where the cluster will be deployed.

#### Release Mirror
```bash
export OCP_RELEASE=4.8.42
export LOCAL_REGISTRY='<registry>.azurecr.io:443'
export LOCAL_REPOSITORY='ocp4/openshift48'
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON='/home/user/pullsecret.json' #openshift pull secret + add azure container registry pull secret without port.
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
export LOCAL_SECRET_JSON='/home/user/pullsecret.json' #openshift pull secret + add azure container registry pull secret without port.

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

Once this process completes, 4 directories will be created:
- manifests-certified-operator-index-xxxxxx
- manifests-community-operator-index-xxxxxx
- manifests-redhat-marketplace-index-xxxxxx
- manifests-redhat-operator-index-xxxxxx

Inside each of these directories you will find 2 files that will need to be deployed to the cluster:
- imageContentSourcePolicy.yaml
- catalogSource.yaml

These will be deployed as a final step after cluster creation.

### ARM Templates
This directory, contains the arm templates required for the steps below:

- [Storage](./02_storage.json) - Deploys the RHOCP VM Image.
- [Infra](./03_infra.json) - Deploys an internal load balancer and private DNS Zone records.
- [Bootstrap](./04_bootstrap.json) - Deploys a temporary machine to kick start the cluster.
- [Master Nodes](./05_masters.json) - Deploys the Openshift control nodes.
- [Worker Nodes](./06_workers.json) - Deploys the Openshift compute nodes.
- [Setup Manifests](./setup-manifests.py) - Modifies manifest files created by by openshift installer. You will need to edit this file with your network settings.

> 🚧 **NOTE**: The NSG inside of the Setup Manifests file: `config.securityGroupName` is used by the Openshift cluster to manage ACLs. This NSG should exist in the cluster resource group but does not need to be applied to any subnets on your existing VNet. You may use your own NSGs. If you delete this NSG, the cluster will create a warning on the ingress controller that it cannot find the NSG. The NSG must be named: ${INFRA_ID}-nsg.

Please download these files to your jumpbox to deploy the infrastructure.

## Deploy Cluster

### Step 1
Copy [Install Config](./install-config.yaml) file into the directory you will initialize the cluster from.

  > 🚧 **WARNING** The pull secret in this file must contain your mirror credentials. This configuration needs to include the port :443 in the key name otherwise it will error during the deployment. Example: myacr.azurecr.io:443. The auth value is the base64 version of user:password from the Azure Container Registry.

### Step 2
Copy the `openshift-install` binary into the install directory and initialize the config:

  ```bash
  ./openshift-install create install-config
  ```

Edit the `install-config.yaml` file and update Compute Replicas to 0.

### Step 3
Export the environment variables necessary for the deployment:
```bash
export CLUSTER_NAME=`yq -r .metadata.name install-config.yaml`
export AZURE_REGION=`yq -r .platform.azure.region install-config.yaml`
export BASE_DOMAIN=`yq -r .baseDomain install-config.yaml`
export BASE_DOMAIN_RESOURCE_GROUP=`yq -r .platform.azure.baseDomainResourceGroupName install-config.yaml`
```

### Step 4
Prepare the manifests for the cluster:
```bash
./openshift-install create manifests

rm -f openshift/99_openshift-cluster-api_master-machines-*.yaml
rm -f openshift/99_openshift-cluster-api_worker-machineset-*.yaml
```

Make these manual changes:
- manifests/cluster-scheduler-02-config.yml
  - Set master scheduling key to false
- manifests/cluster-dns-02-config.yml
  - Delete private dns zone object

### Step 5
Export variables to name the cluster and the resource group the cluster will be deployed into:
```bash
export INFRA_ID=`yq -r '.status.infrastructureName' manifests/cluster-infrastructure-02-config.yml`
export RESOURCE_GROUP=`yq -r '.status.platformStatus.azure.resourceGroupName' manifests/cluster-infrastructure-02-config.yml`
```

If you do not want to use the resource name from the yaml file below, you can can override these variables with your own value.

### Step 6
Modify the `setup-manifests.py` to match your network configuration in Azure.

Install dotmap for python3 using pip3: `pip3 install dotmap`

Run the following command to update your manifest files:
```bash
python3 setup-manifests.py $RESOURCE_GROUP $INFRA_ID
```

### Step 7
Create the ignition configs for the deployment:
```bash
./openshift-install create ignition-configs
```

### Step 8
Create a managed identity that will be used by the cluster to manage resources in the clusters resource group. The identity will need `Contributor` access on the cluster's resource group and it will need a role that has `subnet reader` access on the virtual network that the cluster is getting deployed into.

```bash
az identity create -g $RESOURCE_GROUP -n ${INFRA_ID}-identity

export managedIdentity=$(az resource list --resource-group $RESOURCE_GROUP --resource-type "Microsoft.ManagedIdentity/userAssignedIdentities" --query "[].{name:name}" --out tsv)
```

### Step 9
Create a unique name for the storage account that will be used to start the bootstrap VM and provide SMB file share access for the clusters PVCs. 

```bash
export STORAGE_ACCOUNT_NAME="myuniquenamexyz"
```

### Step 10 
Create the storage account:
```bash
az storage account create -g $RESOURCE_GROUP --location $AZURE_REGION --name ${STORAGE_ACCOUNT_NAME} --kind StorageV2 --sku Standard_ZRS
```

### Step 11

Create a private endpoint to storage account with access to blob and file. Also verify the private DNS Zone for the storage accounts private endpoint has a link to the the VNet where the cluster is deployed.

### Step 12
Fetch the storage account key and upload the base image and ignition file for the bootstrap VM:
```bash
export ACCOUNT_KEY=`az storage account keys list -g $RESOURCE_GROUP --account-name ${STORAGE_ACCOUNT_NAME} --query "[0].value" -o tsv`

az storage container create --name vhd --account-name ${STORAGE_ACCOUNT_NAME}

export VHD_URL=$(./openshift-install coreos print-stream-json | jq -r '.architectures.x86_64."rhel-coreos-extensions"."azure-disk".url')

az storage blob copy start --account-name ${STORAGE_ACCOUNT_NAME} --account-key $ACCOUNT_KEY --destination-blob "rhcos.vhd" --destination-container vhd --source-uri "$VHD_URL"

# Upload ignition file
az storage container create --name files --account-name ${STORAGE_ACCOUNT_NAME}
az storage blob upload --account-name ${STORAGE_ACCOUNT_NAME} --account-key $ACCOUNT_KEY -c "files" -f "bootstrap.ign" -n "bootstrap.ign"
```

### Step 13
Create a private DNS Zone for the cluster:

```bash
az network private-dns zone create -g $RESOURCE_GROUP -n ${CLUSTER_NAME}.${BASE_DOMAIN}
```

Create private dns link back to vnet the cluster will be deployed into.

### Step 14

Wait for the base image for the cluster to be upload to blob storage:
```bash
status="unknown"
while [ "$status" != "success" ]
do
  status=`az storage blob show --container-name vhd --name "rhcos.vhd" --account-name ${STORAGE_ACCOUNT_NAME} --account-key $ACCOUNT_KEY -o tsv --query properties.copy.status`
  echo $status
done
```

### Step 15

Create a custom image resource:

```bash
export VHD_BLOB_URL=`az storage blob url --account-name ${STORAGE_ACCOUNT_NAME} --account-key $ACCOUNT_KEY -c vhd -n "rhcos.vhd" -o tsv`

az deployment group create -g $RESOURCE_GROUP  --template-file "02_storage.json"  --parameters vhdBlobURL="$VHD_BLOB_URL"  --parameters baseName="$INFRA_ID"
```

### Step 16

Deploy the load balancer and private DNS records:

```bash
az deployment group create -g $RESOURCE_GROUP  --template-file "03_infra.json"  --parameters privateDNSZoneName="${CLUSTER_NAME}.${BASE_DOMAIN}"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters controlSubnetName="control"
```

### Step 17

Create the bootstrap VM:

```bash
bootstrap_url_expiry=`date -u -d "10 hours" '+%Y-%m-%dT%H:%MZ'`

export BOOTSTRAP_URL=`az storage blob generate-sas -c 'files' -n 'bootstrap.ign' --https-only --full-uri --permissions r --expiry $bootstrap_url_expiry --account-name ${STORAGE_ACCOUNT_NAME} --account-key $ACCOUNT_KEY -o tsv`

export BOOTSTRAP_IGNITION=`jq -rcnM --arg v "3.1.0" --arg url $BOOTSTRAP_URL '{ignition:{version:$v,config:{replace:{source:$url}}}}' | base64 | tr -d '\n'`
```

> 🚧 **NOTE**: Ensure the securityGroupName that was set with setup-manifests matches what will be created in this step: ${vnetBaseName}-nsg. This is a dummy NSG so the ingress operator does not error.

Update the parameters in the cli command below and deploy the bootstrap VM:
```bash
az deployment group create -g $RESOURCE_GROUP  --template-file "04_bootstrap.json"  --parameters bootstrapIgnition="$BOOTSTRAP_IGNITION"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters controlSubnetName="control" --parameters identityName=$managedIdentity
```

### Step 18

Update the parameters in the cli command below and deploy the master VMs:

```bash
export MASTER_IGNITION=`cat master.ign | base64 | tr -d '\n'`

# Make sure the identity name matches what was deployed (or created ahead of the deployment)
az deployment group create -g $RESOURCE_GROUP  --template-file "05_masters.json"  --parameters masterIgnition="$MASTER_IGNITION"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters controlSubnetName="control" --parameters identityName=$managedIdentity
```

### Step 19
Wait for bootstrap process to complete

```bash
./openshift-install wait-for bootstrap-complete --log-level debug
```

After bootstrap completes, you can delete the bootstrap resources:
```bash
az network nsg rule delete -g $RESOURCE_GROUP --nsg-name ${INFRA_ID}-nsg --name bootstrap_ssh_in
az vm stop -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap
az vm deallocate -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap
az vm delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap --yes
az disk delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap_OSDisk --no-wait --yes
az network nic delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap-nic --no-wait
az storage blob delete --account-key $ACCOUNT_KEY --account-name ${STORAGE_ACCOUNT_NAME} --container-name files --name bootstrap.ign
az network public-ip delete -g $RESOURCE_GROUP --name ${INFRA_ID}-bootstrap-ssh-pip
```

### Step 20
Confirm you can login to the cluster:

```bash
export KUBECONFIG="$PWD/auth/kubeconfig"
oc get nodes
oc get clusteroperator
```

### Step 21

Update the parameters in the cli command below and deploy the master VMs:

```bash
export WORKER_IGNITION=`cat worker.ign | base64 | tr -d '\n'`

# Make sure the identity name matches what was deployed (or created ahead of the deployment)
az deployment group create -g $RESOURCE_GROUP --template-file "06_workers.json"  --parameters workerIgnition="$WORKER_IGNITION"  --parameters baseName="$INFRA_ID" --parameters vnetBaseName="airgap-vnet" --parameters vnetBaseResourceGroupName="airgap-maximo" --parameters computeSubnetName="workers" --parameters identityName=$managedIdentity
```

### Step 22

Get the cert signing requests:
```bash
oc get csr -A
```
Approve the csrs
```bash
oc get csr -A | grep Pending | grep csr | awk '{print $1}' | xargs oc adm certificate approve
```

Repeat this step twice to fully approve the CSRs.

### Step 23

Setup the dns records to allow apps to be routable to the cluster:

Wait for private IP to be provisioned by the load balancer for the ingress operator:
```bash
oc -n openshift-ingress get service router-default --no-headers
```

> 🚧 **NOTE**: If the private IP is stuck on `Pending` then you can check the events for the namespace using the command: `oc get events -n openshift-ingress`. After issues are resolved, you can trigger recreation of the route with the following command: `oc delete service router-default -n openshift-ingress`.

Configure the DNS Zone:
```bash
export PRIVATE_IP_ROUTER=`oc -n openshift-ingress get service router-default --no-headers | awk '{print $4}'`

az network private-dns record-set a create -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n *.apps --ttl 300

az network private-dns record-set a add-record -g $RESOURCE_GROUP -z ${CLUSTER_NAME}.${BASE_DOMAIN} -n *.apps -a $PRIVATE_IP_ROUTER
```

### Step 24

Watch the cluster resource group for 2 `imageregistryxxx` storage accounts to be created and add private endpoints for `blob` access (reusing the same dns zone for blob storage) into the virtual network for the operator to fully complete.

### Step 25
Wait for the cluster to finish upgrading:

```bash
./openshift-install wait-for install-complete --log-level debug
```

### Step 26

Navigate to the directory where the catalog mirror manifests were created and deploy the catalog sources:

```bash
# certified Operators
oc create -f ./manifests-certified-operator-index-xxxx/imageContentSourcePolicy.yaml

oc create -f ./manifests-certified-operator-index-xxxx/catalogSource.yaml

# Community Operators
oc create -f ./manifests-community-operator-index-xxxx/imageContentSourcePolicy.yaml

oc create -f ./manifests-community-operator-index-xxxx/catalogSource.yaml

# Redhat Marketplace Operators
oc create -f ./manifests-redhat-marketplace-index-xxxx/imageContentSourcePolicy.yaml

oc create -f ./manifests-redhat-marketplace-index-xxxx/catalogSource.yaml

# Redhat Operators
oc create -f ./manifests-redhat-operator-index-xxxx/imageContentSourcePolicy.yaml

oc create -f ./manifests-redhat-operator-index-xxxx/catalogSource.yaml
```

### Step 27

Create a premium storage account:
```bash
export PREMIUM_STORAGE_ACCOUNT_NAME="mypremiumstorageaccountname"

az storage account create -g $RESOURCE_GROUP --location $AZURE_REGION --name ${PREMIUM_STORAGE_ACCOUNT_NAME} --kind FileStorage --sku Premium_ZRS --enable-large-file-share --https-only false
```

Create a private endpoint to storage account with access to file. Also verify the private DNS Zone for the storage accounts private endpoint has a link to the the VNet where the cluster is deployed.

### Step 28

To install Azure Files CSI drivers v1.12.0, you must use a special fork that supports digest references for the deployment. Alternatively, you may create a registry.conf file for the mirroring and disable `mirror-by-digest-only`. This file will need to be base64'd and put into a `MachineConfig` yaml and pushed to the cluster.

#### Mirror the public images to your repo
```bash
export LOCAL_REGISTRY='<registry>.azurecr.io:443'

skopeo login ${LOCAL_REGISTRY}

skopeo copy --all docker://mcr.microsoft.com/oss/kubernetes-csi/csi-provisioner@sha256:542c9258a1441e4927883ea73425e21f9a14043a649686bf6b51700f34c64f8e docker://${LOCAL_REGISTRY}/kubernetes-csi/csi-provisioner@sha256:542c9258a1441e4927883ea73425e21f9a14043a649686bf6b51700f34c64f8e
skopeo copy --all docker://mcr.microsoft.com/oss/kubernetes-csi/csi-attacher@sha256:19fbca01394f7ed80151731180cfde0a3367f038beae2a97cda7928034010057 docker://${LOCAL_REGISTRY}/kubernetes-csi/csi-attacher@sha256:19fbca01394f7ed80151731180cfde0a3367f038beae2a97cda7928034010057
skopeo copy --all docker://mcr.microsoft.com/oss/kubernetes-csi/csi-snapshotter@sha256:a889e925e15f9423f7842f1b769f64cbcf6a20b6956122836fc835cf22d9073f docker://${LOCAL_REGISTRY}/kubernetes-csi/csi-snapshotter@sha256:a889e925e15f9423f7842f1b769f64cbcf6a20b6956122836fc835cf22d9073f
skopeo copy --all docker://mcr.microsoft.com/oss/kubernetes-csi/csi-resizer@sha256:ab6c2e18a4d943f2bf8688e1779622277a1d14c355c9d4bfc0d761d86c5108b3 docker://${LOCAL_REGISTRY}/kubernetes-csi/csi-resizer@sha256:ab6c2e18a4d943f2bf8688e1779622277a1d14c355c9d4bfc0d761d86c5108b3
skopeo copy --all docker://mcr.microsoft.com/oss/kubernetes-csi/livenessprobe@sha256:c96a6255c42766f6b8bb1a7cda02b0060ab1b20b2e2dafcc64ec09e7646745a6 docker://${LOCAL_REGISTRY}/kubernetes-csi/livenessprobe@sha256:c96a6255c42766f6b8bb1a7cda02b0060ab1b20b2e2dafcc64ec09e7646745a6
skopeo copy --all docker://mcr.microsoft.com/k8s/csi/azurefile-csi@sha256:e48a5045decd1b55480da9ceb8b4ee557c043c9d8c19776998c1424e6f4a5af0 docker://${LOCAL_REGISTRY}/kubernetes-csi/azurefile-csi@sha256:e48a5045decd1b55480da9ceb8b4ee557c043c9d8c19776998c1424e6f4a5af0
skopeo copy --all docker://mcr.microsoft.com/oss/kubernetes-csi/csi-node-driver-registrar@sha256:dbec3a8166686b09b242176ab5b99e993da4126438bbce68147c3fd654f35662 docker://${LOCAL_REGISTRY}/kubernetes-csi/csi-node-driver-registrar@sha256:dbec3a8166686b09b242176ab5b99e993da4126438bbce68147c3fd654f35662
```

#### Configure Image Content Source Policy

This process may take 5-10 minutes to schedule on all nodes.

```bash
oc apply -f https://raw.githubusercontent.com/haavape/maximo/main/src/upi_airgap_configs/ImageContentSourcePolicyAzureFiles.yaml
```

#### Install Azure Files within your cluster:

```bash
#Create directory for install files
mkdir /tmp/OCPInstall
mkdir /tmp/OCPInstall/QuickCluster

#Prepare openshift client for connectivity
export KUBECONFIG="$PWD/auth/kubeconfig"

#set variables for deployment
export deployRegion="eastus"
export resourceGroupName="myRG"
export tenantId="tenantId"
export subscriptionId="subscriptionId"
export clientId="clientId" #This account will be used by OCP to access azure files to create shares within Azure Storage.
export clientSecret="clientSecret"
export branchName="main"

 #create directory to store modified files
 mkdir customFiles

 #Configure Azure Files Standard
 wget -nv https://raw.githubusercontent.com/haavape/maximo/$branchName/src/storageclasses/azurefiles-standard.yaml -O ./azurefiles-standard.yaml
 envsubst < ./azurefiles-standard.yaml > ./customFiles/azurefiles-standard.yaml
 oc apply -f ./customFiles/azurefiles-standard.yaml

#Configure Azure Files Premium

#Create the azure.json file and upload as secret
wget -nv https://raw.githubusercontent.com/haavape/maximo/$branchName/src/storageclasses/azure.json -O ./azure.json
envsubst < ./azure.json > ./customFiles/azure.json
oc create secret generic azure-cloud-provider --from-literal=cloud-config=$(cat ./customFiles/azure.json | base64 | awk '{printf $0}'; echo) -n kube-system

#Grant access
oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:csi-azurefile-node-sa

#Install CSI Driver
oc create configmap azure-cred-file --from-literal=path="/etc/kubernetes/cloud.conf" -n kube-system

driver_version=v1.12.0
echo "Driver version " $driver_version
curl -skSL https://raw.githubusercontent.com/grtn316/azurefile-csi-driver/local/deploy/install-driver.sh | bash -s $driver_version --

#Deploy premium Storage Class
 wget -nv https://raw.githubusercontent.com/haavape/maximo/$branchName/src/storageclasses/azurefiles-premium.yaml -O ./azurefiles-premium.yaml
 envsubst < ./azurefiles-premium.yaml > ./customFiles/azurefiles-premium.yaml
 oc apply -f ./customFiles/azurefiles-premium.yaml

 oc apply -f https://raw.githubusercontent.com/haavape/maximo/$branchName/src/storageclasses/persistent-volume-binder.yaml
```

Once this is complete, you should see 2 new storage classes in the cluster:
```bash
oc get storageclass
```

### Installing Mongo CE

To install MongoDB:

#### Mirror the public images to your repo

```bash
export LOCAL_REGISTRY='<registry>.azurecr.io:443'

skopeo login ${LOCAL_REGISTRY}

skopeo copy docker://quay.io/mongodb/mongodb-kubernetes-operator-version-upgrade-post-start-hook@sha256:da347eb74525715a670280545e78ecee1195ec2630037b3821591c87f7a314ee docker://${LOCAL_REGISTRY}/mongodb/mongodb-kubernetes-operator-version-upgrade-post-start-hook@sha256:da347eb74525715a670280545e78ecee1195ec2630037b3821591c87f7a314ee
skopeo copy docker://quay.io/mongodb/mongodb-kubernetes-readinessprobe@sha256:bf5a4ffc8d2d257d6d9eb45d3e521f30b2e049a9b60ddc8e4865448e035502ca docker://${LOCAL_REGISTRY}/mongodb/mongodb-kubernetes-readinessprobe@sha256:bf5a4ffc8d2d257d6d9eb45d3e521f30b2e049a9b60ddc8e4865448e035502ca
skopeo copy docker://quay.io/mongodb/mongodb-agent@sha256:a6b316e6df0fee2c3d64cb065260e33586330784dcaab02cc7a3052cde3c94b9 docker://${LOCAL_REGISTRY}/mongodb/mongodb-agent@sha256:a6b316e6df0fee2c3d64cb065260e33586330784dcaab02cc7a3052cde3c94b9
skopeo copy docker://quay.io/mongodb/mongodb-kubernetes-operator@sha256:e19ae43539521f0350fb71684757dc535fc989deb75f3789cd84b782489eda80 docker://${LOCAL_REGISTRY}/mongodb/mongodb-kubernetes-operator@sha256:e19ae435
39521f0350fb71684757dc535fc989deb75f3789cd84b782489eda80
skopeo copy docker://quay.io/ibmmas/mongo@sha256:8c48baa1571469d7f5ae6d603b92b8027ada5eb39826c009cb33a13b46864908 docker://${LOCAL_REGISTRY}/mongodb/mongo@sha256:8c48baa1571469d7f5ae6d603b92b8027ada5eb39826c009cb33a13b46864908
```
#### Configure Image Content Source Policy

This process may take 5-10 minutes to schedule on all nodes.

```bash
oc apply -f https://raw.githubusercontent.com/haavape/maximo/main/src/upi_airgap_configs/ImageContentSourcePolicyMongo.yaml
```

#### Install Mongo

```bash
#navigate to the directory where the auth folder exists for your cluster
export KUBECONFIG="$PWD/auth/kubeconfig"

#clone repo for install scripts
git clone https://github.com/grtn316/iot-docs.git

#navigate to certs directory
cd iot-docs/mongodb/certs/

#generate self signed certs
./generateSelfSignedCert.sh

#navigate back a directory to: /mongodb/iot-docs/mongodb
cd ..

#export the following variables, replacing the password
export MONGODB_STORAGE_CLASS="managed-premium"
export MONGO_NAMESPACE=mongo
export MONGO_PASSWORD="<enterpassword>"

#install MongoDB
./install-mongo-ce.sh

```

Follow our [testing steps](../../README.md#installing-mongodb) to verify MongoDB is deployed and functioning.


### Finishing Up

The cluster should now be online and accessible from the cli and the web console. You may proceed with your use case deployments.

You can retrieve login information from the logs here:

```bash
./openshift-install wait-for install-complete --log-level debug
```