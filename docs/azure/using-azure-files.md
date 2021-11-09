# Azure Files CSI driver on OpenShift

You will need to create a YAML file and push it to OpenShift. This will pull a storage provisioner we have provided for you. For more details on the Azure Files CSI driver, check out the [driver GitHub repository](https://github.com/kubernetes-sigs/azurefile-csi-driver) and the documentation on [how this drivers integrates with AKS](https://docs.microsoft.com/en-us/azure/aks/azure-files-csi).

Go to the Azure Portal or use the azure CLI and provision an Azure Files instance in a resource group in the region where your OpenShift is deployed. You can [follow our documentation](https://docs.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-portal) on how to do so, but a quick way would be:

```bash
az storage account create \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --location $region \
    --kind StorageV2 \
    --sku Standard_LRS \
    --enable-large-file-share
```

Once you have an Azure Files share, open up your favorite text editor and create a file called `azure-files.yaml` with the contents below. Make sure to update `location` and `storageAccount` with the values you used (e.g. `eastus` and `mymaximostorage`).

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefiles-standard
provisioner: kubernetes.io/azure-file
parameters:
  skuName: Standard_LRS
  location: <region_of_your_file_share>
  storageAccount: <azure_file_share_name>
```

With the file ready, it is time to push it to OpenShift and add create permissions to the system:persistent-volume-binder role.

```bash

## Creating the storage class
oc apply -f https://raw.githubusercontent.com/Azure/maximo/main/src/StorageClasses/azure-files.yaml

# The azure files provisioner will create a storage account and grab its access key. However, it 
# can't store it inside OpenShift as a secret because it has no permission. The below fixes that.

oc policy add-role-to-user admin system:serviceaccount:kube-system:persistent-volume-binder -n default

You should now see the StorageClass in the OpenShift admin interface or by executing `oc get sc`. Output should look like this:

```bash
roeland@metanoia:~$ oc get sc
NAME                        PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
azurefiles-standard         kubernetes.io/azure-file   Delete          Immediate              false                  2d6h
managed-premium (default)   kubernetes.io/azure-disk   Delete          WaitForFirstConsumer   true                   2d7h
```

That was it. You can now use Azure Files in your YAML files by referring to the storageclass as `azurefiles`. For example:

```yaml
kafka:
  storage_class: azurefiles-standard
  storage_size: 5G
  zookeeper_storage_class: azurefiles-standard
  zookeeper_storage_size: 5G
```

## Using storage classes (no CSI)

In future OpenShift Container Platform versions, volumes provisioned using existing in-tree plug-ins are planned for migration to their equivalent CSI driver. It is recommended to use CSI whenever possible and avoid using the old storage classes.

If you prefer not to use a CSI driver, you can also follow the instructions in the [OpenShift documentation on setting up Azure Files](https://docs.openshift.com/container-platform/4.8/storage/persistent_storage/persistent-storage-azure-file.html).
