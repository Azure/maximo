
param region string = resourceGroup().location
// param networkInterfaceName string
// param networkSecurityGroupName string
var networkSecurityGroupRules = [
  {
    'name': 'SSH'
    'properties': {
        'priority': 300
        'protocol': 'TCP'
        'access': 'Allow'
        'direction': 'Inbound'
        'sourceAddressPrefix': '*'
        'sourcePortRange': '*'
        'destinationAddressPrefix': '*'
        'destinationPortRange': '22'
      }
  }
]
//param subnetName string
// param addressPrefixes array
// param subnets array
// param publicIpAddressName string
// param publicIpAddressType string
// param publicIpAddressSku string
@description('Name of the JumpBox that will deploy the OpenShift installer.')
param virtualMachineName string
//param virtualMachineComputerName string
var osDiskType = 'Premium_LRS'
param virtualMachineSize string = 'Standard_B2ms'
@description('Admin username for the JumpBox')
param adminUsername string = 'azureuser'
@secure()
@description('Admin password for the JumpBox')
param adminPassword string
var zone = '1'
@description('Resource Group Name where Public DNS Zone exists')
param baseDomainResourceGroup string //used for ocp yaml config
@description('Domain Name of your Public DNS Zone. For Example: contoso.com')
param domainName string
@description('Name of the OpenShift cluster')
param clusterName string
@description('You can optionally replace the install-config.yaml with a custom version by providing the full URL to the file')
param customInstallConfigURL string
@allowed([
  'Yes'
  'No'
])
param installMAS string = 'Yes'
@allowed([
  'Yes'
  'No'
])
param installOCS string = 'Yes'
@allowed([
  'Yes'
  'No'
])
param installCP4D string = 'Yes'
@allowed([
  'Yes'
  'No'
])
param installVI string = 'Yes'
@description('Client Id of the application registration that has at least Contributor and User Access Administrator access on the subscription')
param applicationId string
@description('Secret for the Client Id provided above.')
@secure()
param applicationSecret string
@description('SSH Public key that can be used to connect to the OpenShift nodes')
param sshPubKey string
@description('Pull Secret for the OpenShift cluster to pull images from the RedHat registry')
param pullSecret string
@description('IBM Entitlement Key used to pull images from the IBM registry')
param entitlementKey string
@description('Virtual network name to be created')
param vnetName string = 'maximo-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param subnetControlNodePrefix string = '10.0.0.0/24'
@description('Name of the subnet where the management nodes will be deployed')
param subnetControlNodeName string = 'control'
param subnetWorkerNodePrefix string = '10.0.2.0/23'
@description('Name of the subnet where the worker nodes will be deployed')
param subnetWorkerNodeName string = 'workers'
param subnetEndpointsPrefix string = '10.0.1.0/24'
@description('Name of the subnet where the private endpoints will be deployed')
param subnetEndpointsName string = 'endpoints'
@description('Prefix for the storage accounts')
param storageNamePrefix string = 'maximofiles'
param subnetBastionPrefix string = '10.0.4.0/27'
@description('Do not change the Subnet name for the Bastion host')
param subnetBastionName string = 'AzureBastionSubnet'
@description('Name of the Bastion host')
param bastionHostName string = 'maximoBastionHost'
@description('VM Size for the management nodes')
param controlMachineSize string = 'Standard_D8s_v3'
@description('VM Size for the worker nodes')
param workerMachineSize string = 'Standard_D8s_v3'
@description('Number of management nodes')
@minValue(3)
param numControlReplicas int = 3
@description('Number of worker nodes')
param numWorkerReplicas int = 9
@description('Version of OpenShift to deploy')
var openshiftVersion = '4.8.22'
@description('Version of Azure CSI drivers to install')
var azureFilesCSIVersion = 'v1.12.0'
@description('MAS Channel to deploy from')
var masChannel = '8.7.x'
@description('NVidia Channel to deploy from')
var nvidiaOperatorChannel = 'v1.9.0'
var nvidiaOperatorCSV = 'gpu-operator-certified.v1.9.1'
@description('Branch name where scripts are pulled from')
var branchName = 'main'

//create dns zone
module dnsZone 'dns.bicep' = {
  name: 'DnsConfig'
  scope: resourceGroup(baseDomainResourceGroup)
  params: {
    domainName: domainName
  }
}

module network 'networking.bicep' = {
  name: 'VNet'
  scope: resourceGroup()
  params: {
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetControlNodePrefix: subnetControlNodePrefix
    subnetControlNodeName: subnetControlNodeName
    subnetWorkerNodePrefix: subnetWorkerNodePrefix
    subnetWorkerNodeName: subnetWorkerNodeName
    subnetEndpointsPrefix: subnetEndpointsPrefix
    subnetEndpointsName: subnetEndpointsName
    location: region

  }
}

module premiumStorage 'storage.bicep' = {
  name: 'privateStorage'
  scope: resourceGroup()
  params: {
    storageNamePrefix: storageNamePrefix
    subnetEndpointsName: subnetEndpointsName
    vnetName: vnetName
    location: region
  }
  dependsOn:[
    network
  ]
}

module bastionHost 'bastion.bicep' = {
  name: 'bastionHost'
  scope: resourceGroup()
  params: {
    subnetBastionName: subnetBastionName
    subnetBastionPrefix: subnetBastionPrefix
    bastionHostName: bastionHostName
    vnetName: vnetName
    location: region
  }
  dependsOn:[
    network
  ]
}

//linux vm sidecar to deploy OCP
module sidecarVM 'jumpbox.bicep' = {
  name: 'LinuxVM'
  scope: resourceGroup()
  params: {
    location: region
    networkInterfaceName: '${virtualMachineName}-nic'
    networkSecurityGroupName: '${virtualMachineName}-nsg'
    networkSecurityGroupRules:networkSecurityGroupRules
    subnetName: subnetWorkerNodeName
    virtualNetworkName: vnetName
    // publicIpAddressName: publicIpAddressName
    // publicIpAddressType: publicIpAddressType
    // publicIpAddressSku: publicIpAddressSku
    virtualMachineName: virtualMachineName
    osDiskType: osDiskType
    virtualMachineSize: virtualMachineSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    zone: zone
    applicationId: applicationId
    applicationSecret: applicationSecret
    sshPubKey: sshPubKey
    pullSecret: pullSecret
    entitlementKey: entitlementKey
    baseDomain: domainName
    clusterName: clusterName
    baseDomainResourceGroup: baseDomainResourceGroup
    vnetName: vnetName
    subnetControlNodeName: subnetControlNodeName
    subnetWorkerNodeName: subnetWorkerNodeName
    subnetEndpointsName: subnetEndpointsName
    controlMachineSize: controlMachineSize
    workerMachineSize: workerMachineSize
    numControlReplicas: numControlReplicas
    numWorkerReplicas: numWorkerReplicas
    customInstallConfigURL: customInstallConfigURL
    installMAS: installMAS
    installOCS: installOCS
    installCP4D: installCP4D
    installVI: installVI
    openshiftVersion: openshiftVersion
    azureFilesCSIVersion: azureFilesCSIVersion
    masChannel: masChannel
    nvidiaOperatorChannel: nvidiaOperatorChannel
    nvidiaOperatorCSV: nvidiaOperatorCSV
    branchName: branchName
  }
  dependsOn: [
    network
  ]
}

//output adminUsername string = adminUsername
//output adminPassword string = adminPassword
