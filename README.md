# ZnunyAgentList

## Purpose

`ZnunyAgentList` is a standalone Znuny 6.5 GenericInterface helper package for external integrations that need a controlled REST API for safe lookup data, ticket read/search metadata, and TicketCreate preflight validation.

The package name remains `ZnunyAgentList` and the package version is `1.2.0`.

## What This Package Does

- Registers read-only GenericInterface operations for agents, queues, customer users, tickets, ticket dictionaries, package config, and package health.
- Provides safe `Ticket::Get` and `Ticket::Search` metadata operations with explicit response allow-lists.
- Provides controlled `Ticket::ArticleCreate`, `Ticket::Close`, and `Ticket::Reopen` write operations that are disabled by default.
- Provides a non-mutating `Ticket::ValidateTicketCreate` operation that checks a future TicketCreate payload without creating a ticket.
- Uses standard GenericInterface authentication.
- Requires an authenticated Znuny agent user.
- Requires `ro` permission in at least one group configured in `ZnunyAgentList::AllowedGroups`.
- Returns explicit allow-listed response fields only.

## What This Package Does Not Do

- Does not create tickets.
- Does not modify queues, users, customer users, services, SLAs, states, priorities, types, preferences, config, groups, roles, or database rows.
- Does not modify arbitrary ticket fields.
- Does not call `TicketCreate`.
- Does not register generic unrestricted `TicketUpdate` as a package runtime operation.
- Does not use raw SQL.
- Does not add database migrations.
- Does not modify Znuny core files.
- Does not edit `ZZZAAuto.pm`.
- Does not create the `api_group` group automatically.
- Does not install, upgrade, uninstall, rebuild config, clear cache, or deploy automatically.

## Supported Environment

- Supported platform: Znuny 6.5 LTS
- Validation target: Znuny 6.5.20
- Server path: `/opt/otrs`
- Server OS: Rocky Linux 8
- Runtime user: `otrs`
- Local development: Windows source editing only

Authoritative Perl syntax checks, package builds, package installation, operation discovery, and REST validation must happen on the real Znuny server. Windows local checks are not runtime validation.

## Security Model

Every operation inherits from `Kernel::GenericInterface::Operation::Common` and authenticates through:

```perl
my ( $UserID, $UserType ) = $Self->Auth(%Param);
```

Read operation access is allowed only when all of these are true:

- GenericInterface authentication succeeds.
- `UserType` is `User`.
- The authenticated agent has at least `ro` permission in one group configured in:

```text
ZnunyAgentList::AllowedGroups
```

The default group is:

```text
api_group
```

Authentication failures, wrong user type, missing/invalid group config, missing group permission, and group lookup failures all return the same generic error code:

```text
ZnunyAgentList.AuthFail
```

`ZnunyAgentList::Health` is authenticated and group-protected. It is not a public endpoint.

Version `1.2.0` includes write-control settings for controlled ticket write operations:

```text
ZnunyAgentList::AllowedWriteGroups
ZnunyAgentList::EnableTicketWriteOperations
ZnunyAgentList::ReopenState
ZnunyAgentList::CloseState
```

Write operations are disabled and unconfigured by default. `AllowedWriteGroups` defaults to an empty list, `EnableTicketWriteOperations` defaults to `0`, `ReopenState` defaults to `open`, and `CloseState` defaults to `closed successful`.

To enable controlled write operations after installing the package:

1. Create a dedicated write group for API agents.
2. Add only approved API agent users to that group with `ro` permission.
3. Set `ZnunyAgentList::AllowedWriteGroups` to that group.
4. Set `ZnunyAgentList::EnableTicketWriteOperations` to `1`.
5. Keep read-only integrations in `ZnunyAgentList::AllowedGroups` when they do not need writes.

## Required Manual Security Setup

Before production use:

1. Create a dedicated Znuny group named `api_group`.
2. Create a dedicated API agent user.
3. Give that API agent `ro` permission in `api_group`.
4. Use that API agent for GenericInterface API access.
5. Keep `ZnunyAgentList::AllowedGroups` restricted to `api_group`.
6. Do not use normal human admin accounts for integrations.
7. Restrict network access to the GenericInterface web service.

