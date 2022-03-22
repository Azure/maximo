# AutoOCP

## Updating cloud init file (Optional)

Modifying the cloud-init file will allow you to add additional customizations to your deployment that are not available in the `parameters.json` file.

After updating the cloud init file, you will need to turn it in a string to load into the `cloudInitData` variable inside of the jumpbox.bicep file. Prepare the string:

```bash
awk -v ORS='\\n' '1' cloud-init.yaml
```

After updating the parameter, you will need to escape the apostrophes in the string with a preceding `\'` .

## Preparing to deploy

You will need a public DNS Zone that can be accessed by the OpenShift installer. During deployment, you will be prompted for the following:

- Client Id
- Client Secret
- Password
- SSH Public Key
- OpenShift Pull Secret
- IBM Entitlement Key
- Resource Group where your public DNS Zone is located
- Domain Name used by your public DNS Zone
- Cluster Name
- Install MAS (y/n)
- Install OCS (y/n)
- Install CP4D (y/n)

The Domain Name must match the name of the DNS Zone that you will be using for OpenShift. During the deployment this DNS Zone will be updated with records to resolve to the cluster. If it is not accessible by the Client Id, the deployment will fail.

```bash
az group create --location "East US" --name OCP-Sidecar

az deployment group create --resource-group  OCP-Sidecar --template-file bootstrap.bicep --parameters parameters.json
```

After the deployment is finished, you can SSH into the JumpBoxVM and look in the directory: `/tmp/OCPInstall/QuickCluster` for install artifacts. For logs, you can look at: `cat /var/log/cloud-init-output.log`

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