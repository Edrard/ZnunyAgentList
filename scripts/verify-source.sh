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

printf 'ZnunyAgentList source verification for server-side review\n'
printf 'Repository root: %s\n\n' "$ROOT"
printf 'This script performs read-only source checks. It does not build, install,\n'
printf 'uninstall, rebuild configuration, clear cache, or call the REST endpoint.\n\n'

require_file '.gitignore'
require_file 'CHANGES.md'
require_file 'LICENSE'
require_file 'README.md'
require_file 'ZnunyAgentList.sopm'
require_file 'Kernel/Config/Files/XML/ZnunyAgentList.xml'
require_file 'scripts/verify-source.sh'
require_file 'scripts/build-package.sh'

SOPM="$ROOT/ZnunyAgentList.sopm"
CONFIG_XML="$ROOT/Kernel/Config/Files/XML/ZnunyAgentList.xml"

if ! command -v xmllint >/dev/null 2>&1; then
    fail 'xmllint is required for XML checks. Install the Rocky Linux libxml2 package or run XML validation manually.'
else
    if xmllint --noout "$SOPM" >/dev/null 2>&1; then
        pass 'SOPM XML is well-formed'
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

    if xmllint --noout "$CONFIG_XML" >/dev/null 2>&1; then
        pass 'SysConfig XML is well-formed'
    else
        fail 'SysConfig XML does not parse'
    fi

    SETTING_COUNT=$(xpath_count "/otrs_config/Setting[starts-with(@Name,'GenericInterface::Operation::Module###')]" "$CONFIG_XML")
    if [ "$SETTING_COUNT" -ge '1' ]; then
        pass "SysConfig XML contains $SETTING_COUNT operation Setting elements"
    else
        fail 'SysConfig XML contains no operation Setting elements'
    fi

    BAD_NAVIGATION_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[starts-with(@Name,'GenericInterface::Operation::Module###') and Navigation!='GenericInterface::Operation::ModuleRegistration'])" "$CONFIG_XML" 2>/dev/null)
    if [ "$BAD_NAVIGATION_COUNT" = '0' ]; then
        pass 'All operation registrations use GenericInterface::Operation::ModuleRegistration navigation'
    else
        fail 'Unexpected SysConfig operation navigation value found'
    fi

    BAD_HASH_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[starts-with(@Name,'GenericInterface::Operation::Module###') and (not(Value/Hash/Item[@Key='Name']) or not(Value/Hash/Item[@Key='Controller']) or Value/Hash/Item[@Key='ConfigDialog']!='AdminGenericInterfaceOperationDefault')])" "$CONFIG_XML" 2>/dev/null)
    if [ "$BAD_HASH_COUNT" = '0' ]; then
        pass 'All operation registrations contain Name, Controller, and default ConfigDialog'
    else
        fail 'One or more operation registrations are missing required hash values'
    fi

    ALLOWED_GROUPS_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[@Name='ZnunyAgentList::AllowedGroups'])" "$CONFIG_XML" 2>/dev/null)
    if [ "$ALLOWED_GROUPS_COUNT" = '1' ]; then
        pass 'SysConfig contains ZnunyAgentList::AllowedGroups'
    else
        fail 'SysConfig must contain ZnunyAgentList::AllowedGroups exactly once'
    fi

    API_GROUP_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[@Name='ZnunyAgentList::AllowedGroups']/Value/Array/Item[.='api_group'])" "$CONFIG_XML" 2>/dev/null)
    if [ "$API_GROUP_COUNT" = '1' ]; then
        pass 'Default allowed group is api_group'
    else
        fail 'Default allowed group api_group is missing'
    fi

    OLD_SYSTEM_REGISTRATION_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[@Name='GenericInterface::Operation::Module###System::Config' or @Name='GenericInterface::Operation::Module###System::Health'])" "$CONFIG_XML" 2>/dev/null)
    if [ "$OLD_SYSTEM_REGISTRATION_COUNT" = '0' ]; then
        pass 'Old System::Config and System::Health registrations are absent'
    else
        fail 'Old System::Config or System::Health registration is still present'
    fi

    for OperationName in \
        'GenericInterface::Operation::Module###ZnunyAgentList::Config' \
        'GenericInterface::Operation::Module###ZnunyAgentList::Health'
    do
        OperationCount=$(xmllint --xpath "count(/otrs_config/Setting[@Name='$OperationName'])" "$CONFIG_XML" 2>/dev/null)
        if [ "$OperationCount" = '1' ]; then
            pass "Operation registration exists: $OperationName"
        else
            fail "Operation registration missing or duplicated: $OperationName"
        fi
    done

    mapfile -t SOPM_LOCATIONS < <(xmllint --xpath '/otrs_package/Filelist/File/@Location' "$SOPM" 2>/dev/null | sed -E 's/ Location="/\n/g; s/"//g' | sed '/^$/d' | sort)

    SOPM_HAS_REPOSITORY_ONLY=$(printf '%s\n' "${SOPM_LOCATIONS[@]}" | grep -E '^(README\.md|CHANGES\.md|LICENSE|\.gitignore|scripts/|dist/|\.git)' || true)
    if [ -z "$SOPM_HAS_REPOSITORY_ONLY" ]; then
        pass 'SOPM does not install repository-only files'
    else
        fail "SOPM installs repository-only files: $SOPM_HAS_REPOSITORY_ONLY"
    fi

    mapfile -t RUNTIME_FILES < <(
        {
            find "$ROOT/Kernel/GenericInterface/Operation" -type f -name '*.pm' -printf '%P\n' | sed 's#^#Kernel/GenericInterface/Operation/#'
            printf '%s\n' 'Kernel/Config/Files/XML/ZnunyAgentList.xml'
        } | sort
    )

    for RuntimeFile in "${RUNTIME_FILES[@]}"; do
        require_file "$RuntimeFile"

        if printf '%s\n' "${SOPM_LOCATIONS[@]}" | grep -Fxq "$RuntimeFile"; then
            pass "SOPM contains runtime file: $RuntimeFile"
        else
            fail "SOPM is missing runtime file: $RuntimeFile"
        fi
    done

    for SopmLocation in "${SOPM_LOCATIONS[@]}"; do
        if printf '%s\n' "${RUNTIME_FILES[@]}" | grep -Fxq "$SopmLocation"; then
            :
        else
            fail "SOPM contains unexpected runtime location: $SopmLocation"
        fi
    done
