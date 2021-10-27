param domainName string


resource symbolicname 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: domainName
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}
