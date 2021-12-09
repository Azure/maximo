@description('Prefix name of your storage accounts')
param storageNamePrefix string = 'maximofiles'

@description('Location for all resources.')
param location string

// Details for private endpoints

@description('Azure Private Endpoints subnet name')
param subnetEndpointsName string = 'endpoints'

@description('Name of the VNet you are deployinh')
param vnetName string = 'maximo-vnet'

// Some variables to grab the details we need
var vnetId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks', vnetName)
var subnetReference = '${vnetId}/subnets/${subnetEndpointsName}'

// More performant and lower latency storage for databases, Kafka and 
// other resources.
resource storage_premium 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: take('${storageNamePrefix}prm${uniqueString(resourceGroup().id)}', 24)
  location: location
  kind: 'FileStorage'
  sku: {
    name: 'Premium_LRS'
  }
  properties: {
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
}

// Standard storage account for fileshares that are less performance hungry 
// and smaller. Costs for standard storage accounts are lower and there is 
// no minimum share size of 100GiB.
resource storage_standard 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: take('${storageNamePrefix}std${uniqueString(resourceGroup().id)}', 24)
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
}

// Endpoints

resource files_private_zone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
  properties: {}
}

resource files_private_zone_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${files_private_zone.name}/${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Premium endpoint 

resource premium_private_endpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'premiumstorage'
  location: location
  properties: {
    subnet: {
      id: subnetReference
    }
    privateLinkServiceConnections: [
      {
        properties: {
          privateLinkServiceId: storage_premium.id
          groupIds: [
            'file'
          ]
        }
        name: 'PremiumFilesEndpoint'
      }
    ]
  }
}

resource files_private_zone_group_premium 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${premium_private_endpoint.name}/dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'premium'
        properties: {
          privateDnsZoneId: files_private_zone.id
        }
      }
    ]
  }
}

// Standard endpoint

resource standard_private_endpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
  name: 'standardstorage'
  location: location
  properties: {
    subnet: {
      id: subnetReference
    }
    privateLinkServiceConnections: [
      {
        properties: {
          privateLinkServiceId: storage_standard.id
          groupIds: [
            'file'
          ]
        }
        name: 'StandardFilesEndpoint'
      }
    ]
  }
}
resource files_private_zone_group_standard 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${standard_private_endpoint.name}/dnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'standard'
        properties: {
          privateDnsZoneId: files_private_zone.id
        }
      }
    ]
  }
}
