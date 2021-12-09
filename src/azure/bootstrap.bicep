param location string
param networkInterfaceName string
param networkSecurityGroupName string
param networkSecurityGroupRules array
//param subnetName string
// param addressPrefixes array
// param subnets array
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
param domainName string
param clusterName string
param baseDomainResourceGroup string //used for ocp yaml config
param vnetName string
param vnetAddressPrefix string
param subnetControlNodePrefix string
param subnetControlNodeName string
param subnetWorkerNodePrefix string
param subnetWorkerNodeName string
param subnetEndpointsPrefix string
param subnetEndpointsName string
param storageNamePrefix string


//create dns zone
module dnsZone 'dns.bicep' = {
  name: 'DnsConfig'
  scope: resourceGroup('Domain')
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

//linux vm sidecar to deploy OCP
module sidecarVM 'sidecar.bicep' = {
  name: 'LinuxVM'
  scope: resourceGroup()
  params: {
    location: location
    networkInterfaceName: networkInterfaceName
    networkSecurityGroupName: networkSecurityGroupName
    networkSecurityGroupRules:networkSecurityGroupRules
    subnetName: subnetWorkerNodeName
    virtualNetworkName: vnetName
    publicIpAddressName: publicIpAddressName
    publicIpAddressType: publicIpAddressType
    publicIpAddressSku: publicIpAddressSku
    virtualMachineName: virtualMachineName
    virtualMachineComputerName: virtualMachineComputerName
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
  }
  dependsOn: [
    network
  ]
}

output adminUsername string = adminUsername
output adminPassword string = adminPassword
