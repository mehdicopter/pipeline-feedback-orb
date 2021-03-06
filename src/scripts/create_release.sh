#!/bin/bash

set -x
set -eo pipefail

function create_release() {
    missing_dependencies=false

    if ! which curl; then
        echo 'Missing dependency: The curl command is not available'
        missing_dependencies=true
    fi

    if ! which jq; then
        echo 'Missing dependency: The jq command is not available'
        missing_dependencies=true
    fi

    if [ ${missing_dependencies} == true ]; then
        echo 'Missing dependencies detected, aborting'
        exit 1
    fi

    if which envsubst; then
        release_name=$(echo "${INSTANA_RELEASE_NAME}" | envsubst)
    else
        echo 'The envsubst command is not available, skipping the interpolation of environment variables in the release name'

        release_name="${INSTANA_RELEASE_NAME}"
    fi

    echo "Creating release '${release_name}'"

    if [ -z "${INSTANA_RELEASE_SCOPE}" ]; then
        INSTANA_RELEASE_SCOPE='{}'
    fi

    echo "${INSTANA_RELEASE_SCOPE}" > scope.json

    if ! OUTPUT=$(jq empty scope.json 2>&1); then
        echo "Scope JSON is valid: ${OUTPUT}"
        exit 1
    fi

    curl --location --request POST "${!INSTANA_ENDPOINT_URL_NAME}/api/releases" \
        --silent \
        --fail \
        --show-error \
        --header "Authorization: apiToken ${!INSTANA_API_TOKEN_NAME}" \
        --header "Content-Type: application/json" \
        --data "{
    \"name\": \"${release_name}\",
    \"start\": $(date +%s)000,
    \"applications\": $(jq -r '.applications' < scope.json),
    \"services\": $(jq -r '.services' < scope.json)
}" | jq -r ".id" | xargs -I {} echo "New release created with id {}"
}

create_release