The package does not create or modify groups, users, roles, or permissions.

## Operations Overview

| Suggested Route | HTTP Method | GenericInterface Operation | Purpose | Security Notes |
| --- | --- | --- | --- | --- |
| `/Agent` | GET | `User::AgentList` | List active non-out-of-office agents | Agent auth plus allowed group |
| `/Queue` | GET | `Queue::List` | List valid queues | Agent auth plus allowed group |
| `/Queue/{QueueID}` | GET | `Queue::Get` | Lookup queue by ID | Agent auth plus allowed group |
| `/Queue?Name=...` | GET | `Queue::Get` | Lookup queue by name | Agent auth plus allowed group |
| `/CustomerUser?Search=...` | GET | `CustomerUser::Search` | Search valid customer users | Search is hardened and capped |
| `/CustomerUser/{UserLogin}` | GET | `CustomerUser::Get` | Lookup customer user by login | Explicit allow-list only |
| `/ZnunyAgentListTicket/{TicketID}` | GET | `Ticket::Get` | Lookup ticket metadata by `TicketID` | Explicit allow-list only |
| `/ZnunyAgentListTicketNumber/{TicketNumber}` | GET | `Ticket::Get` | Lookup ticket metadata by `TicketNumber` | Explicit allow-list only |
| `/ZnunyAgentListTicketSearch?...` | GET | `Ticket::Search` | Safe filtered ticket search | Requires at least one filter and capped result limits |
| `/TicketArticle` | POST | `Ticket::ArticleCreate` | Add controlled reply or internal note | Requires write flag plus write group |
| `/TicketClose` | POST | `Ticket::Close` | Close ticket with required reason | Requires closed target state and write group |
| `/TicketReopen` | POST | `Ticket::Reopen` | Reopen closed ticket with required reason | Requires non-closed target state and write group |
| `/ResolveTicketDefaults?...` | GET | `Ticket::ResolveTicketDefaults` | Resolve queue/customer defaults from host name | Business misses return warnings |
| `/TicketState` | GET | `Ticket::StateList` | List valid ticket states with state type | Dictionary values only |
| `/TicketPriority` | GET | `Ticket::PriorityList` | List valid ticket priorities | Dictionary values only |
| `/TicketType` | GET | `Ticket::TypeList` | List valid ticket types | Empty list with warning if unavailable |
| `/Service` | GET | `Ticket::ServiceList` | List valid services | Empty list with warning if unavailable |
| `/SLA` | GET | `Ticket::SLAList` | List valid SLAs | Empty list with warning if unavailable |
| `/SystemConfig` | GET | `ZnunyAgentList::Config` | Return package capabilities | No sensitive environment data |
| `/Health` | GET | `ZnunyAgentList::Health` | Return package health status | Authenticated, not public |
| `/ValidateTicketCreate` | POST | `Ticket::ValidateTicketCreate` | Validate future TicketCreate data | Never creates or modifies tickets |

## Suggested REST Route Mapping

The package registers operations only. REST routes are mapped manually in Znuny Admin > Web Services.

Use the operation names from the table above when adding package-specific operations to the intended GenericInterface web service. The suggested routes are examples and can be adjusted to local naming standards.

The repository Web Service template includes the recommended `1.2.0` package-specific routes and standard Znuny GenericTicketConnector compatibility routes. Import and verify the template manually; it is not installed by the package.

## Optional Web Service Import Template

The repository includes an optional Znuny GenericInterface REST import template:

```text
examples/webservices/AdvancedZnunyAgentListREST.yml
```

This YAML is a helper template only. It is not automatically installed by the `.opm` package and is not listed in `ZnunyAgentList.sopm`.

The template contains two operation categories:

- Standard Znuny GenericTicketConnector compatibility operations: `SessionCreate`, `SessionGet`, `TicketCreate`, `TicketGet`, `TicketGetList`, `TicketHistoryGet`, `TicketSearch`, and `TicketUpdate`.
- ZnunyAgentList package-specific safe and controlled operations: `AgentList`, `QueueList`, `QueueGet`, `CustomerUserSearch`, `CustomerUserGet`, `ResolveTicketDefaults`, ticket dictionary list operations, `ValidateTicketCreate`, safe `Ticket::Get` and `Ticket::Search`, `Ticket::ArticleCreate`, `Ticket::Close`, `Ticket::Reopen`, `ZnunyAgentList::Config`, and `ZnunyAgentList::Health`.

