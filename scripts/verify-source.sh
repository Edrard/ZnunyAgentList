#!/usr/bin/env bash

set -euo pipefail

ERRORS=0

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd) || exit 1

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    ERRORS=$((ERRORS + 1))
    printf 'ERROR: %s\n' "$1"
}

require_file() {
    if [ -f "$ROOT/$1" ]; then
        pass "Required file exists: $1"
    else
        fail "Required file is missing: $1"
    fi
}

xpath_text() {
    xmllint --xpath "string($1)" "$2" 2>/dev/null
}

xpath_count() {
    xmllint --xpath "count($1)" "$2" 2>/dev/null
}

printf 'ZnunyAgentList source verification\n'
printf 'Repository root: %s\n\n' "$ROOT"
printf 'This script performs read-only source checks. It does not build, install,\n'
printf 'uninstall, rebuild configuration, clear cache, or call the REST endpoint.\n\n'

require_file '.gitignore'
require_file 'CHANGES.md'
require_file 'LICENSE'
require_file 'README.md'
require_file 'ZnunyAgentList.sopm'
require_file 'Kernel/Config/Files/XML/ZnunyAgentList.xml'
require_file 'Kernel/GenericInterface/Operation/User/AgentList.pm'
require_file 'scripts/verify-source.sh'
require_file 'scripts/build-package.sh'

if ! command -v xmllint >/dev/null 2>&1; then
    fail 'xmllint is required for XML checks. Install the Rocky Linux libxml2 package or run XML validation manually.'
