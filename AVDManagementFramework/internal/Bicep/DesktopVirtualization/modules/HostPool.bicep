param HostPoolName string
param Location string
param PoolType string
param maxSessionLimit int
param Tags object = {}
param SessionHostJoinType string


param TokenExpirationTime string = dateTimeAdd(utcNow('O'),'PT2H','O')

var loadBalancerType = (PoolType == 'Personal') ? 'Persistent' : 'BreadthFirst'
var hostPoolType = (PoolType == 'Personal') ? 'Personal' : 'Pooled'


resource HostPool 'Microsoft.DesktopVirtualization/hostPools@2021-02-01-preview' = {
  name: HostPoolName
  location: Location
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: maxSessionLimit
    validationEnvironment: false // TODO: Decide on validation environment from stage
    registrationInfo: {
      registrationTokenOperation: 'Update'
      expirationTime: TokenExpirationTime
    }
    customRdpProperty: (SessionHostJoinType == 'AAD') ?  'targetisaadjoined:i:1;enablerdsaadauth:i:1' : null
  }
  tags:Tags
}

output registrationToken string = HostPool.properties.registrationInfo.token //TODO: set this as a secure string
