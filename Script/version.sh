# Copyright 2021 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it.

#!/usr/bin/env bash

set -e

if which jq >/dev/null; then
    echo "jq is installed"
else
    echo "error: jq not installed.(brew install jq)"
fi

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

echo "Target version - ${BLUE}$1${NC}"
echo "------------------AEPEdgeConsent-------------------"
PODSPEC_VERSION_IN_AEPEdgeConsent=$(pod ipc spec AEPEdgeConsent.podspec | jq '.version' | tr -d '"')
echo "Local podspec version - ${BLUE}${PODSPEC_VERSION_IN_AEPEdgeConsent}${NC}"
SOUCE_CODE_VERSION_IN_AEPEdgeConsent=$(cat ./Sources/ConsentConstants.swift | egrep '\s*EXTENSION_VERSION\s*=\s*\"(.*)\"' | ruby -e "puts gets.scan(/\"(.*)\"/)[0] " | tr -d '"')
echo "Souce code version - ${BLUE}${SOUCE_CODE_VERSION_IN_AEPEdgeConsent}${NC}"

if [[ "$1" == "$PODSPEC_VERSION_IN_AEPEdgeConsent" ]] && [[ "$1" == "$SOUCE_CODE_VERSION_IN_AEPEdgeConsent" ]]; then
    echo "${GREEN}Pass!${NC}"
else
    echo "${RED}[Error]${NC} Version do not match!"
    exit -1
fi
exit 0
