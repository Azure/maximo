@description('Name of the VNet you are deployinh')
param vnetName string = 'maximo-vnet'

@description('Total address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Control plane node prefix')
param subnetControlNodePrefix string = '10.0.0.0/24'

@description('Control plane subnet name')
param subnetControlNodeName string = 'control'

@description('Worker node prefix')
param subnetWorkerNodePrefix string = '10.0.2.0/23'

@description('Worker node subnet name')
param subnetWorkerNodeName string = 'workers'

@description('Azure Private Endpoints subnet prefix')
param subnetEndpointsPrefix string = '10.0.1.0/24'

@description('Azure Private Endpoints subnet name')
param subnetEndpointsName string = 'endpoints'

@description('Location for all resources.')
param location string = resourceGroup().location

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
