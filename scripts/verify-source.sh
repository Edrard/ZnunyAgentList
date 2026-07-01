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
require_file 'scripts/test-move-assign-validation.pl'
require_file 'examples/webservices/AdvancedZnunyAgentListREST.yml'

SOPM="$ROOT/ZnunyAgentList.sopm"
CONFIG_XML="$ROOT/Kernel/Config/Files/XML/ZnunyAgentList.xml"
WEBSERVICE_YAML="$ROOT/examples/webservices/AdvancedZnunyAgentListREST.yml"

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

    if [ "$(xpath_text '/otrs_package/Version' "$SOPM")" = '1.4.1' ]; then
        pass 'SOPM version is 1.4.1'
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

    for SettingName in \
        'ZnunyAgentList::AllowedWriteGroups' \
        'ZnunyAgentList::EnableTicketWriteOperations' \
        'ZnunyAgentList::ReopenState' \
        'ZnunyAgentList::CloseState'
    do
        SettingCount=$(xmllint --xpath "count(/otrs_config/Setting[@Name='$SettingName'])" "$CONFIG_XML" 2>/dev/null)
        if [ "$SettingCount" = '1' ]; then
            pass "SysConfig setting exists: $SettingName"
        else
            fail "SysConfig setting missing or duplicated: $SettingName"
        fi
    done

    ALLOWED_WRITE_GROUP_DEFAULT_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[@Name='ZnunyAgentList::AllowedWriteGroups']/Value/Array/Item)" "$CONFIG_XML" 2>/dev/null)
    if [ "$ALLOWED_WRITE_GROUP_DEFAULT_COUNT" = '0' ]; then
        pass 'Default write group list is empty'
    else
        fail 'Default write group list must be empty'
    fi

    ENABLE_WRITE_DEFAULT=$(xpath_text "/otrs_config/Setting[@Name='ZnunyAgentList::EnableTicketWriteOperations']/Value/Item" "$CONFIG_XML")
    if [ "$ENABLE_WRITE_DEFAULT" = '0' ]; then
        pass 'Default write operation feature flag is disabled'
    else
        fail 'Default write operation feature flag must be disabled'
    fi

    for OperationName in \
        'GenericInterface::Operation::Module###Ticket::Get' \
        'GenericInterface::Operation::Module###Ticket::Search' \
        'GenericInterface::Operation::Module###Ticket::ArticleCreate' \
        'GenericInterface::Operation::Module###Ticket::Close' \
        'GenericInterface::Operation::Module###Ticket::Reopen' \
        'GenericInterface::Operation::Module###Ticket::Lock' \
        'GenericInterface::Operation::Module###Ticket::Unlock' \
        'GenericInterface::Operation::Module###Queue::AssignableAgents' \
        'GenericInterface::Operation::Module###Ticket::MoveAssignValidate' \
        'GenericInterface::Operation::Module###Ticket::MoveAssign' \
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

    TICKET_UPDATE_REGISTRATION_COUNT=$(xmllint --xpath "count(/otrs_config/Setting[@Name='GenericInterface::Operation::Module###Ticket::TicketUpdate' or @Name='GenericInterface::Operation::Module###TicketUpdate'])" "$CONFIG_XML" 2>/dev/null)
    if [ "$TICKET_UPDATE_REGISTRATION_COUNT" = '0' ]; then
        pass 'Generic unrestricted TicketUpdate operation is not registered'
    else
        fail 'Generic unrestricted TicketUpdate operation is registered'
    fi

    mapfile -t SOPM_LOCATIONS < <(xmllint --xpath '/otrs_package/Filelist/File/@Location' "$SOPM" 2>/dev/null | sed -E 's/ Location="/\n/g; s/"//g' | sed '/^$/d' | sort)

    SOPM_HAS_REPOSITORY_ONLY=$(printf '%s\n' "${SOPM_LOCATIONS[@]}" | grep -E '^(README\.md|CHANGES\.md|LICENSE|\.gitignore|scripts/|examples/|review/|build/|tmp/|dist/|\.git|.*\.(opm|zip|log)$)' || true)
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

