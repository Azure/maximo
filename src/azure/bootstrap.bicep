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
param domainName string
param clusterName string
param baseDomainResourceGroup string //used for ocp yaml config


//create dns zone
module firstStorageAcct 'dns.bicep' = {
  name: 'DnsConfig'
  scope: resourceGroup('Domain')
  params: {
    domainName: domainName
  }
}

//linux vm sidecar to deploy OCP
module secondStorageAcct 'sidecar.bicep' = {
  name: 'LinuxVM'
  scope: resourceGroup()
  params: {
    location: location
    networkInterfaceName: networkInterfaceName
    networkSecurityGroupName: networkSecurityGroupName
    networkSecurityGroupRules:networkSecurityGroupRules
    subnetName: subnetName
    virtualNetworkName: virtualNetworkName
    addressPrefixes: addressPrefixes
    subnets: subnets
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
  }
}

output adminUsername string = adminUsername
output adminPassword string = adminPassword
