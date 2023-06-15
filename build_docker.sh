#!/usr/bin/env bash

# abort if any command fails
#set -e

function usage() {
    cat << EOF

Usage: $0 --set-version <image_version>

Example: $0 --set-version 1.0.0

EOF
}


while [[ $# > 1 ]]
    do
        key="$1"

        case ${key} in
            --set-version)
                VERSION="$2"
                shift
            ;;
            *)
                usage
                exit 1
            ;;
        esac
    shift
done

if [ -z "$VERSION" ]; then
    usage
    exit 1
fi

echo "BUILD IMAGE"
echo "Version $VERSION"
docker build --tag endevir/eproxy:${VERSION} .
docker push endevir/eproxy:${VERSION}
