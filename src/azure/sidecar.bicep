param location string
param networkInterfaceName string
param networkSecurityGroupName string
param networkSecurityGroupRules array
param subnetName string
param virtualNetworkName string
param addressPrefixes array
param subnets array
param publicIpAddressName string
param publicIpAddressType string
param publicIpAddressSku string
param virtualMachineName string
param virtualMachineComputerName string
param osDiskType string
param virtualMachineSize string
param adminUsername string
@secure()
param adminPassword string
param zone string
param applicationId string
@secure()
param applicationSecret string
param sshPubKey string
param pullSecret string
param entitlementKey string
param baseDomain string
param clusterName string
param baseDomainResourceGroup string


var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
var vnetId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
var subnetRef = '${vnetId}/subnets/${subnetName}'
var subscriptionId = subscription().subscriptionId
var tenantId = subscription().tenantId //tenantId() does not work
var cloudInitData = '#cloud-config\n\nruncmd:\n - mkdir /tmp/OCPInstall\n - mkdir ~/.azure/\n - echo \'{"subscriptionId":"${subscriptionId}","clientId":"${applicationId}","clientSecret":"${applicationSecret}","tenantId":"${tenantId}"}\' > ~/.azure/osServicePrincipal.json\n - [ wget, -nv, "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.6.48/openshift-install-linux.tar.gz", -O, /tmp/OCPInstall/openshift-install-linux.tar.gz ]\n - echo "ssh-rsa ${sshPubKey}" > /tmp/id_rsa\n - mkdir /tmp/OCPInstall/QuickCluster\n - tar xvf /tmp/OCPInstall/openshift-install-linux.tar.gz -C /tmp/OCPInstall\n - [ wget, -nv, "https://raw.githubusercontent.com/Azure/maximo/4.6/src/ocp/install-config.yaml", -O, /tmp/OCPInstall/install-config.yaml ]\n - |\n    export baseDomain="${baseDomain}"\n    export clusterName="${clusterName}"\n    export deployRegion="${location}"\n    export baseDomainResourceGroup="${baseDomainResourceGroup}"\n    export pullSecret=\'${pullSecret}\'\n    export sshPubKey="${sshPubKey}"\n    export ENTITLEMENT_KEY="${entitlementKey}"\n - envsubst < /tmp/OCPInstall/install-config.yaml > /tmp/OCPInstall/QuickCluster/install-config.yaml\n - sudo /tmp/OCPInstall/openshift-install create cluster --dir=/tmp/OCPInstall/QuickCluster --log-level=info\n - export clusterInstanceName=$(cat /tmp/OCPInstall/QuickCluster/metadata.json | jq -r .infraID)\n - [ wget, -nv, "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.6.48/openshift-client-linux.tar.gz", -O, /tmp/OCPInstall/openshift-client-linux.tar.gz ]\n - tar xvf /tmp/OCPInstall/openshift-client-linux.tar.gz -C /tmp/OCPInstall\n - export KUBECONFIG=/tmp/OCPInstall/QuickCluster/auth/kubeconfig\n - [ wget, -nv, "https://raw.githubusercontent.com/Azure/maximo/4.6/src/installers/ocp_setup.sh", -O, ocp_setup.sh ]\n - chmod +x ocp_setup.sh\n - sudo -E ./ocp_setup.sh\n - [ wget, -nv, "https://raw.githubusercontent.com/Azure/maximo/4.6/src/installers/mas_deploy.sh", -O, mas_deploy.sh ]\n - chmod +x mas_deploy.sh\n - sudo -E ./mas_deploy.sh\n'


resource networkInterfaceName_resource 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    networkSecurityGroupName_resource
    virtualNetworkName_resource
    publicIpAddressName_resource
  ]
}

resource networkSecurityGroupName_resource 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
  }
}

resource publicIpAddressName_resource 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
  sku: {
    name: publicIpAddressSku
  }
  zones: [
    zone
  ]
}

resource virtualMachineName_resource 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'RedHat'
        offer: 'RHEL'
        sku: '8_4'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceName_resource.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(cloudInitData)
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  zones: [
    zone
  ]
}

output adminUsername string = adminUsername
output adminPassword string = adminPassword