`ZnunyAgentList` does not implement or register generic unrestricted `TicketUpdate` as a package runtime module. The optional Web Service template includes standard `Ticket::TicketUpdate` only for compatibility with existing GenericTicketConnectorREST clients. Administrators may remove or disable that standard operation in the imported Web Service if they want a strictly controlled integration surface.

Import it manually after installing `ZnunyAgentList`:

```text
Admin > Web Services > Add Web Service > Import web service
```

The recommended imported Web Service name is:

```text
AdvancedZnunyAgentListREST
```

Importing a Web Service YAML can overwrite or conflict with an existing Web Service if names are the same. After import, verify the transport, authentication, debugger settings, and route mappings in the Znuny Admin UI. Then rebuild configuration and clear cache as separate administrative steps.

Example endpoint base URL:

```text
https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST
```

Smoke test `Health`:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Health?UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Existing GenericTicketConnectorREST-style clients may continue to use SessionID-based authentication through the compatibility session routes:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Session" \
  -H "Content-Type: application/json" \
  -d '{"UserLogin":"zabbix.integration","Password":"SECRET"}' | jq .
```

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Health?SessionID=SESSION_ID_PLACEHOLDER" | jq .
```

Smoke tests may also pass `UserLogin` and `Password` directly as shown below. That does not remove `SessionID` support from the Web Service.

Expected success:

```json
{
  "Plugin": "ZnunyAgentList",
  "Success": 1,
  "Time": "2026-06-15 16:22:07",
  "Version": "1.2.0"
}
```

Expected no-auth or wrong-password response:

```json
{
  "Error": {
    "ErrorCode": "ZnunyAgentList.AuthFail",
    "ErrorMessage": "ZnunyAgentList: Authentication failed."
  }
}
```

Smoke test `Agent`:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Agent?UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Expected response contains an `Agents` array.

Smoke test `Queue`:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Queue?UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Expected response contains a `Queues` array.

Ticket get by `TicketID`:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/ZnunyAgentListTicket/123?UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Ticket get by `TicketNumber`:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/ZnunyAgentListTicketNumber/2026061710000012?UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Ticket search:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/ZnunyAgentListTicketSearch?Queue=Support&StateType=open&Limit=50&UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Ticket search without filters:

```bash
curl -sk "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/ZnunyAgentListTicketSearch?UserLogin=zabbix.integration&Password=SECRET" | jq .
```

Expected response contains an empty `Tickets` array and the warning `At least one search filter is required.`

Create an internal note:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/TicketArticle?UserLogin=zabbix.integration&Password=SECRET" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":123,"Kind":"internal_note","Subject":"Integration note","Body":"Internal diagnostic note."}' | jq .
```

Create a public reply:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/TicketArticle?UserLogin=zabbix.integration&Password=SECRET" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":123,"Kind":"reply","Subject":"Update from integration","Body":"Customer-visible update."}' | jq .
```

Close a ticket:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/TicketClose?UserLogin=zabbix.integration&Password=SECRET" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":123,"Reason":"Issue resolved by external workflow."}' | jq .
```

Reopen a ticket:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/TicketReopen?UserLogin=zabbix.integration&Password=SECRET" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":123,"Reason":"Issue reproduced after closure."}' | jq .
```

