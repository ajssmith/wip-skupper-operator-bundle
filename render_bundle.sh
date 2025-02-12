#!/bin/bash
#
# render_templates for the SKUPPER_OPERATOR component
#
set -e
set -x
set -u
set -o pipefail

source render_vars.sh
. scripts/read_var.sh

function error() {
  echo "$*"
  exit 1
}

function getImageSHA() {
    IMAGE="$1"
    docker image pull "${IMAGE}" > /dev/null 2>&1
    docker image inspect --format='{{index .RepoDigests 0}}' "${IMAGE}" || exit 1
}

function retrieveBrewBuilds() {
    read_var DATA_PLANE_TAG "Data plane version" true ""
    read_var CONTROL_PLANE_TAG "Control plane version" true ""
    echo
    echo Retrieving brewkoji builds
    echo
    if python scripts/get_image_builds.py --data-plane-tag "${DATA_PLANE_TAG}" --control-plane-tag "${CONTROL_PLANE_TAG}"; then
      echo
      echo Enter builds to use
      echo
      read_var ROUTER_BUILD "Skupper router build" false ""
      read_var CONTROLLER_BUILD "Controller build" false ""
      read_var KUBE_ADAPTOR_BUILD "Kube adaptor build" false ""
      read_var CLI_BUILD "CLI build" false ""
      read_var NETWORK_OBSERVER_BUILD "Network observer build" false ""
      getBrewImageSHAs
    else
      echo "Unable to list builds from brewkoji"
      read_var CONTINUESHA "Do you want to provide SHAs manually?" true "yes" "yes" "no"
      [[ "${CONTINUESHA,,}" = "no" ]] && exit 0
      echo
    fi
}

function getBrewImageSHAs() {
    echo
    echo "Retrieving image SHAs ..."
    python scripts/get_image_shas.py \
      --controller-build "${CONTROLLER_BUILD}" \
      --router-build "${ROUTER_BUILD}" \
      --kube-adaptor-build "${KUBE_ADAPTOR_BUILD}" \
      --cli-build "${CLI_BUILD}" \
      --network-observer-build "${NETWORK_OBSERVER_BUILD}" \
      > /tmp/imageshas.$$.json    

      SKUPPER_ROUTER_SHA=""
      CONTROLLER_SHA=""
      KUBE_ADAPTOR_SHA=""
      CLI_SHA=""
      NETWORK_OBSERVER_SHA=""

      [[ -n "${ROUTER_BUILD}" ]] && SKUPPER_ROUTER_SHA=$(jq -r ".\"${ROUTER_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${CONTROLLER_BUILD}" ]] && CONTROLLER_SHA=$(jq -r ".\"${CONTROLLER_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${KUBE_ADAPTOR_BUILD}" ]] && KUBE_ADAPTOR_SHA=$(jq -r ".\"${KUBE_ADAPTOR_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${CLI_BUILD}" ]] && CLI_SHA=$(jq -r ".\"${CLI_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${NETWORK_OBSERVER_BUILD}" ]] && NETWORK_OBSERVER_SHA=$(jq -r ".\"${NETWORK_OBSERVER_BUILD}\"" /tmp/imageshas.$$.json)
}

###############################################################################


TARGET_RELEASED_SKOPEO_PULLSPEC="docker://${REDHAT_REGISTRY}/${DOWNSTREAM_PRODUCT_NAME}/skupper-operator:v${PRODUCT_VERSION}"
PREVIOUS_EXISTS=$(skopeo inspect -n ${TARGET_RELEASED_SKOPEO_PULLSPEC} > /dev/null 2>&1 && echo "please" || echo "nope")
# Set the default channel if we are on an initial Y stream release
if [[ "nope" != "$PREVIOUS_EXISTS" ]]; then
  # A previous build does exist for this stream, so let's set the previous version
  export PREVIOUS_VERSION=$(skopeo inspect -n ${TARGET_RELEASED_SKOPEO_PULLSPEC} 2>/dev/null | jq -er '.Labels.csv-version')
else
  export PREVIOUS_VERSION=""
fi

export VERSION=${VERSION:-${PRODUCT_VERSION}}

