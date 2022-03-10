param location string
// param networkInterfaceName string
// param networkSecurityGroupName string
param networkSecurityGroupRules array
//param subnetName string
// param addressPrefixes array
// param subnets array
// param publicIpAddressName string
// param publicIpAddressType string
// param publicIpAddressSku string
param virtualMachineName string
//param virtualMachineComputerName string
param osDiskType string
param virtualMachineSize string
param adminUsername string
@secure()
param adminPassword string
param zone string
@description('Resource Group Name where Public DNS Zone exists')
param baseDomainResourceGroup string //used for ocp yaml config
param domainName string
param clusterName string
param customInstallConfigURL string
param installMAS string
param installOCS string
param installCP4D string
param applicationId string
@secure()
param applicationSecret string
param sshPubKey string
param pullSecret string
param entitlementKey string
param vnetName string
param vnetAddressPrefix string
param subnetControlNodePrefix string
param subnetControlNodeName string
param subnetWorkerNodePrefix string
param subnetWorkerNodeName string
param subnetEndpointsPrefix string
param subnetEndpointsName string
param storageNamePrefix string
param subnetBastionPrefix string
param subnetBastionName string
param bastionHostName string
param controlMachineSize string
param workerMachineSize string
param numControlReplicas string
param numWorkerReplicas string
param openshiftVersion string
param azureFilesCSIVersion string
param masChannel string

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
    location: location

  }
}

module premiumStorage 'storage.bicep' = {
  name: 'privateStorage'
  scope: resourceGroup()
  params: {
    storageNamePrefix: storageNamePrefix
    subnetEndpointsName: subnetEndpointsName
    vnetName: vnetName
    location: location
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
    location: location
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
    location: location
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
    openshiftVersion: openshiftVersion
    azureFilesCSIVersion: azureFilesCSIVersion
    masChannel: masChannel
  }
  dependsOn: [
    network
  ]
}

//output adminUsername string = adminUsername
//output adminPassword string = adminPassword
