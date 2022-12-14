param environmentName string = 'dev'

var storageAccountName = 'stavmdemoblob${environmentName}'
var cdnProfileName = 'cdn-avmdemoblob-${environmentName}'
var cdnEndpointName = 'avmdemoblob-${environmentName}'
param rgLocation string = resourceGroup().location


resource storageAccountName_resource 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: storageAccountName
  location: rgLocation
  sku: {
    name: 'Standard_RAGRS'  
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource storageAccountName_default 'Microsoft.Storage/storageAccounts/blobServices@2021-01-01' = {
  parent: storageAccountName_resource
  name: 'default' 
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource storageAccountName_default_web 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-01-01' = {
  parent: storageAccountName_default
  name: '$web'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  }  
}

resource cdnProfileName_resource 'Microsoft.Cdn/profiles@2020-04-15' = if (contains([
  'qa'
  'prod'
], environmentName)) {
  name: cdnProfileName
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }
  properties: {}
}

resource cdnProfileName_cdnEndpointName 'Microsoft.Cdn/profiles/endpoints@2020-04-15' = if (contains([
  'qa'
  'prod'
], environmentName)) {
  parent: cdnProfileName_resource
  name: cdnEndpointName
  location: 'Global'
  properties: {
    isHttpAllowed: true
    isHttpsAllowed: true
    originHostHeader: '${storageAccountName}.z6.web.core.windows.net'
    origins: [
      {
        name: '${storageAccountName}-z6-web-core-windows-net'
        properties: {
          hostName: '${storageAccountName}.z6.web.core.windows.net'
          httpPort: 80
          httpsPort: 443
          originHostHeader: '${storageAccountName}.z6.web.core.windows.net'
          priority: 1
          weight: 1000
          enabled: true
        }
      }
    ]
    isCompressionEnabled: true
    contentTypesToCompress: [
      'application/eot'
      'application/font'
      'application/font-sfnt'
      'application/javascript'
      'application/json'
      'application/opentype'
      'application/otf'
      'application/pkcs7-mime'
      'application/truetype'
      'application/ttf'
      'application/vnd.ms-fontobject'
      'application/xhtml+xml'
      'application/xml'
      'application/xml+rss'
      'application/x-font-opentype'
      'application/x-font-truetype'
      'application/x-font-ttf'
      'application/x-httpd-cgi'
      'application/x-javascript'
      'application/x-mpegurl'
      'application/x-opentype'
      'application/x-otf'
      'application/x-perl'
      'application/x-ttf'
      'font/eot'
      'font/ttf'
      'font/otf'
      'font/opentype'
      'image/svg+xml'
      'text/css'
      'text/csv'
      'text/html'
      'text/javascript'
      'text/js'
      'text/plain'
      'text/richtext'
      'text/tab-separated-values'
      'text/xml'
      'text/x-script'
      'text/x-component'
      'text/x-java-source'
    ]
  }
}

resource cdnProfileName_cdnEndpointName_qatestathome_inter_ikea_net 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = if ('qa' == environmentName) {
  parent: cdnProfileName_cdnEndpointName
  name: 'qaavmdemoblob-inter-ikea-net'
  properties: {
    hostName: 'qaavmdemoblob.inter.ikea.net'
  }
 
}

resource cdnProfileName_cdnEndpointName_testathome_inter_ikea_net 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = if ('prod' == environmentName) {
  parent: cdnProfileName_cdnEndpointName
  name: 'avmdemoblob-inter-ikea-net'
  properties: {
    hostName: 'avmdemoblob.inter.ikea.net'
  }  
}

output endpoint string = storageAccountName_resource.properties.primaryEndpoints.web
