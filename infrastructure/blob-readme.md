# Infrastructure FE

Setting up infrastructure for the project.

Should use the [azure best practice naming convention](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)

Remember to give your App registration (Security Group) at least Contritubor rights on your Azure Subscription.

## Azure CLI

```sh
# Login
az login

# Verify account
az account show

# Set default subscription, if not already correct
az account set --subscription mr-creative-tech

# Logout
az account clear
```

## Azure Resource Manager - IaC

The frontend uses a mix of ARM templates and azure cli commands for setup. And only cli commands for deployments.

Each environment is deployed separately to its own resource group, which contains everything required.

### Environment names and resource group creation

```sh
export env='unstable'
export group_env="rg-avmdemoblob-$env"
az group create --location 'westeurope' --name $group_env
```

### Environment setup

Run example commands in `infrastructure/create-environment.sh`.

In some cases your local environment might change permissions on the deplo-ci.sh script. in case that happens just run:

```sh
# run this localy in a terminal
git update-index --chmod=+x ./deploy-ci.sh
```

```sh
# Show deployment output, again after activation
az deployment group show -g "$group_env" -n fe-template-environment --query 'properties.outputs'
```

```sh
# (Optional) Inspect resource
az storage blob service-properties show --account-name "avmdemoblob$env"
az resource show \
    --resource-group "$group_env" \
    --resource-type 'Microsoft.Storage/storageAccounts' \
    --name "stavmdemoblob$env"
```

### Deployment

1. Create PR main into {qa / prod}-be branch.
2. Deploy to {qa / prod} using script in `infrastructure/deploy.sh`.
3. Purge cache.

## Add/Update Azure credentials for github actions.

Read this: https://about-azure.com/deploying-to-azure-using-github-actions/ to get an understanding of how this works. However do not follow the steps simply add the folowing json to AZURE_CREDENTIALS in github secretes.

```json
{
  "clientId": "<Client ID of the app registtration you are using>",
  "clientSecret": "<Client secret that you genertate inside the app registration>",
  "subscriptionId": "<Subscription ID of the targeted subscription>",
  "tenantId": "Tenant ID i.e id of the azure AD",
  "activeDirectoryEndpointUrl": "https://login.microsoft.com/",
  "resourceManagementEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```
