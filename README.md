# ZnunyAgentList

## Purpose

`ZnunyAgentList` is a standalone Znuny 6.5 GenericInterface helper package for external integrations that need safe lookup data and TicketCreate preflight validation.

The package name remains `ZnunyAgentList` and the package version is `1.1.0`.

## What This Package Does

- Registers read-only GenericInterface operations for agents, queues, customer users, ticket dictionaries, package config, and package health.
- Provides a non-mutating `Ticket::ValidateTicketCreate` operation that checks a future TicketCreate payload without creating a ticket.
- Uses standard GenericInterface authentication.
- Requires an authenticated Znuny agent user.
- Requires `ro` permission in at least one group configured in `ZnunyAgentList::AllowedGroups`.
- Returns explicit allow-listed response fields only.

## What This Package Does Not Do

- Does not create tickets.
- Does not modify tickets, queues, users, customer users, services, SLAs, states, priorities, types, preferences, config, groups, roles, or database rows.
- Does not call `TicketCreate`.
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

Access is allowed only when all of these are true:

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
| `/ResolveTicketDefaults?...` | GET | `Ticket::ResolveTicketDefaults` | Resolve queue/customer defaults from host name | Business misses return warnings |
| `/TicketState` | GET | `Ticket::StateList` | List valid ticket states | Dictionary values only |
| `/TicketPriority` | GET | `Ticket::PriorityList` | List valid ticket priorities | Dictionary values only |
| `/TicketType` | GET | `Ticket::TypeList` | List valid ticket types | Empty list with warning if unavailable |
| `/Service` | GET | `Ticket::ServiceList` | List valid services | Empty list with warning if unavailable |
| `/SLA` | GET | `Ticket::SLAList` | List valid SLAs | Empty list with warning if unavailable |
| `/SystemConfig` | GET | `ZnunyAgentList::Config` | Return package capabilities | No sensitive environment data |
| `/Health` | GET | `ZnunyAgentList::Health` | Return package health status | Authenticated, not public |
| `/ValidateTicketCreate` | POST | `Ticket::ValidateTicketCreate` | Validate future TicketCreate data | Never creates or modifies tickets |

## Suggested REST Route Mapping

The package registers operations only. REST routes are mapped manually in Znuny Admin > Web Services.

Use the operation names from the table above when adding operations to the intended GenericInterface web service. The suggested routes are examples and can be adjusted to local naming standards.

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

`Ticket::StateList`:

```json
{
  "TicketStates": [
    {
      "ID": 1,
      "Name": "new",
      "ValidID": 1
    }
  ]
}
```

`ZnunyAgentList::Config`:

```json
{
  "Plugin": "ZnunyAgentList",
  "Version": "1.1.0",
  "Features": {
    "AgentList": true,
    "CustomerUserSearch": true,
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
  "Version": "1.1.0",
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
/path/to/output/ZnunyAgentList-1.1.0.opm
```

Building does not install the package.

## Package Installation

Installation is a later explicit administrative step:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Install /path/to/ZnunyAgentList-1.1.0.opm" otrs
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
- no operation writes data.

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
- Current package version is `1.1.0`.
- Do not add new GenericInterface operations without updating XML, SOPM, docs, and server-side validation.
