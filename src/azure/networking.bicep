@description('Name of the VNet you are deploying')
param vnetName string

@description('Total address prefix')
param vnetAddressPrefix string

@description('Control plane node prefix')
param subnetControlNodePrefix string

@description('Control plane subnet name')
param subnetControlNodeName string

@description('Worker node prefix')
param subnetWorkerNodePrefix string

@description('Worker node subnet name')
param subnetWorkerNodeName string

@description('Azure Private Endpoints subnet prefix')
param subnetEndpointsPrefix string

@description('Azure Private Endpoints subnet name')
param subnetEndpointsName string

@description('Location for all resources.')
param location string

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetControlNodeName
        properties: {
          addressPrefix: subnetControlNodePrefix
        }
      }
      {
        name: subnetWorkerNodeName
        properties: {
          addressPrefix: subnetWorkerNodePrefix
        }
      }
      {
        name: subnetEndpointsName
        properties: {
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          addressPrefix: subnetEndpointsPrefix
        }
      }
    ]
  }
}
