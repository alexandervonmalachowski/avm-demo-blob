#!/usr/bin/env sh
#
# Usage:
#     infrastructure/fe-create-environment.sh <environmentname> [<subscription>]
#     [<group_env>]
#
# Environment variable inputs.
# All of these have defaults
#     subscription
#     group_env  
#   
#
# Example:
#     infrastructure/fe-create-environment.sh unstable
#     infrastructure/fe-create-environment.sh dev
#     infrastructure/fe-create-environment.sh qa mr-creative-tech
#     infrastructure/fe-create-environment.sh prod mr-creative-tech

# Abort on failures
set -e

# Always run from `{scriptlocation}/..`, one level up from `infrastucture`. (frontend root)
cd "$(dirname "$0")/.."

# Input and variables
env=${1:?}
sub=${2:-'mr-creative-tech'}
group_env="rg-avmdemoblob-$env"


# Login to azure if required
if ! az account show > /dev/null
then
    echo "ABORTING: Azure login must be done before deployment"
    exit 1
fi
az account set --subscription "$sub" > /dev/null
echo "Subscription: $(az account show --query 'name' --output tsv)"
echo "ResourceGroup: $group_env"

# Create group if not existing
if ! az group show --name "$group_env" > /dev/null
then
    az group create --location 'westeurope' --name "$group_env"
fi

# Run commands for the creation template
# TODO: Use 'what-if' verification, when it works.
for cmd in 'validate' 'create'; do
    echo
    echo "$cmd..."
    az deployment group "$cmd" \
        --resource-group "$group_env" \
        --template-file infrastructure/blob-template-environment.bicep \
        --parameters "environmentName=$env" \
        --output table
done

echo
echo "Enable static website..."
az storage blob service-properties update \
    --static-website true \
    --404-document '404/index.html' \
    --index-document 'index.html' \
    --account-name "stavmdemoblob$env"

# Print success with endpoint
endpoint=$(
    az storage account show \
        --resource-group "$group_env" \
        --name "stavmdemoblob$env" \
        --query 'primaryEndpoints.web' \
        --output tsv
)

echo
echo "Sucessfully created environment"
echo "> $endpoint"
