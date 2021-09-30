# Maximo

This repository provides deployment guidance, scripts and best practices for running IBM Maximo 8.5.0 on OpenShift 4.8.10 using the Azure Cloud.

> [!NOTE]
> It is recommended to use a Linux or macOS system to complete the installation.

Before installing Maximo, the following __pre-reqs__ must be completed:
- Azure
    - Create an App Service Domain.
    - Create an Application Registration (SPN) with Contributor and User Access Administrator access on the Subscription you are intending to deploy into.
    - Deploy Azure Red Hat Openshift or OpenShift Container Platform.
        - OCP
            - Sign up for a trial at: https://try.openshift.com
            - Download the pull secret, install and client at: https://console.redhat.com/openshift/install/azure/installer-provisioned
        - ARO
            - TBD
    - Create an Azure Files Storage Account.
- OpenShift
    - Resize Worker Nodes to: Standard_D8s_v3 or simliar
    - Create Azure Files Storage Class
    - Install cert-manager
    - Install MongoDB Community Edition
    - Install Service Binding Operator
    - Install IBM Catalog Operator
    - Install IBM Behavior Analytics Service (BAS)
    - Install IBM License Service

After these services have been installed and configured, you can successfully install and configure Maximo Application Suite (MAS) on OpenShift running on Azure.

## Getting Started

### Installing Pre-Reqs
1. Please follow [this guide](/Azure/README.md) to configure Azure.
1. Please follow [this guide](/OCP/README.md) to configure OCP on Azure.
1. Please follow [this guide](/Applications/README.md) to install Maximo dependancies for Maximo.

Once you have configured the pre-reqs for Maximo you can follow these steps to deploy and configure a workspace.

1.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
