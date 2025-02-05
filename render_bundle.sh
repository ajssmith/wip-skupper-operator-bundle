#!/bin/bash
#
# render_templates for the SUBMARINER_OPERATOR component
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
      read_var NETWORK_OBSERVER_BUILD "Network observer build" false ""
      read_var CLI_BUILD "CLI build" false ""
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
      --network-observer-build "${NETWORK_OBSERVER_BUILD}" \
      --cli-build "${CLI_BUILD}" \
      > /tmp/imageshas.$$.json    

      SKUPPER_ROUTER_SHA=""
      CONTROLLER_SHA=""
      KUBE_ADAPTOR_SHA=""
      NETWORK_OBSERVER_SHA=""
      CLI_SHA=""

      [[ -n "${ROUTER_BUILD}" ]] && SKUPPER_ROUTER_SHA=$(jq -r ".\"${ROUTER_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${CONTROLLER_BUILD}" ]] && CONTROLLER_SHA=$(jq -r ".\"${CONTROLLER_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${KUBE_ADAPTOR_BUILD}" ]] && KUBE_ADAPTOR_SHA=$(jq -r ".\"${KUBE_ADAPTOR_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${NETWORK_OBSERVER_BUILD}" ]] && NETWORK_OBSERVER_SHA=$(jq -r ".\"${NETWORK_OBSERVER_BUILD}\"" /tmp/imageshas.$$.json)
      [[ -n "${CLI_BUILD}" ]] && CLI_SHA=$(jq -r ".\"${CLI_BUILD}\"" /tmp/imageshas.$$.json)
}

###############################################################################
###############################################################################

TARGET_RELEASED_SKOPEO_PULLSPEC="docker://${REDHAT_REGISTRY}/${DOWNSTREAM_PROJECT_NAME}/skupper-operator:v${PRODUCT_VERSION}"
PREVIOUS_EXISTS=$(skopeo inspect -n ${TARGET_RELEASED_SKOPEO_PULLSPEC} > /dev/null 2>&1 && echo "please" || echo "nope")
# Set the default channel if we are on an initial Y stream release
if [[ "nope" != "$PREVIOUS_EXISTS" ]]; then
  # A previous build does exist for this stream, so let's set the previous version
  export PREVIOUS_VERSION=$(skopeo inspect -n ${TARGET_RELEASED_SKOPEO_PULLSPEC} 2>/dev/null | jq -er '.Labels.csv-version')
else
  export PREVIOUS_VERSION=""
fi

export VERSION=${VERSION:-${PRODUCT_VERSION}}
if [ -d  "${PREVIOUS_RELEASES_DIR}" ]; then
  export PREVIOUS_VERSION=${PREVIOUS_VERSION:-$(ls "${PREVIOUS_RELEASES_DIR}" | grep -v -E 'dummy|'"${FULL_VERSION}" | sort -r --version-sort | head -n1)}
fi

# DEBUG
echo "*****************************************************"
echo "VERSION:                                          ${VERSION}"
echo "FULL_VERSION:                                     ${FULL_VERSION}"
echo "PREVIOUS_VERSION:                                 ${PREVIOUS_VERSION}"
echo "PRODUCT_VERSION:                                  ${PRODUCT_VERSION}"
echo "PRODUCT_VERSION_Z:                                ${PRODUCT_VERSION_Z}"
echo "UPSTREAM_CLONE_URL:                               ${UPSTREAM_CLONE_URL}"
echo "UPSTREAM_CLONE_SHA:                               ${UPSTREAM_CLONE_SHA}"
echo "MANIFESTS_DIR:                                    ${MANIFESTS_DIR}"
echo "METADATA_DIR:                                     ${METADATA_DIR}"
echo "PREVIOUS_RELEASES_DIR:                            ${PREVIOUS_RELEASES_DIR}"
echo "REDHAT_REGISTRY:                                  ${REDHAT_REGISTRY}"
echo "DOWNSTREAM_PROJECT_NAME:                          ${DOWNSTREAM_PROJECT_NAME}"
echo "SUPPORTED_OCP_VERSIONS:                           ${SUPPORTED_OCP_VERSIONS}"
echo "GOLANG_VERSION:                                   ${GOLANG_VERSION}"
echo "OPERATOR_SDK_VERSION:                             ${OPERATOR_SDK_VERSION}"
echo "BUNDLE_DEFAULT_CHANNEL:                           ${BUNDLE_DEFAULT_CHANNEL}"
echo "BUNDLE_CHANNELS:                                  ${BUNDLE_CHANNELS}"
echo "*****************************************************"

