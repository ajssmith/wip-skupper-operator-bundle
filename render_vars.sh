export PRODUCT_VERSION=2.0
export PRODUCT_VERSION_Z=0
export UPSTREAM_CLONE_URL=https://github.com/skupperproject/skupper.git
export UPSTREAM_CLONE_SHA=1d1366b566b3fbe9e37b7aa02c8c7d0825687b8b
export MANIFESTS_DIR="bundle/manifests"
export METADATA_DIR="bundle/metadata"
export PREVIOUS_RELEASES_DIR="previous-releases"
export REDHAT_REGISTRY="registry.redhat.io"
export DOWNSTREAM_PROJECT_NAME="rhsi"
export FULL_VERSION=2.0.0-rc1
export ERRATA_ID=145073

# The versioning scheme available in the openshift versions label accepts:
#     Min version (v4.6)
#     Range (v4.6-v4.8)
#     A specific version (=v4.7)
export SUPPORTED_OCP_VERSIONS="v4.12-v4.18"
export GOLANG_VERSION="1.22"
export OPERATOR_SDK_VERSION="1.35.0"
export BUNDLE_DEFAULT_CHANNEL="stable-2"
export BUNDLE_CHANNELS="stable-2,stable-v2.0"