Write disabled negative test:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/TicketClose?UserLogin=zabbix.integration&Password=SECRET" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":123,"Reason":"Write flag disabled test."}' | jq .
```

Expected response contains package error code `ZnunyAgentList.WriteForbidden` when `ZnunyAgentList::EnableTicketWriteOperations` is `0`.

Wrong write group negative test:

```bash
curl -sk -X POST "https://otrs.example.net/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/TicketReopen?UserLogin=read.only.integration&Password=SECRET" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":123,"Reason":"Wrong group test."}' | jq .
```

Expected response contains package error code `ZnunyAgentList.WriteForbidden` when the authenticated agent is not in `ZnunyAgentList::AllowedWriteGroups`.

Znuny GenericInterface may return HTTP 200 even for application-level authentication or authorization errors. Integrations must inspect the JSON body for `Success` or `Error`, not only the HTTP status code.

## Response Shapes

All normal successful operations return:

```perl
{
    Success => 1,
    Data    => {
        ...
    },
}
```

Business validation misses return `Success => 1` with `Found => 0`, `Valid => 0`, `Warnings`, or `Errors` inside `Data`. Authentication and authorization failures use the generic GenericInterface error response.

`User::AgentList`:

```json
{
  "Agents": [
    {
      "UserID": 12,
      "UserLogin": "agent@example.invalid",
      "UserFullname": "Example Agent"
    }
  ]
}
```

`Queue::List`:

```json
{
  "Queues": [
    {
      "QueueID": 12,
      "Name": "Support",
      "FullName": "Support",
      "ValidID": 1
    }
  ]
}
```

`Queue::Get` found:

```json
{
  "Queue": {
    "Found": true,
    "QueueID": 12,
    "Name": "Support",
    "FullName": "Support",
    "ValidID": 1
  }
}
```

`Queue::Get` not found:

```json
{
  "Queue": {
    "Found": false
  },
  "Warnings": [
    "Queue not found."
  ]
}
```

`CustomerUser::Search`:

```json
{
  "CustomerUsers": [
    {
      "UserLogin": "customer@example.invalid",
      "UserCustomerID": "ExampleCustomer",
      "UserFirstname": "Example",
      "UserLastname": "Customer",
      "UserEmail": "customer@example.invalid"
    }
  ]
}
```

Wildcard-only `CustomerUser::Search` rejection:

```json
{
  "CustomerUsers": [],
  "Warnings": [
    "Search must contain at least 2 non-wildcard characters."
  ]
}
```

`CustomerUser::Get` found:

```json
{
  "CustomerUser": {
    "Found": true,
    "UserLogin": "customer@example.invalid",
    "UserCustomerID": "ExampleCustomer",
    "UserFirstname": "Example",
    "UserLastname": "Customer",
    "UserEmail": "customer@example.invalid"
  }
}
```

`CustomerUser::Get` not found:

```json
{
  "CustomerUser": {
    "Found": false
  },
  "Warnings": [
    "CustomerUser not found."
  ]
}
```

`Ticket::ResolveTicketDefaults`:

```json
{
  "Input": {
    "HostName": "Support host.example.invalid"
  },
  "Detected": {
    "QueueName": "Support",
    "CustomerUserLogin": "SupportClients"
  },
  "Queue": {
    "Found": true,
    "QueueID": 12,
    "Name": "Support",
    "FullName": "Support"
  },
  "CustomerUser": {
    "Found": true,
    "UserLogin": "SupportClients",
    "UserCustomerID": "Support"
  },
  "Warnings": []
}
```

`Ticket::Get`:

```json
{
  "Found": true,
  "Ticket": {
    "TicketID": 123,
    "TicketNumber": "2026061710000012",
    "Title": "Example ticket",
    "QueueID": 12,
    "Queue": "Support",
    "OwnerID": 4,
    "Owner": "agent.login",
    "CustomerUserID": "customer.login",
    "CustomerUser": "customer.login",
    "StateID": 4,
    "State": "open",
    "StateType": "open",
    "PriorityID": 3,
    "Priority": "3 normal",
    "Created": "2026-06-17 10:00:00",
    "Changed": "2026-06-17 10:15:00"
  },
  "Warnings": []
}
```

`Ticket::Search` without filters:

```json
{
  "Tickets": [],
  "Count": 0,
  "Limit": 50,
  "Offset": 0,
  "Warnings": [
    "At least one search filter is required."
  ]
}
```

`Ticket::Search` requires at least one meaningful filter. It defaults to `Limit = 50`, caps `Limit` at `100`, caps `Offset` at `1000`, accepts `Offset` or `Page`, and allow-lists `SortBy` to `TicketID`, `TicketNumber`, `Created`, `Changed`, `State`, `Priority`, `Queue`, `Owner`, or `Title`.

`Ticket::StateList`:

```json
{
  "TicketStates": [
    {
      "ID": 1,
      "StateID": 1,
      "Name": "new",
      "State": "new",
      "StateTypeID": 1,
      "StateType": "new",
      "ValidID": 1
    }
  ]
}
```

`ZnunyAgentList::Config`:

```json
{
  "Plugin": "ZnunyAgentList",
  "Version": "1.2.0",
  "Features": {
    "AgentList": true,
    "CustomerUserSearch": true,
    "TicketGet": true,
    "TicketSearch": true,
    "TicketArticleCreate": true,
    "TicketClose": true,
    "TicketReopen": true,
    "ValidateTicketCreate": true
  },
  "Znuny": {
    "Version": "6.5.x"
  }
}
```

`ZnunyAgentList::Health`:

```json
{
  "Success": true,
  "Plugin": "ZnunyAgentList",
  "Version": "1.2.0",
  "Time": "2026-06-15 12:00:00"
}
```

`Ticket::ValidateTicketCreate` valid:

```json
{
  "Valid": true,
  "Errors": [],
  "Warnings": []
}
```

`Ticket::ValidateTicketCreate` invalid:

```json
{
  "Valid": false,
  "Errors": [
    "Queue not found."
  ],
  "Warnings": []
}
```

## Customer User Search Safety

`CustomerUser::Search` sanitizes `Search`, removes wildcard characters from a temporary validation copy, and requires at least 2 meaningful non-wildcard characters. The wildcard characters checked for this minimum are:

```text
*
%
?
```

Wildcard-only searches such as `**`, `%%`, `??`, or `*%` return an empty result with a warning. This reduces broad customer user enumeration risk. The actual search value is not defaulted to `*`, and `Limit` is capped at 50.

## Ticket Default Resolution Rule

`Ticket::ResolveTicketDefaults` uses the first whitespace-separated `HostName` token:

```text
QueueName = first HostName token
CustomerUserLogin = QueueName + "Clients"
```

It validates the queue with `QueueGet(Name => ...)` and the customer user with `CustomerUserDataGet(User => ...)`. Missing business data returns `Found => 0` and warnings rather than GenericInterface errors.

## TicketCreate Preflight Validation

`Ticket::ValidateTicketCreate` validates:

- `OwnerID`
- `Queue`
- `CustomerUser`
- `State`
- `Lock`

It never calls `TicketCreate`, never locks or unlocks tickets, and never writes data. It is a lookup-style preflight check only.

## Package Source Layout

Package-owned runtime files live under:

```text
Kernel/Config/Files/XML/ZnunyAgentList.xml
Kernel/GenericInterface/Operation/...
```

Repository-only files include docs, helper scripts, `.gitignore`, review artifacts, logs, and generated packages.

## SOPM / Installed Runtime Files

`ZnunyAgentList.sopm` installs only runtime files:

- `Kernel/Config/Files/XML/ZnunyAgentList.xml`
- `Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm`
- `Kernel/GenericInterface/Operation/ZnunyAgentList/Config.pm`
- `Kernel/GenericInterface/Operation/ZnunyAgentList/Health.pm`
- operation modules under `Kernel/GenericInterface/Operation/User/`
- operation modules under `Kernel/GenericInterface/Operation/Queue/`
- operation modules under `Kernel/GenericInterface/Operation/CustomerUser/`
- operation modules under `Kernel/GenericInterface/Operation/Ticket/`

The SOPM does not install `README.md`, `CHANGES.md`, `LICENSE`, scripts, Git metadata, review files, logs, or generated `.opm` files.

## Transfer To Server

Transfer the source tree to a staging path on the Znuny server using one of:

```bash
git clone <REPOSITORY_URL> /path/to/ZnunyAgentList
scp -r /local/path/ZnunyAgentList <ssh-user>@<znuny-host>:/path/to/ZnunyAgentList
rsync -a --exclude .git /local/path/ZnunyAgentList/ <ssh-user>@<znuny-host>:/path/to/ZnunyAgentList/
```

Use placeholders only. Do not store credentials, tokens, or session IDs in this repository.

## Server-Side Verification

Run read-only source verification on Rocky Linux 8:

```bash
cd /path/to/ZnunyAgentList
bash scripts/verify-source.sh
```

Run Perl syntax checks on the real Znuny server:

```bash
cd /opt/otrs
find /path/to/ZnunyAgentList/Kernel/GenericInterface/Operation -type f -name '*.pm' -print0 \
  | xargs -0 -n1 perl -I/path/to/ZnunyAgentList -I/opt/otrs -c
