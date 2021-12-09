# AutoOCP

### Updating cloud init file

After updating the cloud init file, you will need to turn it in a string to load into the `cloudInitData` variable inside of the sidecar.bicep file. Prepare the string:

```bash
awk -v ORS='\\n' '1' cloud-init.yaml
```

### Preparing to deploy

You will need a DNS Zone that can be accessed by the openshift installer. During deployment, you will be prompted for the following:

- Client Id
- Client Secret
- Password
- SSH Public Key
- OpenShift Pull Secret
- IBM Entitlement Key
- Domain Name
- Cluster Name

The Domain Name should match the name of the DNS Zone that you will be using for OpenShift. During the deployment this DNS Zone will be updated with records to resolve to the cluster. If it is not accessible, the deplyment will fail.

```bash
az group create --location "East US" --name OCP-Sidecar

az deployment group create --resource-group  OCP-Sidecar --template-file bootstrap.bicep --parameters parameters.json
```

After the deployment is finished, you can SSH into the BootstrapVM and look in the directory: `/tmp/OCPInstall/QuickCluster` for install artifacts. For logs, you can look at: `cat /var/log/cloud-init-output.log`