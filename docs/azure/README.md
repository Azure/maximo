# Preparing Azure for OpenShift Deployment

## Table of Contents

* [Service Principal](#service-principal)
* [Virtual Network](#virtual-network)
* [Storage Accounts](#storage-accounts)
* [Jumpbox VM](#jumpbox-vm)
* [Bastion Host](#bastion-host)


## Service Principal

In order to allow the OCP IPI Installer to deploy within your environment, you will need to [create an Azure Application Registration (SPN)](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) and grant it `Contributor` and `User Access Administrator` permissions on the subscription you plan to deploy into. If granting permissions at the subscription level is not possible, you can also create a resource group for the IPI installer and configure the permissions on this resource group instead. You will need to target the resource group in the `install-config.yaml` file under the `platform.azure.resourceGroupName` section. More information can be found in the [openshift installer docs](https://docs.openshift.com/container-platform/4.8/installing/installing_azure/installing-azure-customizations.html#installation-configuration-parameters-additional-azure_installing-azure-customizations).

> 💡 **NOTE**: After deployment, you may remove the User Access Administrator access to the subscription. It is used to configure the Managed Identity within the Clusters Resource Group.

> 💡 **NOTE**: If you are using the deployment scripts found in this guide, you will need 2 resource groups. 1 will be targeted by the Bicep deployment and the other will be targeted by the IPI Installer. The IPI Installer uses terraform inside of the binary and will have issue with state when attempting to use a single resource group.

After creating the SPN and assigning its access, you will need to create a [secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-2-create-a-new-application-secret) that will be used during the OCP install process.

> 💡 **NOTE**: After the deployment, this account will be used by the OCP Cluster to interact with NSGs, Storage Accounts...etc. Keep in mind, when the secret expires the cluster will be unable to update the Azure cluster deployment and will need to be renewed in AAD.

## Virtual Network

It is recommended to create your own VNet and/or add additional subnets to an existing VNet for use during your OCP deployment.

### Recommended Subnet configuration

![VNet Subnets](../images/subnets.png)


## Storage Accounts

2 Storage Accounts should be created:

1. **Standard V2**
    1. **SKU:** Standard_ZRS
1. **Premium File Storage (NFS)**
    1. **SKU:** Premium_ZRS
    1. **HTTPS Traffic Support:** False

It is strongly recommended to create storage accounts using [private endpoints](https://docs.microsoft.com/en-us/azure/storage/common/storage-private-endpoints) connected to the endpoints subnet mentioned in the [Virtual Network](#virtual-network) section.

Storage classes for these accounts will be created during the [installation process](../../README.md#azure-files-csi-drivers).

## Jumpbox VM

This machine may be used as a jump box using Azure Bastion to connect to the OpenShift cluster. This is an optional VM as you may have existing network connectivity that already has this capability.

If this machine is desired, we recommending installing the following tools on the VM:

* [OC Client](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/) (Openshift Client)
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Azure Bastion

Please follow the official [Azure Bastion documentation](https://docs.microsoft.com/en-us/azure/bastion/tutorial-create-host-portal) for instructions on configuring this service.