```

These checks do not prove package installation, GenericInterface discovery, or REST behavior.

## Package Build

Build the `.opm` on the Znuny server:

```bash
cd /path/to/ZnunyAgentList
bash scripts/build-package.sh /path/to/ZnunyAgentList /path/to/output
```

The helper runs `scripts/verify-source.sh` first, checks that the `otrs` user can read source/runtime files, verifies that the output directory is writable by `otrs`, and runs `Dev::Package::Build` as `otrs`.

Building creates:

```text
/path/to/output/ZnunyAgentList-1.2.0.opm
```

Building does not install the package.

## Package Installation

Installation is a later explicit administrative step:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Install /path/to/ZnunyAgentList-1.2.0.opm" otrs
```

Do not run installation from the Windows development environment.

## Configuration Rebuild and Cache Cleanup

After package installation, rebuild config and clear cache as separate administrative steps:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Maint::Config::Rebuild" otrs
su -s /bin/bash -c "bin/otrs.Console.pl Maint::Cache::Delete" otrs
```

## Web Service Route Mapping

After installation and required Znuny administration steps, manually add the operations to the intended GenericInterface web service in Znuny Admin > Web Services.

Validate that the operation names appear as expected, especially:

```text
ZnunyAgentList::Config
ZnunyAgentList::Health
```

Do not expose the web service publicly without network-level restrictions.

## REST Testing Checklist

On the real Znuny 6.5.20 server, validate:

- unauthenticated requests are rejected;
- invalid credentials are rejected;
- authenticated customer users are rejected;
- authenticated agents without `api_group` `ro` permission are rejected;
- the dedicated API agent with `api_group` `ro` permission is allowed;
- `Health` requires authentication and group permission;
- customer search rejects wildcard-only values;
- response payloads contain only explicit allow-listed fields;
- `ValidateTicketCreate` returns validation results without creating tickets;
- write operations require `ZnunyAgentList::EnableTicketWriteOperations = 1` and membership in `ZnunyAgentList::AllowedWriteGroups`.

## Upgrade Checklist

Before production upgrade use:

- build the new `.opm` on the Znuny server;
- verify package metadata and installed file list;
- test GenericInterface operation discovery;
- test authentication and group authorization;
- test REST behavior for every route;
- confirm no unexpected package-owned files are added.

## Uninstall Checklist

Before production uninstall use:

- review package-owned files from the SOPM;
- confirm no database objects or migrations are involved;
- uninstall through Znuny Package Manager tooling only after explicit approval;
- rebuild config and clear cache as separate administrative steps if required;
- confirm only package-owned files were removed.

## Troubleshooting

- If operations do not appear in Web Service configuration, confirm package installation, config rebuild, cache cleanup, and XML registration.
- If every request fails with `ZnunyAgentList.AuthFail`, confirm GenericInterface credentials, `UserType`, `ZnunyAgentList::AllowedGroups`, and `ro` permission in `api_group`.
- If customer search returns an empty list with a warning, confirm the search contains at least 2 non-wildcard characters.
- If service, SLA, or type operations return warnings, confirm the optional Znuny subsystem is enabled and available.
- If package build fails, run `bash scripts/verify-source.sh` and confirm the `otrs` user can read the source tree and write the output directory.

## Security Notes

- Use a dedicated API agent, not a normal human admin account.
- Keep `ZnunyAgentList::AllowedGroups` narrow.
- Restrict network access to the GenericInterface endpoint.
- Do not store credentials, tokens, or session IDs in this repository.
- Do not add raw SQL, migrations, core modifications, write operations, or automatic deployment helpers.

## Development Notes

- Local Windows checks are useful for Git hygiene only.
- Runtime syntax checks, package build, installation, operation discovery, and REST testing require the real Znuny 6.5.20 server.
- Current package version is `1.2.0`.
- Do not add new GenericInterface operations without updating XML, SOPM, docs, and server-side validation.
