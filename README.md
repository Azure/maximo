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

For the installation you will need a few programs, these are: `oc` the OpenShift CLI, `openssl` and `kubectl`. You can [grab the OpenShift clients from Red Hat at their mirror](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/). This will provide the `oc` CLI and also includes `kubectl`. You can install `openssl` by installing the OpenSSL package on most modern Linux distributions using your package manager. Knowledge of Kubernetes is not required but recommended as a lot of Kubernetes concepts will come by.

After these services have been installed and configured, you can successfully install and configure Maximo Application Suite (MAS) on OpenShift running on Azure.

## What needs to be done

The goal of this guide is to get a Maximo product running on top of Maximo Core on top of OpenShift on top of Azure. For example with Maximo Monitor, that would look like this:

TODO: Diagram

For us to get there we need to execute the following steps:

1. [Prepare and configure Azure](#step-1-preparing-azure) resources for OpenShift and Maximo install
2. [Deploy OpenShift](#step-2-deploy-openshift)
3. [Install the dependencies of the Maximo](#step-3a-dependencies-for-maximo) and then [Maximo itself](#step-3b-installing-maximo) (Core)
4. Install OpenShift Container Storage
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

### Finishing up

Once you have to OpenShift installed, visit the admin URL and try to log in to validate everything is up and running. The URL will look something like `console-openshift-console.apps.{clustername}.{domain}.{extension}`. The username is kubeadmin and the password was provided to you by the installer.

You will need to login to the `oc` CLI. You can get an easy way to do this by navigating the the `Copy login` page. You can find this on the top right of the screen:

![Copy login panel](docs/images/ocp-copy-login.png)

Login if needed, click on display token and use the oc login command to authenticate your `oc` client to your OpenShift deployment.

Once you have confirmed everything looks good, you can proceed with the requirements for Maximo.

<!-- this can be split off later to the apps section -->

## Installing Maximo Core

Maximo Application Suite (MAS or Maximo) can be installed on OpenShift. IBM provides documentation for Maximo on its [documentation site](https://www.ibm.com/docs/en/mas85/8.5.0). Make sure to refer to the documentation for [Maximo 8.5.0](https://www.ibm.com/docs/en/mas85/8.5.0), as that is the version we are describing throughout this document.

This steps referring to the base suite to install, also referred to as Maximo Core. All of the steps below assume you are logged on to your OpenShift cluster and you have the `oc` CLI available.

> 💡 **TIP**:
> Copy the `oc` client to your /usr/bin directory to access the client from any directory. This will be required for some installing scripts.

### Step 3a: Dependencies for Maximo

Maximo has a few requirements that have to be available before it can be installed. These are:

1. cert-manager
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
oc create -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
```

To validate everything is up and running, check `oc get po -n cert-manager`. If you have the [kubectl cert-manager extension](https://cert-manager.io/docs/usage/kubectl-plugin/#installation) installed, you can also verify the install with `kubectl cert-manager check api`.

```bash
oc get po -n cert-manager

NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-5597cff495-dh278             1/1     Running   0          2d1h
cert-manager-cainjector-bd5f9c764-2j29c   1/1     Running   0          2d1h
cert-manager-webhook-c4b5687dc-thh2b      1/1     Running   0          2d1h
```

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

To install, run the following commands:

```bash
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/ServiceBinding/service-binding-operator.yaml -n openshift-operators
installplan=$(oc get installplan -n openshift-operators | grep -i service-binding | awk '{print $1}'); echo "installplan: $installplan"
oc patch installplan ${installplan} -n openshift-operators --type merge --patch '{"spec":{"approved":true}}'
```

To validate everything is up and running, check `oc get operator/ibm-sls.ibm-sls`.

```bash
oc get operator/ibm-sls.ibm-sls

NAME              AGE
ibm-sls.ibm-sls   5d7h
```

#### Installing IBM Catalog Operator

[IBM Catalog Operator](https://) is an index of operators available to automate deployment and maintenance of IBM Software products into Red Hat® OpenShift® clusters. Operators within this catalog have been built following Kubernetes best practices and IBM standards to provide a consistent integrated set of capabilities.

To install, run the following commands:

```bash
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/OperatorCatalogs/catalog-source.yaml -n openshift-marketplace
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
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/BehaviorService/bas-og.yaml -n ibm-bas
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/BehaviorService/bas-subscription.yaml -n ibm-bas
```

Next, you will need to create 2 secrets. Be sure to update the username and password in the example below:

```bash
oc create secret generic database-credentials --from-literal=db_username=<enterusername> --from-literal=db_password=<enterpassword> -n ibm-bas
oc create secret generic grafana-credentials --from-literal=grafana_username=<enterusername> --from-literal=grafana_password=<enterpassword> -n ibm-bas
```

Finally, deploy the Analytics Proxy. This will take up to 30 minutes to complete:

> 🚧 **WARNING** The below configuration is using the `azurefiles` storage class created in a previous step. If you did not configure this, you will need to update the class with another option.

```bash
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/BehaviorService/bas-analytics-proxy.yaml -n ibm-bas
```

Once this is complete, retrieve the bas endpoint and the API Key for use when doing the initial setup of Maximo:

```bash
oc get routes bas-endpoint -n ibm-bas
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/BehaviorService/bas-api-key.yaml -n ibm-bas
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
  * Hostnames / Ports
  * Database Name
  * Admin Credentials

Create a new project and store the docker secret with IBM entitlement key:

```bash
oc new-project ibm-sls
export ENTITLEMENT_KEY=<Entitlement Key>
oc -n ibm-sls create secret docker-registry ibm-entitlement --docker-server=cp.icr.io --docker-username=cp  --docker-password=$ENTITLEMENT_KEY
```

Next retrieve the YAML file that will contain the credentials to your MongoDB instance. It is highly recommended this file is removed after deployment. You may also just deploy this YAML code directly in the OCP console instead of pushing a file.

Retrieve and edit the yaml file, updating credentials:

```bash
wget https://raw.githubusercontent.com/Azure/maximo/main/src/LicenseService/sls-mongo.yaml
nano sls-mongo.yaml
```

YAML file will look like the following:

```yml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: sls-mongo-credentials
  namespace: ibm-sls
stringData:
  username: ‘<username>’
  password: ‘<password>’
```

Save the file and upload it to OCP:

```bash
oc create -f sls-mongo.yaml -n ibm-sls
```

Deploy the operator group and subscription configurations:

```bash
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/LicenseService/sls-og.yaml -n ibm-sls
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/LicenseService/sls-subscription.yaml -n ibm-sls
```

Retrieve and edit the config yaml file, updating the host information:

```bash
wget https://raw.githubusercontent.com/Azure/maximo/main/src/LicenseService/sls-config.yaml
nano sls-config.yaml
```

> 🚧 **WARNING** The below configuration is using the `azurefiles` storage class created in a previous step. If you did not configure this, you will need to update the class with another option.

YAML file will look like the following:

```yml
apiVersion: sls.ibm.com/v1
kind: LicenseService
metadata:
  name: sls
  namespace: ibm-sls
spec:
  license:
    accept: true
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
  rlks:
    storage:
      class: azurefiles
      size: 5G
```

Deploy the service configuration:

```bash
oc create -f https://raw.githubusercontent.com/Azure/maximo/main/src/LicenseService/sls-config.yaml -n ibm-sls
```

### Step 3b: Installing Maximo

If you have an IBM Passport Advantage account, you may download the latest version of Maximo from the service portal. If not, you can install directly using the IBM Maximo Operator inside of OpenShift. In this example, we will install using the operator.

## Installing Cloud Pak for Data

Maximo Application Suite (MAS or Maximo) can be installed on OpenShift. IBM provides documentation for Maximo on its [documentation site](https://www.ibm.com/docs/en/mas85/8.5.0). Make sure to refer to the documentation for [Maximo 8.5.0](https://www.ibm.com/docs/en/mas85/8.5.0), as that is the version we are describing throughout this document.

All of the steps below assume you are logged on to your OpenShift cluster and you have the `oc` CLI available.

### Installing Cloud Pak Foundational Services

Prerequisites for Cloud Pak for Data (CP4D):

1. OpenShift Container Storage

#### Setting up OpenShift Container Storage (OCS)

First we need to make a new machineset for OCS - it needs a minimum of 30 vCPUs and 72GB of RAM. Our existing cluster is not big enough for that.

```bash
oc apply -f src/MachineSets/ocs-z1.yaml
oc create ns openshift-storage
oc annotate namespace openshift-storage openshift.io/node-selector="components=ocs"



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
oc patch installplan ${installplan} -n cp4d --type merge --patch '{"spec":{"approved":true}}'

### Installing Db2 Warehouse

oc adm policy add-cluster-role-to-user system:controller:persistent-volume-binder system:serviceaccount:cp4d:zen-databases-sa

## Installing Kafka

You need to use strimzi-0.22.x. Versions > 0.22 remove the betav1 APIs that the BAS Kafka services depend on.

1. Install Strimzi TODO
1. Grab the CA for Strimzi, hop onto a container and execute `

To test if Kafka is up and running successfully on your cluster you can use kcat (kafkacat). To do so, execute the following steps:

1. Deploy and enter a kcat container 
1. Create a ca.pem file on / and enter your CA credentials from the `openssl s_client` step

```bash
kcat -b maskafka-kafka-2.maskafka-kafka-brokers.ibm-strimzi.svc:9093 -X security.protocol=SASL_SSL -X sasl.mechanism=SCRAM-SHA-512 -X sasl.username=mas-user -X sasl.password=Y0i9PygsAUAI -X ssl.ca.location=ca.pem -L

Metadata for all topics (from broker 2: sasl_ssl://maskafka-kafka-2.maskafka-kafka-brokers.ibm-strimzi.svc:9093/2):
 3 brokers:
  broker 0 at maskafka-kafka-0.maskafka-kafka-brokers.ibm-strimzi.svc:9093
  broker 2 at maskafka-kafka-2.maskafka-kafka-brokers.ibm-strimzi.svc:9093
  broker 1 at maskafka-kafka-1.maskafka-kafka-brokers.ibm-strimzi.svc:9093 (controller)
 0 topics:
```

### Configuring Maximo with Kafka

Enter all the brokers with port 9093. The brokers are <cluster-name>-kafka-<n>.<cluster-name>-kafka-brokers.<namespace>.svc, e.g.  maskafka-kafka-0.maskafka-kafka-brokers.ibm-strimzi.svc for a cluster called `maskafka` installed in namespace `ibm-strimzi`. To get the credentials for Kafka execute `oc extract secret/mas-user --to=- -n ibm-strimzi`.

## To get your credentials to login

For Maximo: `oc extract secret/nonprod-credentials-superuser -n mas-nonprod-core --to=-`

## Contributing

This project welcomes contributions and suggestions.  Most contributions require ou to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).

Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
