#!/usr/bin/env sh
#
# Usage:
#     infrastructure/fe-deploy-ci.sh <environmentname> [<subscription>] [<ad-client-id>]
#
#   The environment which should be deployed to must already exist.
#   It can be created with the `infrastucture/fe-create-environment.sh` script.
#
# Example:
#     infrastructure/fe-deploy-ci.sh unstable
#     infrastructure/fe-deploy-ci.sh dev
#     infrastructure/fe-deploy-ci.sh qa mr-creative-tech clientId
#     infrastructure/fe-deploy-ci.sh prod mr-creative-tech clientIdProd

# Abort on failures
set -e

# Always run from `{scriptlocation}/..`, one level up from `infrastucture`. (frontend root)
cd "$(dirname "$0")/.."

# Input and variables
env=${1:?}
sub=${2:-'mr-creative-tech'}
# client_id=${3:-'clientId'}
group_env="rg-avmdemoblob-${env}"
revision="$(git rev-parse HEAD)"

endpoint="https://stavmdemoblob${env}.z6.web.core.windows.net/"

# Verify git status, required since the hash is used as version
if [ "$(git status --short)" != '' ]; then
    git status
    echo
    echo "ABORTING: Deployment requries a clean git status..."
    exit 1
fi

# Verify that only accepted commits gets deployed to "higher" environments
case "$env" in
    prod)
        requiredBranch="prod-fe"
        requiredParent="qa-fe"
        ;;
    qa)
        requiredBranch="qa-fe"
        requiredParent="main"
        ;;
    dev)
        requiredBranch="main"
        requiredParent="*"
        ;;
esac

if [ "$env" != 'unstable' ]; then
    # Validate required branch tip
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$requiredBranch")" ] ; then
        echo "checkout is on 'origin/${requiredBranch}' tip"
    else
        echo "ABORTING: Deployments to '$env' environment MUST come from tip of 'origin/${requiredBranch}'"
        exit 1
    fi

    # Validate requried parent
    if [ "$requiredParent" = "*" ] ; then
        echo "required parent is '*', no valdiation required"
    else
        # Fetch first, to enable validation
        git fetch --quiet --depth=1 origin "$requiredParent"
        git log --oneline --decorate --graph --all
        git cat-file -p HEAD
        echo "validating parent 'origin/$requiredParent'"
        if ! git cat-file -p HEAD | grep "parent $(git rev-parse "origin/$requiredParent")" ; then
            echo "ABORTING: Deployments to '$env' environment MUST come from a MERGE commit beween ${requiredBranch} and ${requiredParent}"
            exit 1
        fi
    fi
fi

# Alias for running azure-cli in a container
alias az_cli_container='docker run -t --rm -v "${HOME}/.ssh:/root/.ssh" -v "${HOME}/.azure:/root/.azure" -w "/root/" mcr.microsoft.com/azure-cli:2.34.1'
alias az_cli_container_with_build='docker run -t --rm -v "${HOME}/.ssh:/root/.ssh" -v "${HOME}/.azure:/root/.azure" -v "${PWD}/out:/root/out" -w "/root/" mcr.microsoft.com/azure-cli:2.34.1'


# Print az cli version
az_cli_container az --version

# Login to azure if required
if ! az_cli_container az account show > /dev/null
then
    echo "ABORTING: Azure login must be done before deployment"
    exit 1
fi
az_cli_container az account set --subscription "$sub" > /dev/null
echo "Subscription: $(az_cli_container az account show --query 'name' --output tsv)"
echo "ResourceGroup: $group_env"

# Verify static website enabled
enabled=$(
    az_cli_container az storage blob service-properties show \
        --auth-mode login \
        --account-name "stavmdemoblob$env" \
        --query 'staticWebsite.enabled' \
    | tr -d '\r\n'
)
if [ "$enabled" != 'true' ]
then
    echo "ABORTING: az storage for 'stavmdemoblob$env' is not a static website"
    exit 1
fi

# Build
# echo ENVIRONMENT="$env"
# echo NEXT_PUBLIC_CLIENT_ID="$client_id"
# echo NEXT_PUBLIC_REDIRECT_URI="$endpoint"
# echo NEXT_PUBLIC_REVISION="$revision"

# rm -rf out
# yarn install --immutable --immutable-cache
# ENVIRONMENT="$env" \
# NEXT_PUBLIC_CLIENT_ID="$client_id" \
# NEXT_PUBLIC_REDIRECT_URI="$endpoint" \
# NEXT_PUBLIC_REVISION="$revision" \
#     yarn run static

# Upload
az_cli_container_with_build az storage blob upload-batch \
    --account-name "stavmdemoblob$env"  \
    --auth-mode key \
    --source ./out \
    --destination '$web' \
    --pattern '*' \
    --output table \
    --overwrite true

# Print success with endpoint
echo
echo "Sucessfully deployed to environment"
echo "> $endpoint"
