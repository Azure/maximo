# Introduction

This repository provides deployment guidance, scripts and best practices for running IBM Maximo 8.5.0 on OpenShift 4.8.10 using the Azure Cloud.

> 🚧 **WARNING** this guide is currently in early stages and under active development. If you would like to contribute or use this right now, please reach out so we can support you.

## Getting Started

To move forward with a Maximo install you will need a few basics:

* An active Azure subscription.
  * A quota of at least 40 vCPU allowed for your VM type of choice (Dsv4 recommended). Request [a quota increase](https://docs.microsoft.com/azure/azure-portal/supportability/regional-quota-requests) if needed.
  * You will need owner permissions or have someone with owner permissions within reach.
* A domain or subdomain. If you don't have one, you can register one through Azure using an App Service Domain.
* Access to the IBM licensing service for IBM Maximo.

These are normally provided by your organization. You will only need the IBM License for Maximo during the last few steps. Once you have secured access to an Azure subscription, you need a few more things:

* An Application Registration (SPN) with Contributor and User Access Administrator access on the Subscription you are intending to deploy into.
* OpenShift Container Platform up and running on a cluster with at least 24 vCPUs active for the worker nodes. You can deploy Azure Red Hat OpenShift or [OpenShift Container Platform](/docs/openshift/ocp/README.md).

An Azure Files storage account is optional if you are intending to [use  Azure Files](docs/azure/using-azure-files.md) in your deployment.

> 💡 **TIP**: It is recommended to use a Linux, Windows Subsystem for Linux or macOS system to complete the installation. You will need some command line binaries that are not as readily available on Windows.

For the installation you will need a few programs, these are: `oc` the OpenShift CLI, `openssl` and `kubectl`. You can [grab the OpenShift clients from Red Hat at their mirror](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/). This will provide the `oc` CLI and also includes `kubectl`. You can install `openssl` by installing the OpenSSL package on most modern Linux distributions using your package manager. Knowledge of Kubernetes is not required but recommended as a lot of Kubernetes concepts will come by.

After these services have been installed and configured, you can successfully install and configure Maximo Application Suite (MAS) on OpenShift running on Azure.

### Azure configuration

Please follow [this guide](docs/azure/README.md) to configure Azure.

### OpenShift

Please follow [this guide](docs/openshift/ocp/README.md) to configure OpenShift Container Platform on Azure. Guidance for ARO will follow later.

### Azure Files CSI drivers

If you are planning on using the Azure Files CSI driver instead of the Azure Disk CSI drivers, you will need to install the driver. It is not provided by OpenShift right out of the box. Please follow [these instructions](docs/azure/using-azure-files.md) to set up Azure Files with OpenShift.

### Finishing up

Once you have to OpenShift installed, visit the admin URL and try to log in to validate everything is up and running. The URL will look something like `console-openshift-console.apps.{clustername}.{domain}.{extension}`. The username is kubeadmin and the password was provided to you by the installer.

You will need to login to the `oc` CLI. You can get an easy way to do this by navigating the the `Copy login` page. You can find this on the top right of the screen:

![Copy login panel](docs/images/ocp-copy-login.png)

Login if needed, click on display token and use the oc login command to authenticate your `oc` client to your OpenShift deployment.

Once you have confirmed everything looks good, you can proceed with the requirements for Maximo.

<!-- this can be split off later to the apps section -->

## Installing Maximo

Maximo Application Suite (MAS or Maximo) can be installed on OpenShift. IBM provides documentation for Maximo on its [documentation site](https://www.ibm.com/docs/en/mas85/8.5.0). Make sure to refer to the documentation for [Maximo 8.5.0](https://www.ibm.com/docs/en/mas85/8.5.0), as that is the version we are describing throughout this document.

All of the steps below assume you are logged on to your OpenShift cluster and you have the `oc` CLI available.

### Installing cert-manager

[cert-manager](https://github.com/jetstack/cert-manager) is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. It is required for [Maximo](https://www.ibm.com/docs/en/mas85/8.5.0?topic=installation-system-requirements#mas-requirements). For more installation and usage information check out the [cert-manager documentation](https://cert-manager.io/v0.16-docs/installation/openshift/).

Installation of cert-manager is relatively straight forward. Create a namespace and install:

```bash
oc create namespace cert-manager
oc apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml
```

To validate everything is up and running, check `oc get po -n cert-manager`. If you have the [kubectl cert-manager extension](https://cert-manager.io/docs/usage/kubectl-plugin/#installation) installed, you can also verify the install with `kubectl cert-manager check api`.

```bash
roeland@metanoia:~$ oc get po -n cert-manager
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-5597cff495-dh278             1/1     Running   0          2d1h
cert-manager-cainjector-bd5f9c764-2j29c   1/1     Running   0          2d1h
cert-manager-webhook-c4b5687dc-thh2b      1/1     Running   0          2d1h
```

### TODO

* [ ] Install MongoDB Community Edition
* [ ] Install Service Binding Operator
* [ ] Install IBM Catalog Operator
* [ ] Install IBM Behavior Analytics Service (BAS)
* [ ] Install IBM License Service

## Contributing

This project welcomes contributions and suggestions.  Most contributions require ou to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).

Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