###############################################################################
###############################################################################
# Clone upstream repo 
git config --global core.sshCommand 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
rm -fr upstream
git clone "${UPSTREAM_CLONE_URL}" upstream
rc=$?
if [[ $rc -ne 0 ]]; then
   echo "ERROR: Could not clone upstream release repo."
   exit 2
fi
pushd upstream && git checkout "${UPSTREAM_CLONE_SHA}"
popd

# remove old
rm -rf config/crd
rm -rf config/rbac
rm -rf config/samples

# copy crd, rbac and samples config
cp -R upstream/config/crd config
cp -R upstream/config/rbac config
cp -R upstream/config/samples config

rm -Rf upstream

###############################################################################
###############################################################################
#source image-script.sh 
#ERRATA_ID=145073
echo
echo Retrieving builds from Errata Advisory ...
echo
if python scripts/get_errata_image_builds.py --errata "${ERRATA_ID}" > /tmp/errata_builds.$$.json; then
  ROUTER_BUILD=$(jq -r '."skupper-router-container"' /tmp/errata_builds.$$.json)
  CONTROLLER_BUILD=$(jq -r '."skupper-controller-container"' /tmp/errata_builds.$$.json)
  KUBE_ADAPTOR_BUILD=$(jq -r '."skupper-kube-adaptor-container"' /tmp/errata_builds.$$.json)
  NETWORK_OBSERVER_BUILD=$(jq -r '."skupper-network-observer-container"' /tmp/errata_builds.$$.json)
  CLI_BUILD=$(jq -r '."skupper-cli-container"' /tmp/errata_builds.$$.json)
  getBrewImageSHAs
else
  echo "Unable to retrieve builds from errata tool"
  read_var CONTINUESHA "Do you want to provide brew builds manually?" true "yes" "yes" "no"
  [[ "${CONTINUESHA,,}" = "no" ]] && exit 0
  echo
  retrieveBrewBuilds
fi

csv="config/manifests/patch-add-related-images.yaml"
if [[ -n "${CONTROLLER_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-controller-rhel9@).*#\1${CONTROLLER_SHA}#g" ${csv} || error "Error updating controller image SHA"
fi
if [[ -n "${SKUPPER_ROUTER_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-router-rhel9@).*#\1${SKUPPER_ROUTER_SHA}#g" ${csv} || error "Error updating skupper-router image SHA"
fi
if [[ -n "${KUBE_ADAPTOR_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-kube-adaptor-rhel9@).*#\1${KUBE_ADAPTOR_SHA}#g" ${csv} || error "Error updating kube-adaptor image SHA"
fi
if [[ -n "${NETWORK_OBSERVER_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-network-observer-rhel9@).*#\1${NETWORK_OBSERVER_SHA}#g" ${csv} || error "Error updating network-observer image SHA"
fi
if [[ -n "${CLI_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-cli-rhel9@).*#\1${CLI_SHA}#g" ${csv} || error "Error updating cli image SHA"
fi

deploy="config/manifests/patch-add-env-var-related-images.yaml"
if [[ -n "${SKUPPER_ROUTER_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-router-rhel9@).*#\1${SKUPPER_ROUTER_SHA}#g" ${deploy} || error "Error updating skupper-router image SHA"
fi
if [[ -n "${KUBE_ADAPTOR_SHA}" ]]; then
    sed -ri "s#(registry.redhat.io/service-interconnect/skupper-kube-adaptor-rhel9@).*#\1${KUBE_ADAPTOR_SHA}#g" ${deploy} || error "Error updating kube-adaptor image SHA"
fi

###############################################################################
###############################################################################
# Clean previous bundle
#VERSION=2.0.0-rc1
#CHANNELS="stable-2,stable-v2.0"
#DEFAULT_CHANNEL="stable-2"

rm -rf bundle
kubectl kustomize config/manifests | operator-sdk generate bundle -q --overwrite --version $FULL_VERSION --use-image-digests --channels $BUNDLE_CHANNELS --default-channel $BUNDLE_DEFAULT_CHANNEL
operator-sdk bundle validate ./bundle

exit 0