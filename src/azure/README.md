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
- Install VI (y/n)

The Domain Name must match the name of the DNS Zone that you will be using for OpenShift. During the deployment this DNS Zone will be updated with records to resolve to the cluster. If it is not accessible by the Client Id, the deployment will fail.

```bash
az group create --location "North Europe" --name OCP-MAS-PREPROD-northeurope

az deployment group create --resource-group  OCP-MAS-PREPROD-northeurope --template-file bootstrap.bicep --parameters parameters.json
```

After the deployment is finished, you can SSH into the JumpBoxVM and look in the directory: `/tmp/OCPInstall/QuickCluster` for install artifacts. For logs, you can look at: `cat /var/log/cloud-init-output.log`

Alternatively you can deploy straight from this repository:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fmaximo%2Fmain%2Fsrc%2Fazure%2Fbootstrap.bicep)