#!/usr/bin/env bash

set -euo pipefail

ZNUNY_HOME=${ZNUNY_HOME:-/opt/otrs}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_DIR=${1:-$DEFAULT_PROJECT_DIR}
OUTPUT_DIR=${2:-/tmp}
PACKAGE_NAME=ZnunyAgentList
PACKAGE_VERSION=1.2.11

printf 'ZnunyAgentList package build helper\n'
printf 'This helper verifies source and builds an .opm only. It does not install,\n'
printf 'upgrade, uninstall, rebuild configuration, or clear cache.\n\n'

if ! PROJECT_DIR=$(CDPATH= cd -- "$PROJECT_DIR" && pwd); then
    printf 'ERROR: Project directory does not exist: %s\n' "${1:-$DEFAULT_PROJECT_DIR}" >&2
    exit 1
fi

if ! OUTPUT_DIR=$(CDPATH= cd -- "$OUTPUT_DIR" && pwd); then
    printf 'ERROR: Output directory does not exist: %s\n' "${2:-/tmp}" >&2
    exit 1
fi

SOPM_FILE="$PROJECT_DIR/$PACKAGE_NAME.sopm"
PACKAGE_FILE="$OUTPUT_DIR/$PACKAGE_NAME-$PACKAGE_VERSION.opm"

quote_arg() {
    printf '%q' "$1"
}

require_file() {
    if [ ! -f "$1" ]; then
        printf 'ERROR: Required file is missing: %s\n' "$1" >&2
        exit 1
    fi
}

require_otrs_readable_dir() {
    local path=$1
    local label=$2

    if ! su -s /bin/bash -c 'test -d "$1" && test -r "$1" && test -x "$1"' otrs bash "$path"; then
        printf 'ERROR: otrs user cannot read/search %s: %s\n' "$label" "$path" >&2
        exit 1
    fi
}

require_otrs_readable_file() {
    local path=$1
    local label=$2

    if ! su -s /bin/bash -c 'test -f "$1" && test -r "$1"' otrs bash "$path"; then
        printf 'ERROR: otrs user cannot read %s: %s\n' "$label" "$path" >&2
        exit 1
    fi
}

require_otrs_writable_dir() {
    local path=$1
    local label=$2

    if ! su -s /bin/bash -c 'test -d "$1" && test -w "$1"' otrs bash "$path"; then
        printf 'ERROR: otrs user cannot write to %s: %s\n' "$label" "$path" >&2
        exit 1
    fi
}

if [ ! -d "$ZNUNY_HOME" ]; then
    printf 'ERROR: Znuny home does not exist: %s\n' "$ZNUNY_HOME" >&2
    exit 1
fi

require_file "$SOPM_FILE"
require_file "$PROJECT_DIR/Kernel/GenericInterface/Operation/User/AgentList.pm"
require_file "$PROJECT_DIR/Kernel/Config/Files/XML/ZnunyAgentList.xml"

printf 'Verifying source tree...\n'
bash "$PROJECT_DIR/scripts/verify-source.sh"

require_otrs_readable_dir "$ZNUNY_HOME" 'Znuny home'
require_otrs_readable_dir "$PROJECT_DIR" 'project directory'
require_otrs_readable_file "$SOPM_FILE" 'SOPM file'
while IFS= read -r RuntimeFile; do
    require_otrs_readable_file "$RuntimeFile" 'runtime file'
done < <(
    find "$PROJECT_DIR/Kernel/GenericInterface/Operation" -type f -name '*.pm' -print
    printf '%s\n' "$PROJECT_DIR/Kernel/Config/Files/XML/ZnunyAgentList.xml"
)
require_otrs_writable_dir "$OUTPUT_DIR" 'output directory'

BUILD_COMMAND="cd $(quote_arg "$ZNUNY_HOME") && bin/otrs.Console.pl Dev::Package::Build --module-directory $(quote_arg "$PROJECT_DIR") $(quote_arg "$SOPM_FILE") $(quote_arg "$OUTPUT_DIR")"

printf 'Building package as otrs user with Dev::Package::Build...\n'
su -s /bin/bash -c "$BUILD_COMMAND" otrs

if [ ! -f "$PACKAGE_FILE" ]; then
    printf 'ERROR: Expected package was not created: %s\n' "$PACKAGE_FILE" >&2
    exit 1
fi

printf 'Package created: %s\n' "$PACKAGE_FILE"
printf 'This script did not install, upgrade, uninstall, rebuild configuration, or clear cache.\n'