else
    SOPM="$ROOT/ZnunyAgentList.sopm"
    CONFIG_XML="$ROOT/Kernel/Config/Files/XML/ZnunyAgentList.xml"

    if xmllint --noout "$SOPM" >/dev/null 2>&1; then
        pass 'SOPM XML parses successfully'
    else
        fail 'SOPM XML does not parse'
    fi

    if [ "$(xpath_text '/otrs_package/Name' "$SOPM")" = 'ZnunyAgentList' ]; then
        pass 'SOPM package name is ZnunyAgentList'
    else
        fail 'Unexpected SOPM package name'
    fi

    if [ "$(xpath_text '/otrs_package/Version' "$SOPM")" = '1.0.0' ]; then
        pass 'SOPM version is 1.0.0'
    else
        fail 'Unexpected SOPM version'
    fi

    FILE_COUNT=$(xpath_count '/otrs_package/Filelist/File' "$SOPM")
    if [ "$FILE_COUNT" = '2' ]; then
        pass 'SOPM contains exactly two installed files'
    else
        fail "SOPM installed file count is $FILE_COUNT, expected 2"
    fi

    for LOCATION in \
        'Kernel/GenericInterface/Operation/User/AgentList.pm' \
        'Kernel/Config/Files/XML/ZnunyAgentList.xml'
    do
        COUNT=$(xmllint --xpath "count(/otrs_package/Filelist/File[@Location='$LOCATION'])" "$SOPM" 2>/dev/null)
        if [ "$COUNT" = '1' ]; then
            pass "SOPM installs expected file: $LOCATION"
        else
            fail "SOPM does not install expected file exactly once: $LOCATION"
        fi
    done

    PROHIBITED_COUNT=$(xmllint --xpath "count(/otrs_package/Filelist/File[starts-with(@Location,'scripts/') or starts-with(@Location,'dist/') or starts-with(@Location,'.git')])" "$SOPM" 2>/dev/null)
    if [ "$PROHIBITED_COUNT" = '0' ]; then
        pass 'SOPM does not install scripts, dist, or .git paths'
    else
        fail 'SOPM installs scripts, dist, or .git paths'
    fi

    if xmllint --noout "$CONFIG_XML" >/dev/null 2>&1; then
        pass 'SysConfig XML parses successfully'
    else
        fail 'SysConfig XML does not parse'
    fi

    SETTING_COUNT=$(xpath_count '/otrs_config/Setting' "$CONFIG_XML")
    if [ "$SETTING_COUNT" = '1' ]; then
        pass 'SysConfig XML contains exactly one Setting'
    else
        fail "SysConfig Setting count is $SETTING_COUNT, expected 1"
    fi

    SETTING_NAME=$(xpath_text '/otrs_config/Setting/@Name' "$CONFIG_XML")
    if [ "$SETTING_NAME" = 'GenericInterface::Operation::Module###User::AgentList' ]; then
        pass 'SysConfig setting name is correct'
    else
        fail "Unexpected SysConfig setting name: $SETTING_NAME"
    fi

    NAVIGATION=$(xpath_text '/otrs_config/Setting/Navigation' "$CONFIG_XML")
    if [ "$NAVIGATION" = 'GenericInterface::Operation::ModuleRegistration' ]; then
        pass 'SysConfig navigation is GenericInterface::Operation::ModuleRegistration'
    else
        fail "Unexpected SysConfig navigation value: $NAVIGATION"
    fi

    for ITEM in \
        'Name=AgentList' \
        'Controller=User' \
        'ConfigDialog=AdminGenericInterfaceOperationDefault'
    do
        KEY=${ITEM%%=*}
        EXPECTED=${ITEM#*=}
        ACTUAL=$(xpath_text "/otrs_config/Setting/Value/Hash/Item[@Key='$KEY']" "$CONFIG_XML")
        if [ "$ACTUAL" = "$EXPECTED" ]; then
            pass "Operation registration $KEY is $EXPECTED"
        else
            fail "Unexpected operation registration $KEY value: $ACTUAL"
        fi
    done

    ITEM_COUNT=$(xpath_count '/otrs_config/Setting/Value/Hash/Item' "$CONFIG_XML")
    if [ "$ITEM_COUNT" = '3' ]; then
        pass 'Operation registration hash contains exactly three items'
    else
        fail "Operation registration hash item count is $ITEM_COUNT, expected 3"
    fi
fi

if grep -q 'use strict;' "$ROOT/Kernel/GenericInterface/Operation/User/AgentList.pm"; then
    pass 'Perl source contains use strict'
else
    fail 'Perl source does not contain use strict'
fi

if grep -q 'use warnings;' "$ROOT/Kernel/GenericInterface/Operation/User/AgentList.pm"; then
    pass 'Perl source contains use warnings'
else
    fail 'Perl source does not contain use warnings'
fi

if grep -q 'Kernel::GenericInterface::Operation::Common' "$ROOT/Kernel/GenericInterface/Operation/User/AgentList.pm"; then
    pass 'Perl source uses Kernel::GenericInterface::Operation::Common'
else
    fail 'Perl source does not use Kernel::GenericInterface::Operation::Common'
fi

ZZZ_AUTO=$(find "$ROOT" -path "$ROOT/.git" -prune -o -name 'ZZZAAuto.pm' -print -quit)
if [ -n "$ZZZ_AUTO" ]; then
    fail 'ZZZAAuto.pm is present in the source tree'
else
    pass 'No ZZZAAuto.pm file found'
fi

SQL_OR_MIGRATION=$(find "$ROOT" -path "$ROOT/.git" -prune -o \( -name '*.sql' -o -iname 'sql' -o -iname 'database' -o -iname 'migration' -o -iname 'migrations' \) -print -quit)
if [ -n "$SQL_OR_MIGRATION" ]; then
    fail 'SQL or migration files/directories are present in the source tree'
else
    pass 'No SQL or migration files/directories found'
fi

POWERSHELL_FILE=$(find "$ROOT" -path "$ROOT/.git" -prune -o -name '*.ps1' -print -quit)
if [ -n "$POWERSHELL_FILE" ]; then
    fail 'PowerShell files are present in the source tree'
else
    pass 'No PowerShell files found'
fi

OPM_FILE=$(find "$ROOT" -path "$ROOT/.git" -prune -o -name '*.opm' -print -quit)
if [ -n "$OPM_FILE" ]; then
    fail 'Generated .opm files are present in the source tree'
else
    pass 'No generated .opm files found'
fi

printf '\nWARNING: Final compatibility requires validation on Znuny 6.5.20.\n'
printf 'Summary: %s error(s).\n' "$ERRORS"

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