if [ -f "$WEBSERVICE_YAML" ]; then
    if grep -Fq 'AdvancedZnunyAgentListREST' "$WEBSERVICE_YAML"; then
        pass 'Web Service template contains AdvancedZnunyAgentListREST name'
    else
        fail 'Web Service template is missing AdvancedZnunyAgentListREST name'
    fi

    for OperationType in \
        'Session::SessionCreate' \
        'Session::SessionGet' \
        'Ticket::TicketCreate' \
        'Ticket::TicketGet' \
        'Ticket::TicketSearch' \
        'Ticket::TicketHistoryGet' \
        'Ticket::TicketUpdate' \
        'User::AgentList' \
        'Queue::List' \
        'Queue::Get' \
        'Queue::AssignableAgents' \
        'CustomerUser::Search' \
        'CustomerUser::Get' \
        'Ticket::Search' \
        'Ticket::Get' \
        'Ticket::ArticleCreate' \
        'Ticket::Close' \
        'Ticket::Reopen' \
        'Ticket::Lock' \
        'Ticket::Unlock' \
        'Ticket::MoveAssignValidate' \
        'Ticket::MoveAssign' \
        'Ticket::ResolveTicketDefaults' \
        'Ticket::StateList' \
        'Ticket::PriorityList' \
        'Ticket::TypeList' \
        'Ticket::ServiceList' \
        'Ticket::SLAList' \
        'Ticket::ValidateTicketCreate' \
        'ZnunyAgentList::Config' \
        'ZnunyAgentList::Health'
    do
        if grep -Eq "^[[:space:]]*Type:[[:space:]]*$OperationType[[:space:]]*$" "$WEBSERVICE_YAML"; then
            pass "Web Service template contains operation: $OperationType"
        else
            fail "Web Service template is missing operation: $OperationType"
        fi
    done

    for Route in \
        '/Session' \
        '/Session/:SessionID' \
        '/Ticket' \
        '/Ticket/:TicketID' \
        '/TicketList' \
        '/TicketHistory/:TicketID' \
        '/Agent' \
        '/Queue' \
        '/Queue/:QueueID' \
        '/QueueByName/:Name' \
        '/Queue/:QueueID/AssignableAgents' \
        '/CustomerUser' \
        '/CustomerUser/:CustomerUserLogin' \
        '/ZnunyAgentListTicketSearch' \
        '/ZnunyAgentListTicket/:TicketID' \
        '/ZnunyAgentListTicketNumber/:TicketNumber' \
        '/TicketArticle' \
        '/TicketClose' \
        '/TicketReopen' \
        '/TicketLock' \
        '/TicketUnlock' \
        '/TicketMoveAssign/Validate' \
        '/TicketMoveAssign' \
        '/ResolveTicketDefaults' \
        '/TicketState' \
        '/TicketPriority' \
        '/TicketType' \
        '/Service' \
        '/SLA' \
        '/ValidateTicketCreate' \
        '/SystemConfig' \
        '/Health'
    do
        if grep -Eq "^[[:space:]]*Route:[[:space:]]*$Route[[:space:]]*$" "$WEBSERVICE_YAML"; then
            pass "Web Service template contains route: $Route"
        else
            fail "Web Service template is missing route: $Route"
        fi
    done

    YAML_SECRET_VALUE=$(grep -n -E "(BEGIN [A-Z ]*PRIVATE KEY|SECRET|^[[:space:]]*(Password|Token|SessionID|PrivateKey)[[:space:]]*:[[:space:]]*[^[:space:]'\"~#])" "$WEBSERVICE_YAML" || true)
    if [ -z "$YAML_SECRET_VALUE" ]; then
        pass 'Web Service template contains no obvious secret values'
    else
        fail 'Web Service template contains possible secret values'
    fi

    if grep -Fq 'Type: Ticket::TicketUpdate' "$WEBSERVICE_YAML"; then
        printf 'WARNING: Web Service template includes standard Ticket::TicketUpdate for GenericTicketConnector compatibility.\n'
        pass 'Generic TicketUpdate is confined to the repository-only Web Service template'
    else
        fail 'Web Service template is missing GenericTicketConnector Ticket::TicketUpdate compatibility operation'
    fi
else
    fail 'Web Service template is missing'
fi

if grep -Fq 'SearchLimit(' "$ROOT/Kernel/GenericInterface/Operation/Ticket/Search.pm" \
    && grep -Fq 'return $Class->Limit( $Value, 50, 100 );' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm"; then
    pass 'Ticket::Search enforces default limit 50 and max limit 100'
else
    fail 'Ticket::Search default/max limit enforcement was not found'
fi

if grep -Fq "Result => 'COUNT'" "$ROOT/Kernel/GenericInterface/Operation/Ticket/Search.pm" \
    && grep -Fq 'TotalCount' "$ROOT/Kernel/GenericInterface/Operation/Ticket/Search.pm" \
    && grep -Fq 'CountOnly' "$ROOT/Kernel/GenericInterface/Operation/Ticket/Search.pm"; then
    pass 'Ticket::Search supports native total counting and count-only responses'
else
    fail 'Ticket::Search total count support was not found'
fi

