#!/bin/bash

echo "================ Install Manager START ================"

export KUBECONFIG=/tmp/OCPInstall/QuickCluster/auth/kubeconfig

\cp /tmp/OCPInstall/oc /usr/bin #overwrite existing version

#Install OCP
wget -nv "https://raw.githubusercontent.com/Azure/maximo/main/src/installers/ocp_setup.sh" -O /tmp/ocp_setup.sh
chmod +x /tmp/ocp_setup.sh
sudo -E /tmp/ocp_setup.sh

if [ "$installMAS" == "Y" ] || [ "$installMAS" == "Yes" ] || [ "$installMAS" == "y" ]
then
    #Deploy MAS
    wget -nv "https://raw.githubusercontent.com/Azure/maximo/main/src/installers/mas_deploy.sh" -O /tmp/mas_deploy.sh
    chmod +x /tmp/mas_deploy.sh
    sudo -E /tmp/mas_deploy.sh
fi

if [ "$installOCS" == "Y" ] || [ "$installOCS" == "Yes" ] || [ "$installOCS" == "y" ]
then
    #Deploy OCS
    wget -nv "https://raw.githubusercontent.com/Azure/maximo/main/src/installers/ocs_deploy.sh" -O /tmp/ocs_deploy.sh
    chmod +x /tmp/ocs_deploy.sh
    sudo -E /tmp/ocs_deploy.sh
fi

if [ "$installCP4D" == "Y" ] || [ "$installCP4D" == "Yes" ] || [ "$installCP4D" == "y" ]
then
    #Deploy CP4D
    wget -nv "https://raw.githubusercontent.com/Azure/maximo/main/src/installers/cp4d_deploy.sh" -O /tmp/cp4d_deploy.sh
    chmod +x /tmp/cp4d_deploy.sh
    sudo -E /tmp/cp4d_deploy.sh
fi


echo "================ Install Manager END ================"