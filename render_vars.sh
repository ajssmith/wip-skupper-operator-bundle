export PRODUCT_VERSION="2.0"
export UPSTREAM_COMMIT=1d1366b566b3fbe9e37b7aa02c8c7d0825687b8b
export MANIFESTS_DIR="bundle/manifests"
export METADATA_DIR="bundle/metadata"
export REDHAT_REGISTRY="registry.redhat.io"
export DOWNSTREAM_PRODUCT_NAME="service-interconnect"
export FULL_VERSION=2.0.0-rc1-rh-1
export REPLACED_VERSION=2.0.0-rc0-rh-1
export OLM_SKIP_RANGE=">2.0.0-rc0-rh-1 <2.0.0-rc1-rh-1"
export ERRATA_ID=145073

# The versioning scheme available in the openshift versions label accepts:
#     Min version (v4.6)
#     Range (v4.6-v4.8)
#     A specific version (=v4.7)
export MIN_KUBE_VERSION="1.25.0"
export SUPPORTED_OCP_VERSIONS="v4.12-v4.18"
export GOLANG_VERSION="1.22"
export OPERATOR_SDK_VERSION="1.35.0"
export BUNDLE_DEFAULT_CHANNEL="stable-2"
export BUNDLE_CHANNELS="stable-2,stable-v2.0"