for WriteOperation in ArticleCreate Close Reopen Lock Unlock MoveAssignValidate MoveAssign; do
    WriteFile="$ROOT/Kernel/GenericInterface/Operation/Ticket/$WriteOperation.pm"

    if grep -Fq 'AuthenticateWriteAgent' "$WriteFile"; then
        pass "Write operation uses write authorization helper: Ticket::$WriteOperation"
    else
        fail "Write operation does not use write authorization helper: Ticket::$WriteOperation"
    fi

    if grep -Fq 'AuthenticateWriteAgent' "$WriteFile" \
        && grep -Fq 'WriteOperationsEnabled' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm"; then
        pass "Write operation is gated by EnableTicketWriteOperations: Ticket::$WriteOperation"
    else
        fail "Write operation EnableTicketWriteOperations gate not found: Ticket::$WriteOperation"
    fi

    if grep -E 'Param\(.*(ArticleType|SenderType|HistoryType|HistoryComment|From|To|Cc|Bcc|MimeType|Charset|Loop|AutoResponseType|TimeUnit|NoAgentNotify|ForceNotificationToUserID|ExcludeMuteNotificationToUserID|ExcludeNotificationToUserID)' "$WriteFile" >/dev/null 2>&1; then
        fail "Write operation accepts unsafe article internals: Ticket::$WriteOperation"
    else
        pass "Write operation does not accept unsafe article internals: Ticket::$WriteOperation"
    fi
done

if grep -R -n -E 'Param\(.*(QueueID|Queue|OwnerID|Owner|PriorityID|Priority|StateID|TypeID|ServiceID|SLAID|DynamicField|PendingTime|Lock|CustomerUser|Title)' "$ROOT/Kernel/GenericInterface/Operation/Ticket/Close.pm" "$ROOT/Kernel/GenericInterface/Operation/Ticket/Reopen.pm" >/dev/null 2>&1; then
    fail 'Close/Reopen expose generic TicketUpdate-style fields'
else
    pass 'Close/Reopen do not expose generic TicketUpdate-style fields'
fi

if grep -Fq 'MoveAssignValidation(' "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    && grep -Fq 'MoveAssignValidation(' "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm" \
    && grep -Fq 'TicketQueueMoveAllowed(' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm" \
    && grep -Fq 'OwnerCanOwnQueue(' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm" \
    && grep -Fq '( $QueueChanged || $OwnerChanged )' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm"; then
    pass 'Move/assign operations share final target owner/queue permission validation'
else
    fail 'Controlled move/assign final target owner/queue validation was not found'
fi

INLINE_MOVE_ASSIGN_PARAM=$(grep -n -E '=>.*ZnunyAgentList::Common->Param\(' \
    "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm" || true)
if [ -z "$INLINE_MOVE_ASSIGN_PARAM" ] \
    && grep -Fq 'QueueID   => $RawQueueID' "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    && grep -Fq 'QueueID   => $RawQueueID' "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm" \
    && grep -Fq "Param( \\%Param, 'OwnerLogin' )" "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    && grep -Fq "Param( \\%Param, 'OwnerLogin' )" "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm" \
    && grep -Fq "Param( \\%Param, 'CustomerUserID' )" "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    && grep -Fq "Param( \\%Param, 'CustomerUserID' )" "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm" \
    && ! grep -Fq "Param( \\%Param, 'UserLogin' )" "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    && ! grep -Fq "Param( \\%Param, 'UserLogin' )" "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm"; then
    pass 'Move/assign targets use OwnerLogin and CustomerUserID, never authentication UserLogin'
else
    fail 'Move/assign owner or customer target is not isolated from authentication UserLogin'
fi

if grep -Fq 'CustomerChanged' "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssignValidate.pm" \
    && grep -Fq 'CustomerChanged' "$ROOT/Kernel/GenericInterface/Operation/Ticket/MoveAssign.pm" \
    && grep -Fq 'CustomerUserID' "$ROOT/README.md" \
    && grep -Fiq 'CustomerID-only' "$ROOT/README.md" \
    && grep -Fq 'Target owner is not assignable in target queue.' "$ROOT/README.md" \
    && grep -Fq '/TicketMoveAssign/Validate' "$ROOT/README.md" \
    && grep -Fq '/TicketMoveAssign' "$ROOT/README.md"; then
    pass 'Controlled move/assign customer support and CustomerChanged are documented'
else
    fail 'Controlled move/assign customer support or CustomerChanged documentation was not found'
fi

if command -v perl >/dev/null 2>&1; then
    if perl "$ROOT/scripts/test-move-assign-validation.pl"; then
        pass 'Move/assign validation regression harness passed'
    else
        fail 'Move/assign validation regression harness failed'
    fi
else
    fail 'Perl is required for the move/assign validation regression harness'
fi

if grep -Fq 'AuthenticateReadAgent' "$ROOT/Kernel/GenericInterface/Operation/Queue/AssignableAgents.pm" \
    && grep -Fq "Type    => 'owner'" "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm"; then
    pass 'Assignable agents use read authorization and Znuny owner permission logic'
else
    fail 'Assignable agent authorization or owner permission logic was not found'
