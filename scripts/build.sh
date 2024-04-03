#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDERDIR="$(cd "${PROGDIR}/.." && pwd)"
readonly LOCAL_REGISTRY_NAME="builder_test_registry"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROGDIR}/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROGDIR}/.util/print.sh"

function main() {
  local name token
  token=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      --name|-n)
        name="${2}"
        shift 2
        ;;

      --token|-t)
        token="${2}"
        shift 2
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  if [[ -z "${name:-}" ]]; then
    name="testbuilder"
  fi

  # tools::install "${token}"
  if [[ ! -f "${BUILDERDIR}/.bin/pack" ]]; then
    experimental::pack::install
  fi


  # Do not rebuild the builder if it already exists on the local registry
  if [[  -z $(docker ps -aqf "name=${LOCAL_REGISTRY_NAME}") ]]; then
    local_registry::run >/dev/null
  else
    echo "Local registry named ${LOCAL_REGISTRY_NAME} is already running"
    registry_images=$(curl -X GET "localhost:5000/v2/_catalog" | jq -r '.repositories')
    if echo "${registry_images}" | grep -q "${name}"; then
      echo "A builder image named localhost:5000/${name} on the local registry already exists"
      exit 0
    fi
  fi

  name="localhost:5000/${name}"
  builder::create "${name}"
}

function usage() {
  cat <<-USAGE
build.sh [OPTIONS]

Builds the multi-arch builder using a local docker registry

OPTIONS
  --help        -h         prints the command usage
  --name <name> -n <name>  sets the name of the builder that is built
  --token <token>          Token used to download assets from GitHub (e.g. jam, pack, etc) (optional)
USAGE
}

function tools::install() {
  local token
  token="${1}"

  util::tools::pack::install \
    --directory "${BUILDERDIR}/.bin" \
    --token "${token}"
}

# TODO: when an official pack release comes out that supports multi-arch, use that
#  Until then, use an experimental pack version we've saved in experimental-pack-binaries temporarily
function experimental::pack::install() {
  echo "Installing pack experimental"

  os=$(util::tools::os)
  arch=$(util::tools::arch)
  mkdir -p "${BUILDERDIR}/.bin"
  binary_dir="${BUILDERDIR}/experimental-pack-binaries"

  if ! test -f "${binary_dir}/pack-${arch}-${os}"; then
    echo "An experimental pack binary for ${arch} ${os} is not available."
    exit 1
  fi

  cp "${binary_dir}/pack-${arch}-${os}" "${BUILDERDIR}/.bin/pack"
  "${BUILDERDIR}/.bin/pack" version
}

function local_registry::run() {
  docker run --rm -d -p 5000:5000 --name "builder_test_registry" "registry:2.7"
}

function builder::create() {
  local name
  name="${1}"

  util::print::title "Creating builder..."
  # TODO: when a regular pack release is out, revert this to `pack`
  "${BUILDERDIR}"/.bin/pack builder create "${name}" --config "${BUILDERDIR}/builder.toml" --publish
}

main "${@:-}"