fi

while IFS= read -r OperationFile; do
    OperationPath=${OperationFile#"$ROOT/"}

    case "$OperationPath" in
        Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm)
            continue
            ;;
    esac

    if grep -q 'use parent qw(Kernel::GenericInterface::Operation::Common);' "$OperationFile"; then
        pass "Operation uses GenericInterface base class: $OperationPath"
    else
        fail "Operation does not use GenericInterface base class: $OperationPath"
    fi
done < <(find "$ROOT/Kernel/GenericInterface/Operation" -type f -name '*.pm' | sort)

SYSTEM_OPERATION_FILE=$(find "$ROOT/Kernel/GenericInterface/Operation/System" -type f -name '*.pm' -print -quit 2>/dev/null || true)
if [ -n "$SYSTEM_OPERATION_FILE" ]; then
    fail 'Old System operation files are still present'
else
    pass 'No old System operation files found'
fi

AUTO_CONFIG_FILE='ZZZ''AAuto.pm'

ZZZ_AUTO=$(find "$ROOT" -path "$ROOT/.git" -prune -o -name "$AUTO_CONFIG_FILE" -print -quit)
if [ -n "$ZZZ_AUTO" ]; then
    fail "$AUTO_CONFIG_FILE is present in the source tree"
else
    pass "No $AUTO_CONFIG_FILE file found"
fi

# Documentation may mention ZZZAAuto.pm as a forbidden modification.
# Only runtime/package references should fail verification.
ZZZ_REFERENCE=$(grep -R -n "$AUTO_CONFIG_FILE" \
    "$ROOT/Kernel" \
    "$ROOT/ZnunyAgentList.sopm" \
    2>/dev/null || true)
if [ -n "$ZZZ_REFERENCE" ]; then
    fail "$AUTO_CONFIG_FILE reference found in runtime package files"
else
    pass "No $AUTO_CONFIG_FILE references found in runtime package files"
fi

SQL_OR_MIGRATION=$(find "$ROOT" -path "$ROOT/.git" -prune -o \( -name '*.sql' -o -iname 'sql' -o -iname 'database' -o -iname 'migration' -o -iname 'migrations' \) -print -quit)
if [ -n "$SQL_OR_MIGRATION" ]; then
    fail 'SQL or migration files/directories are present in the source tree'
else
    pass 'No SQL or migration files/directories found'
fi

RAW_SQL=$(grep -R -n -E '\b(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' || true)
if [ -n "$RAW_SQL" ]; then
    fail 'Obvious raw SQL keyword found in operation files'
else
    pass 'No obvious raw SQL found in operation files'
fi

WRITE_STYLE_CALLS=$(grep -R -n -E '\b(TicketCreate|TicketUpdate|TicketLockSet|TicketUnlock|SetPreferences|QueueUpdate|QueueAdd|CustomerUserAdd|CustomerUserUpdate|SLAAdd|SLAUpdate|ServiceAdd|ServiceUpdate|PriorityAdd|PriorityUpdate|StateAdd|StateUpdate|TypeAdd|TypeUpdate)\s*\(|DB->Do\b' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' || true)
if [ -n "$WRITE_STYLE_CALLS" ]; then
    fail 'Obvious write-style method call found in operation files'
else
    pass 'No obvious write-style method calls found in operation files'
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

printf '\nWARNING: This read-only check does not prove Perl syntax, package build, installation, operation discovery, or REST behavior.\n'
printf 'WARNING: Complete runtime validation still requires the real Znuny 6.5.20 server.\n'
printf 'Summary: %s error(s).\n' "$ERRORS"

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