# DEBUG
echo "*****************************************************"
echo "VERSION:                                          ${VERSION}"
echo "FULL_VERSION:                                     ${FULL_VERSION}"
echo "PREVIOUS_VERSION:                                 ${PREVIOUS_VERSION}"
echo "PRODUCT_VERSION:                                  ${PRODUCT_VERSION}"
echo "UPSTREAM_COMMIT:                                  ${UPSTREAM_COMMIT}"
echo "MANIFESTS_DIR:                                    ${MANIFESTS_DIR}"
echo "METADATA_DIR:                                     ${METADATA_DIR}"
echo "REDHAT_REGISTRY:                                  ${REDHAT_REGISTRY}"
echo "DOWNSTREAM_PRODUCT_NAME:                          ${DOWNSTREAM_PRODUCT_NAME}"
echo "SUPPORTED_OCP_VERSIONS:                           ${SUPPORTED_OCP_VERSIONS}"
echo "GOLANG_VERSION:                                   ${GOLANG_VERSION}"
echo "OPERATOR_SDK_VERSION:                             ${OPERATOR_SDK_VERSION}"
echo "BUNDLE_DEFAULT_CHANNEL:                           ${BUNDLE_DEFAULT_CHANNEL}"
echo "BUNDLE_CHANNELS:                                  ${BUNDLE_CHANNELS}"
echo "*****************************************************"

###############################################################################
###############################################################################
echo
echo Retrieving builds from Errata Advisory ...
echo
if python scripts/get_errata_image_builds.py --errata "${ERRATA_ID}" > /tmp/errata_builds.$$.json; then
  ROUTER_BUILD=$(jq -r '."skupper-router-container"' /tmp/errata_builds.$$.json)
  CONTROLLER_BUILD=$(jq -r '."skupper-controller-container"' /tmp/errata_builds.$$.json)
  KUBE_ADAPTOR_BUILD=$(jq -r '."skupper-kube-adaptor-container"' /tmp/errata_builds.$$.json)
  CLI_BUILD=$(jq -r '."skupper-cli-container"' /tmp/errata_builds.$$.json)
  NETWORK_OBSERVER_BUILD=$(jq -r '."skupper-network-observer-container"' /tmp/errata_builds.$$.json)
  getBrewImageSHAs
else
  echo "Unable to retrieve builds from errata tool"
  read_var CONTINUESHA "Do you want to provide brew builds manually?" true "yes" "yes" "no"
  [[ "${CONTINUESHA,,}" = "no" ]] && exit 0
  echo
  retrieveBrewBuilds
fi

if [[ -n "${CONTROLLER_SHA}" ]]; then
  export CONTROLLER_SHA
else
  error "Error retrieving controller image SHA"
fi
if [[ -n "${SKUPPER_ROUTER_SHA}" ]]; then
  export SKUPPER_ROUTER_SHA
else
  error "Error retrieving skupper-router image SHA"
fi
if [[ -n "${KUBE_ADAPTOR_SHA}" ]]; then
  export KUBE_ADAPTOR_SHA
else
  error "Error retrieving kube-adaptor image SHA"
fi
if [[ -n "${CLI_SHA}" ]]; then
  export CLI_SHA
else
  error "Error retrieving cli image SHA"
fi
if [[ -n "${NETWORK_OBSERVER_SHA}" ]]; then
  export NETWORK_OBSERVER_SHA
else
  error "Error retrieving network-observer image SHA"
fi

###############################################################################
for file in $(find ./config -name "*.yaml.in"); do
  echo "Processing file: $file"
  envsubst < ${file} > ${file%.in}
done

###############################################################################
rm -rf bundle
kubectl kustomize config/manifests | operator-sdk generate bundle -q --overwrite --version $FULL_VERSION --channels $BUNDLE_CHANNELS --default-channel $BUNDLE_DEFAULT_CHANNEL
mv bundle/manifests/skupper-operator.clusterserviceversion.yaml config/overlays/bases
kubectl kustomize config/overlays > bundle/manifests/skupper-operator.v${FULL_VERSION}.clusterserviceversion.yaml
operator-sdk bundle validate ./bundle

find ./config -name "*.yaml" -type f -delete

exit 0