fi

if grep -E "Param\(.*'(Subject|Body|Kind|Reason|ArticleType|SenderType|HistoryType|HistoryComment|From|To|Cc|Bcc|MimeType|Charset)'" \
    "$ROOT/Kernel/GenericInterface/Operation/Ticket/Lock.pm" \
    "$ROOT/Kernel/GenericInterface/Operation/Ticket/Unlock.pm" >/dev/null 2>&1 \
    || grep -Fq 'TicketArticleCreate' "$ROOT/Kernel/GenericInterface/Operation/Ticket/Lock.pm" \
    || grep -Fq 'TicketArticleCreate' "$ROOT/Kernel/GenericInterface/Operation/Ticket/Unlock.pm"; then
    fail 'Lock/Unlock accept article parameters or create ticket articles'
else
    pass 'Lock/Unlock change lock state without article inputs or article creation'
fi

if grep -Fq 'LockID' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm" \
    && grep -Fq 'Lock           => $Ticket{Lock}' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm"; then
    pass 'Safe ticket metadata includes LockID and Lock'
else
    fail 'Safe ticket metadata is missing LockID or Lock'
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

RUNTIME_TICKET_UPDATE_FILE=$(find "$ROOT/Kernel" -path "$ROOT/.git" -prune -o -type f -path '*/TicketUpdate.pm' -print -quit)
if [ -n "$RUNTIME_TICKET_UPDATE_FILE" ]; then
    fail 'Generic TicketUpdate runtime module is present in package source'
else
    pass 'No generic TicketUpdate runtime module found'
fi

SOPM_TICKET_UPDATE=$(grep -n -E 'TicketUpdate\.pm|GenericInterface/Operation/Ticket/TicketUpdate' "$SOPM" || true)
if [ -n "$SOPM_TICKET_UPDATE" ]; then
    fail 'SOPM includes a generic TicketUpdate runtime wrapper'
else
    pass 'SOPM does not include a generic TicketUpdate runtime wrapper'
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

LOCK_SET_OUTSIDE_COMMON=$(grep -R -n -E '\bTicketLockSet\s*\(' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' \
    | grep -Fv "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm:" || true)
if [ -n "$LOCK_SET_OUTSIDE_COMMON" ]; then
    fail 'TicketLockSet call found outside the controlled common helper'
elif grep -Fq '$TicketObject->TicketLockSet(' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm" \
    && grep -Fq "Lock     => 'lock'" "$ROOT/Kernel/GenericInterface/Operation/Ticket/Lock.pm" \
    && grep -Fq "Lock     => 'unlock'" "$ROOT/Kernel/GenericInterface/Operation/Ticket/Unlock.pm"; then
    pass 'TicketLockSet is confined to controlled lock/unlock operations'
else
    fail 'Controlled TicketLockSet implementation was not found'
fi

QUEUE_SET_OUTSIDE_COMMON=$(grep -R -n -E '\bTicketQueueSet\s*\(' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' \
    | grep -Fv "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm:" || true)
OWNER_SET_OUTSIDE_COMMON=$(grep -R -n -E '\bTicketOwnerSet\s*\(' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' \
    | grep -Fv "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm:" || true)
CUSTOMER_SET_OUTSIDE_COMMON=$(grep -R -n -E '\bTicketCustomerSet\s*\(' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' \
    | grep -Fv "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm:" || true)
if [ -n "$QUEUE_SET_OUTSIDE_COMMON" ] || [ -n "$OWNER_SET_OUTSIDE_COMMON" ] || [ -n "$CUSTOMER_SET_OUTSIDE_COMMON" ]; then
    fail 'TicketQueueSet, TicketCustomerSet, or TicketOwnerSet call found outside the controlled common helper'
elif grep -Fq '$TicketObject->TicketQueueSet(' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm" \
    && grep -Fq '$TicketObject->TicketCustomerSet(' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm" \
    && grep -Fq '$TicketObject->TicketOwnerSet(' "$ROOT/Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm"; then
    pass 'TicketQueueSet, TicketCustomerSet, and TicketOwnerSet are confined to the controlled common helper'
else
    fail 'Controlled TicketQueueSet, TicketCustomerSet, or TicketOwnerSet implementation was not found'
fi

WRITE_STYLE_CALLS=$(grep -R -n -E '\b(TicketCreate|TicketUpdate|TicketUnlock|SetPreferences|QueueUpdate|QueueAdd|CustomerUserAdd|CustomerUserUpdate|SLAAdd|SLAUpdate|ServiceAdd|ServiceUpdate|PriorityAdd|PriorityUpdate|StateAdd|StateUpdate|TypeAdd|TypeUpdate)\s*\(|DB->Do\b' "$ROOT/Kernel/GenericInterface/Operation" --include='*.pm' || true)
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
