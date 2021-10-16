# Introduction

This repository provides deployment guidance, scripts and best practices for running IBM Maximo Application Suite (Maximo or MAS) on OpenShift using the Azure Cloud. The instruction below have been tested with Maximo 8.5.0 on OpenShift 4.8.

TODO: Explain Maximo vs Maximo Apps and breakdown in the repo organization

> 🚧 **WARNING** this guide is currently in early stages and under active development. If you would like to contribute or use this right now, please reach out so we can support you.

## Getting Started

To move forward with a Maximo install you will need a few basics:

* An active Azure subscription.
  * A quota of at least 40 vCPU allowed for your VM type of choice (Dsv4 recommended). Request [a quota increase](https://docs.microsoft.com/azure/azure-portal/supportability/regional-quota-requests) if needed.
  * You will need owner permissions or have someone with owner permissions within reach.
* A domain or subdomain. If you don't have one, you can register one through Azure using an App Service Domain.
* Access to the IBM licensing service for IBM Maximo.
* Access to IBM downloads to download the Maximo Installer (masinstall)

These are normally provided by your organization. You will only need the IBM License for Maximo during the last few steps. Once you have secured access to an Azure subscription, you need a few more things:

* An Application Registration (SPN) with Contributor and User Access Administrator access on the Subscription you are intending to deploy into.
* OpenShift Container Platform up and running on a cluster with at least 24 vCPUs active for the worker nodes. You can deploy Azure Red Hat OpenShift or [OpenShift Container Platform](/docs/openshift/ocp/README.md).

An Azure Files storage account is optional if you are intending to [use  Azure Files](docs/azure/using-azure-files.md) in your deployment.

> 💡 **TIP**: It is recommended to use a Linux, Windows Subsystem for Linux or macOS system to complete the installation. You will need some command line binaries that are not as readily available on Windows.

For the installation you will need a few programs, these are: `oc` the OpenShift CLI, `openssl` and `kubectl`. You will also need Java installed to accept the license terms for Maximo. You can [grab the OpenShift clients from Red Hat at their mirror](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/). This will provide the `oc` CLI and also includes `kubectl`. You can install `openssl` by installing the OpenSSL package on most modern Linux distributions using your package manager. Knowledge of Kubernetes is not required but recommended as a lot of Kubernetes concepts will come by.

After these services have been installed and configured, you can successfully install and configure Maximo Application Suite (MAS) on OpenShift running on Azure.

## What needs to be done

The goal of this guide is to get a Maximo product running on top of Maximo Core on top of OpenShift on top of Azure. For example with Maximo Monitor, that would look like this:

TODO: Diagram

For us to get there we need to execute the following steps:

1. [Prepare and configure Azure](#step-1-preparing-azure) resources for OpenShift and Maximo install
2. [Deploy OpenShift](#step-2-deploy-openshift)
3. [Install the dependencies of the Maximo](#step-3a-dependencies-for-maximo) and then [Maximo itself](#step-3b-installing-maximo) (Core)
4. Install Cloud Pak for Data and OCS
5. Install any dependencies that your Maximo product has
6. Deploy the Maximo solution.

## Step 1: Preparing Azure

Please follow [this guide](docs/azure/README.md) to configure Azure.

## Step 2: Deploy OpenShift

Please follow [this guide](docs/openshift/ocp/README.md) to configure OpenShift Container Platform on Azure. Guidance for ARO will follow later.

### Azure Files CSI drivers

If you are planning on using the Azure Files CSI driver instead of the Azure Disk CSI drivers, you will need to install the driver. It is not provided by OpenShift right out of the box. Please follow [these instructions](docs/azure/using-azure-files.md) to set up Azure Files with OpenShift.

### Enabling OIDC authentication against Azure AD

TODO

### Updating pull secrets

You will need to update the pull secrets to make sure that all containers on OpenShift can pull from the IBM repositories. This means using your entitlement key to be able to pull the containers. This is needed specifically for the install of Db2wh, as there is no other way to slip your entitlement key in. Detailed steps can be found in the [IBM Documentation for CP4D](https://www.ibm.com/docs/en/cpfs?topic=312-installing-foundational-services-by-using-console).

```bash
oc extract secret/pull-secret -n openshift-config --keys=.dockerconfigjson --to=. --confirm
echo "cp:<your_entitlement_key>" | base64 - w0
```

Next, edit .dockerconfigjson using your favorite text editor and update the JSON so that your `cp.icr.io` block is added to the `auths` block:

```json
{
  "auths": {
     "cp.icr.io" : {
        "auth": "<the_string_created_by_the_base64_command_above>",
        "email": "<your_email_address>"
     }
  }
}
```

After that push your updated .dockerconfigjson:

```bash
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson
```

### Finishing up

Once you have to OpenShift installed, visit the admin URL and try to log in to validate everything is up and running. The URL will look something like `console-openshift-console.apps.{clustername}.{domain}.{extension}`. The username is kubeadmin and the password was provided to you by the installer.

You will need to login to the `oc` CLI. You can get an easy way to do this by navigating the the `Copy login` page. You can find this on the top right of the screen:

![Copy login panel](docs/images/ocp-copy-login.png)

Login if needed, click on display token and use the oc login command to authenticate your `oc` client to your OpenShift deployment.

Once you have confirmed everything looks good, you can proceed with the requirements for Maximo.

<!-- this can be split off later to the apps section -->

## Step 3: Installing Maximo Core

Maximo Application Suite (MAS or Maximo) can be installed on OpenShift. IBM provides documentation for Maximo on its [documentation site](https://www.ibm.com/docs/en/mas85/8.5.0). Make sure to refer to the documentation for [Maximo 8.5.0](https://www.ibm.com/docs/en/mas85/8.5.0), as that is the version we are describing throughout this document.

This steps referring to the base suite to install, also referred to as Maximo Core. All of the steps below assume you are logged on to your OpenShift cluster and you have the `oc` CLI available.

> 💡 **TIP**:
> Copy the `oc` client to your /usr/bin directory to access the client from any directory. This will be required for some installing scripts.

### Step 3a: Dependencies for Maximo

Maximo has a few requirements that have to be available before it can be installed. These are:

1. JetStack cert-manager
1. MongoDB CE
1. Service Binding Operator
1. IBM Catalog Operator
1. IBM Behavioral Analytics Systems (BAS)
1. IBM Suite Licensing Services (SLS)
 
#### Installing cert-manager

[cert-manager](https://github.com/jetstack/cert-manager) is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. It is required for [Maximo](https://www.ibm.com/docs/en/mas85/8.5.0?topic=installation-system-requirements#mas-requirements). For more installation and usage information check out the [cert-manager documentation](https://cert-manager.io/v0.16-docs/installation/openshift/).
Installation of cert-manager is relatively straight forward. Create a namespace and install:

```bash
oc create namespace cert-manager
oc apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
```

To validate everything is up and running, check `oc get po -n cert-manager`. If you have the [kubectl cert-manager extension](https://cert-manager.io/docs/usage/kubectl-plugin/#installation) installed, you can also verify the install with `kubectl cert-manager check api`.

```bash
oc get po -n cert-manager
```

Output should be like this:

<pre>
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-5597cff495-dh278             1/1     Running   0          2d1h
cert-manager-cainjector-bd5f9c764-2j29c   1/1     Running   0          2d1h
cert-manager-webhook-c4b5687dc-thh2b      1/1     Running   0          2d1h
</pre>

> ❗ **IMPORTANT** TODO: This is colliding with IBM cert-manager, need to figure out how to make Maximo happy. Right now the only fix is to remove all duplicate CertificateRequests (the ones from IBM cert-manager)

#### Installing MongoDB

In this example, we will be installing the community edition of MongoDB on OpenShift using self signed certs. [MongoDB Community Edition](https://www.mongodb.com) is the free version of MongoDB. This version does not come with enterprise support nor certain features typically required by enterprises. We recommend exploring the options below for production use:

* [Azure CosmosDB for MongoDB](https://docs.microsoft.com/en-us/azure/cosmos-db/mongodb/mongodb-introduction)
* [MongoDB Atlas on Azure](https://docs.atlas.mongodb.com/reference/microsoft-azure/)

If you are not using our globally available service, Azure CosmosDB, then we recommend starting with a minimum 3 node ReplicaSet, with 1 node in each availability zone (outside of the OpenShift cluster). Please verify your deployment will be in the the same region / zones your OpenShift cluster are deployed into.

 To get started, you will clone a github repository and execute a few scripts:

```bash
#clone repo
git clone https://github.com/ibm-watson-iot/iot-docs.git

#navigate to the certs directory
cd mongodb/iot-docs/mongodb/certs/

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

This install can take up to 15 minutes. Once completed, verify the services are online by checking the status of the key: "status.phase":

```bash
oc get MongoDBCommunity -n mongo -o yaml | grep phase

status.phase = Running
```

Capture the connection string by running the following command:

```bash
oc get MongoDBCommunity -n mongo -o yaml | grep mongoUri

mongoUri: mongodb://mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-1.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-2.mas-mongo-ce-svc.mongo.svc.cluster.local:27017
```

Finally, retrieve the certificates from one of the running containers:

```bash
oc exec -it mas-mongo-ce-0 --container mongod -n mongo -- openssl s_client -servername mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local -connect mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local:27017 -showcerts
```

Copy the certs from the output. These will be used during the Maximo initial setup:

```bash
BEGIN CERTIFICATE
...
END CERTIFICATE

BEGIN CERTIFICATE
...
END CERTIFICATE
```

#### Installing Service Binding Operator

[Service Binding Operator](https://github.com/redhat-developer/service-binding-operator/blob/master/README.md) enables application developers to more easily bind applications together with operator managed backing services such as databases, without having to perform manual configuration of secrets, configmaps, etc. 

We have to put this operator on manual approval and you can NOT and should NOT upgrade the operator to a newer version. Maximo requires 0.8.0 specifically. To install, run the following commands:

```bash
oc apply -f src/servicebinding/service-binding-operator.yaml -n openshift-operators
installplan=$(oc get installplan -n openshift-operators | grep -i service-binding | awk '{print $1}'); echo "installplan: $installplan"
oc patch installplan ${installplan} -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'
```

To validate everything is up and running, check `oc get csv service-binding-operator.v0.8.0`.

```bash
oc get csv service-binding-operator.v0.8.0

# It should print the below, pay attention to the Succeeded.

NAME                              DISPLAY                    VERSION   REPLACES                          PHASE
service-binding-operator.v0.8.0   Service Binding Operator   0.8.0     service-binding-operator.v0.7.1   Succeeded
```

#### Installing IBM Catalog Operator

[IBM Catalog Operator](https://) is an index of operators available to automate deployment and maintenance of IBM Software products into Red Hat® OpenShift® clusters. Operators within this catalog have been built following Kubernetes best practices and IBM standards to provide a consistent integrated set of capabilities.

To install, run the following commands:

```bash
oc apply -f src/operatorcatalogs/catalog-source.yaml -n openshift-marketplace
```

To validate everything is up and running, check `oc get catalogsource/ibm-operator-catalog -n openshift-marketplace`.

```bash
oc get catalogsource/ibm-operator-catalog -n openshift-marketplace

NAME                   DISPLAY                TYPE   PUBLISHER   AGE
ibm-operator-catalog   IBM Operator Catalog   grpc   IBM         5d21h
```

#### Installing IBM Behavior Analytics Services Operator (BAS)

[IBM Behavior Analytics Services Operator](https://catalog.redhat.com/software/operators/detail/5fabe3c360c9b64020a34f02) is a service that collects, transforms and transmits product usage data.

To install, run the following commands:

```bash
oc new-project ibm-bas
oc apply -f src/bas/bas-operator.yaml
```

Next, you will need to create 2 secrets. Be sure to update the username and password in the example below:

```bash
oc create secret generic database-credentials --from-literal=db_username=<enterusername> --from-literal=db_password=<enterpassword> -n ibm-bas
oc create secret generic grafana-credentials --from-literal=grafana_username=<enterusername> --from-literal=grafana_password=<enterpassword> -n ibm-bas
```

Finally, deploy the Analytics Proxy. This will take up to 30 minutes to complete:

> 🚧 **WARNING** The below configuration is using the `azurefiles` storage class created in a previous step. If you did not configure this, you will need to update the class with another option.

```bash
# Grant Azure files permissions to this namespace
oc policy add-role-to-user admin system:serviceaccount:kube-system:persistent-volume-binder -n ibm-sls

# Deploy
oc apply -f src/bas/bas-service.yaml

# You can monitor the progress, keep an eye on the status section:
oc describe AnalyticsProxy analyticsproxy -n ibm-bas

# or use oc status
oc status
```

Once this is complete, retrieve the bas endpoint and the API Key for use when doing the initial setup of Maximo:

```bash
oc get routes bas-endpoint -n ibm-bas
oc apply -f src/bas/bas-api-key.yaml
```

Wait a few minutes and then fetch the key:
```bash
oc get secret bas-api-key -n ibm-bas --output="jsonpath={.data.apikey}" | base64 -d
```

Finally, retrieve the certificates from the public endpoint (bas-endpoint from above):

```bash
openssl s_client -servername bas-endpoint-ibm-bas.apps.{clustername}.{domain}.{extension} -connect bas-endpoint-ibm-bas.apps.{clustername}.{domain}.{extension}:443 -showcerts
```

Copy the certs from the output. These will be used during the Maximo initial setup:

```bash
BEGIN CERTIFICATE
...
END CERTIFICATE

BEGIN CERTIFICATE
...
END CERTIFICATE
```

#### Installing IBM Suite License Service (SLS)

[IBM Suite License Service](https://github.com/IBM/ibm-licensing-operator) (SLS) is a token-based licensing system based on Rational License Key Server (RLKS) with MongoDB as the data store.

To configure this service, you will need the following:

* IBM Entitlement Key
* MongoDB Info
  * Hostnames and ports (27017 by default)
  * Database Name
  * Admin Credentials

Create a new project and store the docker secret with IBM entitlement key:

```bash
oc new-project ibm-sls
export ENTITLEMENT_KEY=<Entitlement Key>
oc create secret docker-registry ibm-entitlement --docker-server=cp.icr.io --docker-username=cp  --docker-password=$ENTITLEMENT_KEY -n ibm-sls 
```

Next we need to provide the mongo credentials to SLS, we do this by creating a secret for it. In case you forgot the MongoDB password, retrieve it:

```bash
oc extract secret/mas-mongo-ce-admin-password --to=- -n mongo
```

Then create the secret:

```bash
oc create secret generic sls-mongo-credentials --from-literal=username=admin --from-literal=password=<MONGO_PASSWORD> -n ibm-sls
```

Deploy the operator group and subscription configurations:

```bash
oc apply -f src/sls/sls-operator.yaml
```

This will take a while, as usual, check its progress with `oc get csv -n ibm-sls`. Once done, deploy the sls-service. For this we need to make sure the correct details for Mongo are provided. The default is likely correct, but you should review the `sls-service.yaml` file and make sure the section for mongo is up-to-date:

```yml
  mongo:
    configDb: admin
    nodes:
    - host: mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local
      port: 27017
    - host: mas-mongo-ce-1.mas-mongo-ce-svc.mongo.svc.cluster.local
      port: 27017
    - host: mas-mongo-ce-2.mas-mongo-ce-svc.mongo.svc.cluster.local
      port: 27017
    secretName: sls-mongo-credentials
```

> 🚧 **WARNING** The YAML configuration is using the `azurefiles` storage class created in a previous step. If you did not configure this, you will need to update the class with another option.

Deploy the service configuration:

```bash
# Grant Azure files permissions to this namespace
oc policy add-role-to-user admin system:serviceaccount:kube-system:persistent-volume-binder -n ibm-sls

# Deploy
oc apply -f src/sls/sls-service.yaml
```

Wait for IBM SLS to come up, you can check its progress and also grab the connection details:

```bash
oc get LicenseService sls -n ibm-sls -o yaml
```

### Step 3b: Installing Maximo

#### Deploying using the Operator (recommended)

Maximo install is the same as the other services: install an operator and then create a Suite service. First we need to deploy the operator:

```bash
oc apply -f src/mas/mas-operator.yaml
```

Check progress of the operator installation:

```bash
oc get csv -n mas-test-core
```

Once it says succeeded for MAS, the Truststore and the Common Service Operator (ignore the Service Binding Operator) it is time to install Maximo.

Open the YAML file and **modify the `domain` field and update it to your specific domain and configuration**. Once you have done that:
 
```bash
oc apply -f src/mas/mas-service.yaml
```

Check the progress with:

```bash
oc describe Suite test -n mas-test-core
oc get all -n mas-test-core
```

Once the route is up for the admin dashboard, we can proceed with the initial set up. Grab the username and password by extracting the secret:

```bash
oc extract secret/nonprod-credentials-superuser -n mas-nonprod-core --to=-
```

Skip the step below and proceed with the Maximo set up.

#### Deploying with install-mas.sh (not recommended)

Not recommended, use the YAML way instead.

If you have an IBM Passport Advantage account, you may download the latest version of Maximo from the service portal. If not, you can install directly using the IBM Maximo Operator inside of OpenShift. In this example, we will install using the operator.

Before you can proceed with installing you need to make sure you have a working version of Java in your path. This is needed to accept the license terms for Maximo. The installer for Maximo can be downloaded from [IBM Passport Advantage](https://www.ibm.com/support/fixcentral/swg/downloadFixes?parent=ibm%7ETivoli&product=ibm/Tivoli/IBM+Maximo+Application+Suite&release=8.4.0&platform=All&function=fixId&fixids=8.4.2-IBM-MAS-FP0001&includeRequisites=1&includeSupersedes=0&downloadMethod=http). You will need subscriber access to that. Talk to your IBM representative to get that.

Install Maximo by exporting your ENTITLEMENT_KEY and then running the install-mas.sh script.

```bash
export ENTITLEMENT_KEY=eyJ0eXAiOiJKV<snip>
chmod +x install-mas.sh
./install-mas.sh -i dev -d nonprod.apps.newcluster.maximoonazure.com --accept-license
```

This will take a while to deploy the MAS operator and instantiate it. When completed the output will look like this:

```
Administration Dashboard URL
--------------------------------------------------------------------------------
https://admin.nonprod.apps.newcluster.maximoonazure.com

Super User Credentials
--------------------------------------------------------------------------------
Username: L3OUkILDwaGDM3vWCXMROVJSlmmUnfTC
Password: Wmb73X4somethinglong

Please make a record of the superuser credentials.

If this is a new installation, you can now complete the initial setup
Sign in as the superuser at this URL:
https://admin.nonprod.apps.newcluster.maximoonazure.com/initialsetup
```

#### Setting up Maximo

When using self signed certificates, you will need to visit the https://api.<clusterdomain> page. In our example this is https://api.nonprod.apps.newcluster.maximoonazure.com/. Navigate there and accept any certificates that pop up.

Navigate to https://admin.nonprod.apps.newcluster.maximoonazure.com/initialsetup and accept the SSL certs. You'll be welcomed with a wizard and then a screen like this:

![Maximo initial setup overview](docs/images/maximo-setup-initial.png)

We need to configure each of these dependencies. To gather the information, please execute the following steps:

```bash
# Mongo Details
echo -e 'Mongo Hosts:'; oc get MongoDBCommunity -n mongo  -o 'jsonpath={..status.mongoUri}' | sed -e "s/mongodb\:\/\///;s/\,/\n/g"; echo -e ""

echo -e "Mongo DB certificate:"
oc exec -it mas-mongo-ce-0 --container mongod -n mongo -- bash -c "echo | openssl s_client -servername mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local -connect mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local:27017 -showcerts 2>/dev/null |  openssl x509 -text | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p'"

echo "Mongo password:" $(oc extract secret/mas-mongo-ce-admin-password --to=- -n mongo)

# BAS Details
echo "Bas endpoint:" https://$(oc get routes bas-endpoint -n ibm-bas |awk 'NR==2 {print $2}')
echo "Bas API key:" $(oc get secret bas-api-key -n ibm-bas --output="jsonpath={.data.apikey}" | base64 -d)

# Grab the TLS certificates, you'll need both

echo | openssl s_client -servername bas-endpoint-ibm-bas.apps.newcluster.maximoonazure.com -connect bas-endpoint-ibm-bas.apps.newcluster.maximoonazure.com:443 -showcerts 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p'

# SLS Details

# Grab the ca.crt
oc extract secrets/sls-cert-ca -n ibm-sls --to=- | openssl x509

# And the API key
oc describe LicenseService sls -n ibm-sls | grep "Registration Key"
```

##### Step 3b.a: Set up MongoDB

Grab the details for MongoDB with the script above and enter it below. The authdb = admin, authentication = default. Hit confirm on the certificate and save the settings.

![MongoDB configuration](docs/images/maximo-setup-mongocfg.png)

##### Step 3b.b: Set up BAS

For BAS you need an API key and the BAS endpoint (public endpoint). Grab both with the scripts above and enter below. Hit confirm on the certificate and then save.

> ❗ **IMPORTANT** BAS requires both certificates loaded to proceed. Make sure you add both the wildcard and the TLS cert for the ingress-operator

![BAS configuration](docs/images/maximo-setup-bascfg.png)

##### Step 3b.c: Set up SLS

For SLS you'll need to do two steps, first set up the below with the details gathered from above. 

![SLS configuration](docs/images/maximo-setup-slscfg.png)

After that you'll be greeted with a wizard that calibrates SLS for licensing:

![SLS configuration](docs/images/maximo-setup-slscfg-validation.png)

Once it completes it'll generate some details you need to generate the license.dat file.

##### Step 3b.d: Generate a license.dat file and finalize workspace

With the configuration for all the pieces complete, you'll get a challenge from the SLS. You are provided with a hostname and an ethernet address. Click on the link to take you to the IBM License Center and create a license.dat file. If you have no access, work with someone who does. Take the license.dat and upload it into the page:

![SLS configuration](docs/images/maximo-setup-post-config.png)


Once the license is loaded, set up a workspace. This has to be a unique name. Once done, hit "SAVE" and then "FINISH" on the top right. Maximo will no finalize the setup.


## Step 4: Installing Cloud Pak for Data

Be cautious handling Cloud Pak for Data (CP4D) as it is quite a delicate web of dependencies. It is easy to mess one up, so make sure you understand what you do before you deviate from the path below.

### Installing CP4D 3.5

Cloud Pak for Data 3.5 can only be installed in the namespace where the operator has been installed.

```bash
# Create namespace
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/CloudPakForData/3.5/cpd-meta-ops-namespace.yaml

# Create a pull secret, needed for the meta-api

export ENTITLEMENT_KEY=<keyhere>
oc -n cpd-meta-ops create secret docker-registry ibm-entitlement-key --docker-server=cp.icr.io --docker-username=cp --docker-password=$ENTITLEMENT_KEY 

# Create operator group and operators
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/CloudPakForData/3.5/cp4d35-operator-group.yaml -n cpd-meta-ops
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/CloudPakForData/3.5/scheduling-service-operator.yaml -n cpd-meta-ops
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/CloudPakForData/3.5/cloud-pak-for-data-operator.yaml -n cpd-meta-ops

oc get -n cpd-meta-ops csv

# Proceed when both operators are marked as succeeded. This install cp4d 3.5

oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/CloudPakForData/3.5/cloud-pak-cpdservice.yaml -n cpd-meta-ops
```

You can retrieve the password for CP4D by extracting the `admin-user-details` secret:

```
oc extract secret/admin-user-details --keys=initial_admin_password --to=- -n cpd-meta-ops
```

### Installing CP4D 4.0

CP4D 4.0 has a requirements:

1. IBM Catalog Source set up
1. OpenShift Container Storage (OCS) deployed and configured

During the install, the operators install many other operators, such as the IBM Namedscope Operator, the IBM Zen Operator and IBM Cert Manager.

#### Installing OpenShift Container Storage

OpenShift Container Storage provides ceph to our cluster. Ceph is used by a variety of Maximo services to store its data. Before we can deploy OCS, we need to make a new machineset for it as it is quite needy: a minimum of 30 vCPUs and 72GB of RAM is required. In our sizing we use 4x B8ms for this machineset, the bare minimum and put them on their own nodes so there's no resource contention. After the machineset we need the OCS operator. Alternatively, you can install it from the OperatorHub.

```bash
oc apply -f src/machinesets/ocs-z1.yaml

# Create the namespace
oc apply ns openshift-storage

# Install the operator
oc apply -f src/ocs/ocs-operator.yaml
```

After provisioning the cluster, go to the OpenShift Container Storage operator in the `openshift-storage` namespace and create a `StorageCluster`. Following settings (which are the default):
* managed-premium as StorageClass
* Requested capacity, 2TB or 0.5TB
* Selected nodes: you will see that the operator already pre-selects the nodes we just created. If not, pick the ocs-* nodes

Press next. On the next blade, security and network: leave as is, Default (SDN) and no encryption. Press next. In the last blade, confirm it all and deploy. This takes a while, so check back a while later. You can see if OCS is up and running by going to Storage -> Overview in the OpenShift Admin UI.

#### Installing CP4D Operators

CP4D will install its operators in a namespace called ibm-common-services and the actual deployment will be in another namespace (e.g. cp4d). In this guide we combine the CP4D foundational services together with CP4D operator itself, which is an easier approach. 

```bash
oc apply -f src/CloudPakForData/4.0/cloud-pak-install-operators.yaml
```

This needs a little bit, so have some patience for things to install. You can check the status with:

```bash
oc get -n ibm-common-services csv
```

Output should look like below:

<pre>
roeland@metanoia:~/maximo$ oc get -n ibm-common-services csv
NAME                                           DISPLAY                                VERSION   REPLACES                                      PHASE
cpd-platform-operator.v2.0.4                   Cloud Pak for Data Platform Operator   2.0.4                                                   Succeeded
ibm-cert-manager-operator.v3.14.0              IBM Cert Manager                       3.14.0    ibm-cert-manager-operator.v3.13.0             Succeeded
ibm-common-service-operator.v3.12.0            IBM Cloud Pak foundational services    3.12.0    ibm-common-service-operator.v3.11.0           Succeeded
ibm-cpd-scheduling-operator.v1.2.3             IBM CPD Scheduling                     1.2.3     ibm-cpd-scheduling-operator.v1.2.2            Succeeded
ibm-namespace-scope-operator.v1.6.0            IBM NamespaceScope Operator            1.6.0     ibm-namespace-scope-operator.v1.5.0           Succeeded
ibm-zen-operator.v1.4.0                        IBM Zen Service                        1.4.0     ibm-zen-operator.v1.3.0                       Succeeded
operand-deployment-lifecycle-manager.v1.10.0   Operand Deployment Lifecycle Manager   1.10.0    operand-deployment-lifecycle-manager.v1.9.0   Succeeded
</pre>

One the operator is done, you can proceed and deploy the actual CP4D instance. The api service is called Ibmcpd and is easiest created with YAML. Besides the Ibmcpd you also need an empty OperandRequest to allow the Namespacescope operator to reach from ibm-common-services into your target namespace (in our deployment this is cp4d).

```bash
oc apply -f src/CloudPakForData/4.0/cloud-pak-install-instance.yaml
```

This will take about 30 minutes. You can check the status by checking the ZenService lite-cr and Ibmcpd ibmcpd-cr for their status.

```bash
oc get ZenService lite-cr -n cp4d -o yaml
oc get Ibmcpd ibmcpd-cr -n cp4d -o yaml
```

Once installed, a route will appear and a password is created. Grab the details:

```bash
oc get routes -n cp4d
oc extract secret/admin-user-details --keys=initial_admin_password --to=- -n cp4d
```

Visit the URL (https). The username is admin, the password is in the secret.

<!-- ## Installing Cloud Pak for Data 4.0

Maximo Application Suite (MAS or Maximo) can be installed on OpenShift. IBM provides documentation for Maximo on its [documentation site](https://www.ibm.com/docs/en/mas85/8.5.0). Make sure to refer to the documentation for [Maximo 8.5.0](https://www.ibm.com/docs/en/mas85/8.5.0), as that is the version we are describing throughout this document.

All of the steps below assume you are logged on to your OpenShift cluster and you have the `oc` CLI available.

### Installing Cloud Pak Foundational Services

Prerequisites for Cloud Pak for Data (CP4D):

1. OpenShift Container Storage



https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/cpd/install/preinstall-operator-subscriptions.html

https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/cpd/install/preinstall-foundational-svcs.html


```bash
1. oc new-project ibm-common-services
1. cloud-pak-operator-group.yaml
1. scheduling-service-operator.yaml
1. cloud-pak-foundational-subscription.yaml
```

Check status:
```bash
oc --namespace ibm-common-services get csv

oc get crd | grep operandrequest

oc api-resources --api-group operator.ibm.com
```

### Installing Cloud Pak for Data

https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/cpd/install/preinstall-operator-subscriptions.html#preinstall-operator-subscriptions__install-plan#preinstall-operator-subscriptions__install-plan


https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/cpd/install/install-overview.html

1. cloud-pak-for-data-operator.yaml
1. oc new-project cp4d
1. cloud-pak-enable-operators.yaml
1. cloud-pak-install.yaml

Approve Install Plan:
installplan=$(oc get installplan -n cp4d | grep -i ibm-cert-manager-operator | awk '{print $1}'); echo "installplan: $installplan"
oc patch installplan ${installplan} -n cp4d --type merge --patch '{"spec":{"approved":true}}'

installplan=$(oc get installplan -n cp4d | grep -i ibm-zen-operator | awk '{print $1}'); echo "installplan: $installplan"
oc patch installplan ${installplan} -n cp4d --type merge --patch '{"spec":{"approved":true}}' -->

## Step 5: Maximo solution dependencies

### Installing Db2 Warehouse

To deploy a Db2 warehouse for use with CP4D you need to install the DB2 Operator into an operator group in a namespace and create an instance of the `Db2whService`. 

The YAML in src/Db2Warehouse/db2-install.yaml will do that for you:

```bash
oc apply -f db2-operator.yaml

```

When you install the CP4D DB2 Warehouse Operator, it will also grab the DB2U operator as DB2WH first deploys a regular DB2U to build a warehouse on top. After deploying the operator, you can create a Db2whService in your cp4d namespace. Once you have done this, an instance will light up in your cp4d.

```bash
oc apply -f db2-service.yaml
```

<!-- I don't think we need this anymore? @ranieuwe 
    oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/Db2Warehouse/rook-ceph-operator-config.yaml -n openshift-storage
-->

#### Dedicated nodes

In order to use dedicated nodes for the db2wh deployment you need to create a new machineset with a taint of `ipd4data`. Dedicated nodes are recommended for production deployments. 

Apply the taint to your machine like so:

```yml
taints:
- effect: NoSchedule
  key: icp4data
  value: mas-manage-db2wh
```

We have provided a MachineSet definition in `src/machinesets/db2.yaml` that has the correct taints and recommend sizing for a small DB2 cluster. Install these machines before you deploy DB2. Do so as follows:

```bash
oc apply -f src/machinesets/db2.yaml
```

When you deploy the db2 cluster, the taint it needs in the deployment is "mas-manage-db2wh". By default the db2wh can't see the machinesets from its service account (zen-databases-sa). Grant it permission to allow to see the machines so it can validate if taints and tolerations are going hand in hand.

> 💡 **NOTE** Do not use node selectors, because this can cause ceph to be unavailable on your DB2 nodes

```
oc adm policy add-cluster-role-to-user system:controller:persistent-volume-binder system:serviceaccount:cp4d:zen-databases-sa
```

#### Deploying Db2 Warehouse

In cp4d you will now see a "database" link pop up. Now if you go to instances and hit "New instance" on the top right you will be greeted with this:

![Copy login panel](docs/images/cp4d-db2wh-instance.png)

Click on it, press next and deploy. In this deployment we are using OCS as the certified deployment mechanism. The specifications are [provided by IBM in their documentation](https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-db2w/db2wh-cert-storage.html).

TODO: further notes

#### Configuring Maximo with DB2WH

Go to the configuration panel for Maximo by pressing on the cog on the top right or by going to https://<admin.maximocluster.domain>/config. It will ask you for some details that you can get from the CP4D DB2 overview. On your DB2 Warehouse instance, go to details. In the overview you will get the JDBC URL. Something like `jdbc:db2://<CLUSTER_ACCESSIBLE_IP>:32209/BLUDB:user=admin;password=<password>;securityMechanism=9;encryptionAlgorithm=2`. If you click on the copy icon, it gives you the required details.

Please read the [Maximo documentation on how to specify the URL for DB2WH specifically](https://www.ibm.com/docs/en/mas85/8.5.0?topic=administering-configuring-suite#data) as it depends on the Maximo application you are deploying. Especially so for manage and monitor (requires SSL).

To grab the URL check the svc endpoint that sits in front of the nodes. To get that, execute the following:

```bash
oc get svc -n cp4d | grep db2u-engn
```

Your URL shuld be formed like this: `jdbc:db2://hostname:port/database_name;sslConnection=true`.

Your host is in the list of services above. For example c-db2wh-1634180797242781-db2u-engn-svc.cp4d.svc.cp4d.svc. The port is 50000 for plain or 50001 for SSL, you should use 50001. For the connection string to work with Monnitor you MUST specify `;sslConnection=true` to the end of the connection string.

### Installing Kafka

You need to use strimzi-0.22.x. Versions > 0.22 remove the betav1 APIs that the BAS Kafka services depend on. Strimzi comes as an operator, a service and a user that all need to be deployed. 

Kafka is quite CPU and memory intensive and needs plenty of resources. You'll likely need to scale up your MachineSets to be able to host Kafka.

```bash
# Setup namespace, operator group and operator
oc apply -f strimzi-operator.yaml

# Wait for strimzi operator be completed
oc get csv -n strimzi-kafka
```

Once completed, allow Azure Files (backing for Kafka) and install the service (server, user)

```bash
oc policy add-role-to-user admin system:serviceaccount:kube-system:persistent-volume-binder -n strimzi-kafka
oc apply -f strimzi-service.yaml
```

Monitor for completion on the Kafka resource

```bash
# Grab the TLS cert from the Kafka service
oc get KafkaUser,Kafka -n strimzi-kafka -o yaml

# Grab the password
oc extract secret/masuser --to=- -n strimzi-kafka
```

To test if Kafka is up and running successfully on your cluster you can use kcat (kafkacat). We recommend testing Kafka, because getting the details right is a bit finicky, and if you get it wrong the IoT install fails and you can't really roll it back - meaning you need to reinstall mas.

To check with kcat, execute the following steps, fire up a kcat container:

```bash
oc debug  --image edenhill/kcat:1.7.0 -n strimzi-kafka
```

Create a ca.pem fil on / with the details from the Kafka service. Next, execute the following kcat command:

```bash
kcat -b maskafka-kafka-2.maskafka-kafka-brokers.strimzi-kafka.svc:9093 -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=masuser -X sasl.password=password -X ssl.ca.location=ca.pem -L
```

Output like this:

<pre>

Metadata for all topics (from broker 2: sasl_ssl://maskafka-kafka-2.maskafka-kafka-brokers.strimzi-kafka.svc:9093/2):
 3 brokers:
  broker 0 at maskafka-kafka-0.maskafka-kafka-brokers.strimzi-kafka.svc:9093
  broker 2 at maskafka-kafka-2.maskafka-kafka-brokers.strimzi-kafka.svc:9093
  broker 1 at maskafka-kafka-1.maskafka-kafka-brokers.strimzi-kafka.svc:9093 (controller)
 0 topics:
</pre>

#### Configuring Maximo with Kafka

Enter all the brokers with port 9093 (TLS) or 9092 (non-TLS). The brokers are <cluster-name>-kafka-<n>.<cluster-name>-kafka-broker.<namespace>.svc, e.g.  maskafka-kafka-0.maskafka-kafka-brokers.strimzi-kafka.svc for a cluster called `maskafka` installed in namespace `strimzi-kafka`. You can see them listed with kcat too for convenience. To get the credentials for Kafka execute `oc extract secret/mas-user --to=- -n strimzi-kafka`.

Make sure to load the TLS cert onto the Kafka configuration or your connection to port 9093 will fail. If you use port 9092 (non-TLS) the TLS certificate isn't needed.

TODO: Details steps to get the CORRECT certificates (both!)

### Installion IoT tools

The IBM IoT tools requires MongoDB, Kafka and DB2WH, all of which are available if you followed the steps above. If not, please install any missing dependencies.

Go to the Maximo Configuration -> Catalog -> Tools and click on IoT. Next click Continue on the right.

The IoT tool needs an ibm-entitlement key for the cp.icr.io repository. This is your regular IBM entitlement key. Create as such:

```bash
oc create secret docker-registry ibm-entitlement --docker-username=cp --docker-password=<YOUR_KEY> --docker-server=cp.icr.io -n mas-nonprod-core

oc create ns mas-nonprod-iot
oc create secret docker-registry ibm-entitlement --docker-username=cp --docker-password=<YOUR_KEY> --docker-server=cp.icr.io -n mas-nonprod-iot
```

TODO: Instruct on how to recover from a botched Maximo deploy/cert wise? e.g. go into mongodb, kill tables and update truststore.jks with keytool

## To get your credentials to login

For Maximo: `oc extract secret/nonprod-credentials-superuser -n mas-nonprod-core --to=-`

## Contributing

This project welcomes contributions and suggestions.  Most contributions require ou to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).

Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
