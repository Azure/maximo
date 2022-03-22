# Setup OpenShift Container Platform on Azure

The installation of OpenShift on Azure can either be done using the [IPI Installer](https://docs.openshift.com/container-platform/4.8/installing/installing_azure/preparing-to-install-on-azure.html) or the [UPI Installer](https://github.com/openshift/installer/blob/master/docs/user/azure/install_upi.md).

> 💡 **NOTE**: For airgap scenarios, you will most likely need to use the UPI installer since the IPI installer cannot guarentee an airgapped install.

For the abbreviated install path, follow the guidance below.

## Getting Started
You will need to download the openshift installer to a linux machine. The installer can be found here: [OpenShift Installer Download](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/). You will need to unpack the installer: `tar xvf openshift-install-linux.tar.gz` and retreive a pull secret from the [OpenShift Console](https://console.redhat.com/openshift/install/pull-secret).

Next, you will need to create an `install-config.yaml` file to be used for your deployment. You can start from our existing file found [here](../../../src/ocp/install-config.yaml) or you can build your own from the [docs](https://docs.openshift.com/container-platform/4.8/installing/installing_azure/installing-azure-network-customizations.html#installation-azure-config-yaml_installing-azure-network-customizations).

Once this file has been created, you can execute the deployment:
```bash
#Everything in the /tmp directory will be purged upon reboot.
mkdir /tmp/OCPInstall/QuickCluster
wget -nv https://raw.githubusercontent.com/Azure/maximo/main/src/ocp/install-config.yaml -O /tmp/OCPInstall/QuickCluster/install-config.yaml
#You will need to customize your install-confi.yaml file before installing.
sudo openshift-install create cluster --dir=/tmp/OCPInstall/QuickCluster --log-level=info
```

After roughly 45 minutes, the cluster will come online and the console will provide details to connect to the cluster.

```bash
#Example
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/myuser/tmp/OCPInstall/QuickCluster/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.mycluster.example.com
INFO Login to the console with user: "xxxxxxxx", and password: "xxxxxxxxxxxxxxxxxx"
INFO Time elapsed: 36m22s
```

At this point, you can login and proceed to [installing the Azure Files CSI drivers](../../../README.md#azure-files-csi-drivers).