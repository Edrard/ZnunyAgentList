# ZnunyAgentList

`ZnunyAgentList` is a standalone Znuny 6.5 LTS GenericInterface extension for
integration systems such as Laravel, Zabbix, monitoring tools, and service
automation jobs.

Current stable runtime version: `1.2.6`.

The package provides a controlled REST surface for:

- safe read/list operations;
- safe ticket lookup and search operations;
- validation-only ticket creation preflight checks;
- controlled ticket lifecycle writes;
- optional compatibility routes for standard Znuny GenericTicketConnector
  operations in the repository Web Service template.

It is designed to expose useful integration data without exposing raw database
access, unrestricted ticket updates, or full internal Znuny records.

## Security Model

GenericInterface authentication is always required.

Read access is allowed only when all of these checks pass:

- GenericInterface authentication succeeds.
- The authenticated user is a Znuny agent.
- `UserType` is `User`.
- The authenticated agent belongs to at least one group configured in
  `ZnunyAgentList::AllowedGroups`.
- The agent has at least `ro` permission in one allowed group.

Authentication, wrong user type, missing groups, or missing permissions return a
generic package authentication failure:

```text
ZnunyAgentList.AuthFail
```

The default read group is:

```text
api_group
```

Use a dedicated API agent account. Do not use normal human admin accounts for
automation.

## Write Protection Model

Controlled write operations are intentionally separate from read access.

Write operations are disabled by default. Importing the Web Service template does
not enable writes.

Write access is allowed only when all of these checks pass:

- GenericInterface authentication succeeds.
- The authenticated user is a Znuny agent.
- `UserType` is `User`.
- `ZnunyAgentList::EnableTicketWriteOperations = 1`.
- `ZnunyAgentList::AllowedWriteGroups` is configured and non-empty.
- The authenticated agent belongs to at least one configured write group.
- The authenticated agent has at least `ro` permission in that write group.

Expected write-related SysConfig keys:

```text
ZnunyAgentList::EnableTicketWriteOperations
ZnunyAgentList::AllowedWriteGroups
ZnunyAgentList::CloseState
ZnunyAgentList::ReopenState
```

Common safe configuration:

```text
ZnunyAgentList::AllowedGroups = api_group
ZnunyAgentList::EnableTicketWriteOperations = 1
ZnunyAgentList::AllowedWriteGroups = api_group
ZnunyAgentList::CloseState = closed successful
ZnunyAgentList::ReopenState = open
```

For read-only deployments, keep:

```text
ZnunyAgentList::EnableTicketWriteOperations = 0
```

The package does not expose a generic runtime `TicketUpdate` operation.
Controlled write operations do not accept unsafe article internals and do not let
callers control fields such as:

```text
ArticleType
SenderType
HistoryType
HistoryComment
From
To
Cc
Bcc
MimeType
Charset
Loop
AutoResponseType
```

`Kind` is limited by the package to safe values such as `internal_note` and
`reply`. `Ticket::Close` and `Ticket::Reopen` use configured safe target states
from SysConfig; they are not arbitrary caller-controlled state updates.

## What The Package Does Not Do

- It does not create tickets.
- It does not expose a custom unrestricted runtime `TicketUpdate` wrapper.
- It does not modify queues, users, customer users, services, SLAs, states,
  priorities, types, groups, roles, preferences, or database rows.
- It does not use raw SQL.
- It does not add database migrations.
- It does not modify Znuny core files.
- It does not edit `ZZZAAuto.pm`.
- It does not create `api_group` automatically.
- It does not install, upgrade, uninstall, rebuild config, clear cache, import a
  Web Service, or deploy automatically.

## Supported Environment

- Znuny: `6.5.x` LTS
- Current validation target: Znuny `6.5.20`
- Typical Znuny home: `/opt/otrs`
- Typical runtime user: `otrs`
- Typical server OS: Rocky Linux 8
- Local development: Windows source editing and Git workflow

Perl syntax checks, package builds, package installation, operation discovery,
and REST behavior must be validated on the real Znuny server.

## Web Service Template

The package installs GenericInterface operation modules and SysConfig
registration. REST routes are configured in a Znuny Web Service.

The repository includes an import template:

```text
examples/webservices/AdvancedZnunyAgentListREST.yml
```

The template is not installed automatically by the `.opm` package. Import it
manually in Znuny Admin after package installation.

If routes change, the Web Service template must be re-imported or adjusted in
Znuny Admin because Web Service configuration is stored in the Znuny database.

The template contains:

- package-specific safe and controlled `ZnunyAgentList` operations;
- standard GenericTicketConnector compatibility routes for existing clients.

`PATCH /Ticket/:TicketID` is a standard GenericTicketConnector compatibility
route in the example Web Service template only. The package itself does not
install a custom unrestricted runtime `TicketUpdate` wrapper.

## Authentication Examples

Use placeholders only. Do not store real credentials in this repository.

Session-based authentication:

```bash
curl -sk -X POST \
  "https://znuny.example.invalid/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Session" \
  -H "Content-Type: application/json" \
  -d '{"UserLogin":"API_USER","Password":"API_PASSWORD"}'
```

GET request with query-string authentication:

```bash
curl -sk \
  "https://znuny.example.invalid/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Health?UserLogin=API_USER&Password=API_PASSWORD"
```

Query-string authentication can be useful for smoke tests, but credentials in
URLs may be exposed through logs, browser history, or intermediary systems. Use
session or header-based authentication when appropriate for your Web Service
configuration.

## Package Operations

All package operations require GenericInterface authentication and the read
authorization checks described above unless explicitly marked as write
operations.

### Read And List Operations

| Method | Route | Operation | Purpose | Important Parameters | Response Shape |
| --- | --- | --- | --- | --- | --- |
| `GET` | `/Health` | `ZnunyAgentList::Health` | Authenticated package health | none | `Plugin`, `Version`, `Success`, `Time` |
| `GET` | `/SystemConfig` | `ZnunyAgentList::Config` | Package capabilities/config summary | none | `Plugin`, `Version`, `Features`, `WriteProtection` |
| `GET` | `/Agent` | `User::AgentList` | List valid active agents | none | `Agents[]` with `UserID`, `UserLogin`, `UserFullname` |
| `GET` | `/Queue` | `Queue::List` | List valid queues | none | `Queues[]` |
| `GET` | `/Queue/:QueueID` | `Queue::Get` | Get queue by numeric ID | `QueueID` path parameter | `Queue.Found`, queue metadata |
| `GET` | `/QueueByName/:Name` | `Queue::Get` | Get queue by name | `Name` path parameter | `Queue.Found`, queue metadata |
| `GET` | `/CustomerUser?Search=...&Limit=...` | `CustomerUser::Search` | Search customer users | `Search`, optional `Limit` capped at `50` | `CustomerUsers[]`, optional `Warnings[]` |
| `GET` | `/CustomerUser/:CustomerUserLogin` | `CustomerUser::Get` | Get one customer user | `CustomerUserLogin` path parameter | `CustomerUser.Found`, safe customer fields |
| `GET` | `/TicketState` | `Ticket::StateList` | List ticket states | none | `TicketStates[]` |
| `GET` | `/TicketPriority` | `Ticket::PriorityList` | List ticket priorities | none | `TicketPriorities[]` |
| `GET` | `/TicketType` | `Ticket::TypeList` | List ticket types | none | `TicketTypes[]`, optional warnings |
| `GET` | `/Service` | `Ticket::ServiceList` | List services | none | `Services[]`, optional warnings |
| `GET` | `/SLA` | `Ticket::SLAList` | List SLAs | none | `SLAs[]`, optional warnings |
| `GET` | `/ResolveTicketDefaults?Hostname=...` | `Ticket::ResolveTicketDefaults` | Resolve queue/customer defaults from host name | `Hostname` | `Input`, `Detected`, `Queue`, `CustomerUser`, `Warnings[]` |
| `GET` | `/ResolveTicketDefaults?HostName=...` | `Ticket::ResolveTicketDefaults` | Same as above with alternate parameter spelling | `HostName` | `Input`, `Detected`, `Queue`, `CustomerUser`, `Warnings[]` |
| `POST` | `/ValidateTicketCreate` | `Ticket::ValidateTicketCreate` | Validate future TicketCreate data without creating a ticket | `OwnerID`, `Queue`, `CustomerUser`, `State`, `Lock` as available | `Valid`, `Errors[]`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicket/:TicketID` | `Ticket::Get` | Safe ticket lookup by ID | `TicketID` path parameter | `Found`, `Ticket`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicketNumber/:TicketNumber` | `Ticket::Get` | Safe ticket lookup by number | `TicketNumber` path parameter | `Found`, `Ticket`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicketSearch` | `Ticket::Search` | Safe filtered ticket search | filters such as `TicketNumber`, `Queue`, `StateType`, `Limit`, `Offset`, `Page`, `SortBy`, `SortDirection` | `Tickets[]`, `Count`, `Limit`, `Offset`, `Warnings[]` |

`/CustomerUser/:CustomerUserLogin` intentionally uses a customer-specific path
parameter name. This avoids conflict with the GenericInterface authentication
parameter named `UserLogin`.

`CustomerUser::Search` requires at least two meaningful non-wildcard characters
after removing `*`, `%`, and `?` from a validation copy of the search string.
Wildcard-only searches return an empty result with a warning.

`Ticket::Search` requires at least one meaningful filter. Unfiltered searches
return an empty `Tickets` array and the warning:

```text
At least one search filter is required.
```

Exact `TicketNumber` searches use the package safe ticket lookup path and do not
fall through to an unrestricted broad ticket search.

### Controlled Write Operations

These operations require read authorization plus the additional write protection
checks documented above.

| Method | Route | Operation | Purpose | Important Parameters | Response Shape |
| --- | --- | --- | --- | --- | --- |
| `POST` | `/TicketArticle` | `Ticket::ArticleCreate` | Add a controlled internal note or reply | `TicketID` or `TicketNumber`, `Kind`, `Subject`, `Body` | `ArticleID`, `TicketID`, `TicketNumber`, `Warnings[]` |
| `POST` | `/TicketClose` | `Ticket::Close` | Add a note and move ticket to configured close state | `TicketID` or `TicketNumber`, `Reason`, optional `Kind`, `Subject`, `Body` | `TicketID`, `TicketNumber`, `State`, `StateType`, `ArticleID` |
| `POST` | `/TicketReopen` | `Ticket::Reopen` | Add a note and move ticket to configured reopen state | `TicketID` or `TicketNumber`, `Reason`, optional `Kind`, `Subject`, `Body` | `TicketID`, `TicketNumber`, `State`, `StateType`, `ArticleID` |

Example `POST /TicketArticle` body:

```json
{
  "TicketID": "TICKET_ID",
  "Kind": "internal_note",
  "Subject": "Investigation note",
  "Body": "Checked monitoring data and added internal context."
}
```

Example `POST /TicketClose` body:

```json
{
  "TicketID": "TICKET_ID",
  "Kind": "internal_note",
  "Subject": "Problem resolved",
  "Body": "Monitoring problem was resolved.",
  "Reason": "Problem resolved from integration workflow."
}
```

Example `POST /TicketReopen` body:

```json
{
  "TicketID": "TICKET_ID",
  "Kind": "internal_note",
  "Subject": "Problem reappeared",
  "Body": "Monitoring problem reappeared.",
  "Reason": "Problem reappeared in monitoring."
}
```

## GenericTicketConnector Compatibility Routes

The example Web Service template includes these standard Znuny
GenericTicketConnector compatibility routes:

| Method | Route | Standard Operation | Notes |
| --- | --- | --- | --- |
| `POST` | `/Session` | `Session::SessionCreate` | Creates a GenericInterface session. |
| `GET` | `/Session` | `Session::SessionGet` | Reads session data, typically with `SessionID`. |
| `GET` | `/Session/:SessionID` | `Session::SessionGet` | Reads session data using path parameter. |
| `POST` | `/Ticket` | `Ticket::TicketCreate` | Standard GenericTicketConnector create route from Znuny, not a package runtime module. |
| `GET` | `/Ticket/:TicketID` | `Ticket::TicketGet` | Standard ticket get route. |
| `GET` | `/TicketList` | `Ticket::TicketGetList` | Standard ticket list route. |
| `GET` | `/TicketHistory/:TicketID` | `Ticket::TicketHistoryGet` | Standard ticket history route. |
| `GET` | `/Ticket` | `Ticket::TicketSearch` | Standard ticket search route. |
| `PATCH` | `/Ticket/:TicketID` | `Ticket::TicketUpdate` | Standard compatibility route only; not installed by this package as a runtime wrapper. |

Administrators can remove or disable compatibility operations from the imported
Web Service if they want a strictly package-controlled surface.

## Response Shapes

Package operations return GenericInterface JSON responses. Successful package
operations use:

```json
{
  "Success": 1,
  "Data": {}
}
```

Business misses are not necessarily transport errors. They return `Success: 1`
with fields such as:

```json
{
  "Found": 0,
  "Warnings": ["Queue not found."]
}
```

Authentication or authorization failures return an error body similar to:

```json
{
  "Error": {
    "ErrorCode": "ZnunyAgentList.AuthFail",
    "ErrorMessage": "ZnunyAgentList: Authentication failed."
  }
}
```

Znuny GenericInterface can return HTTP 200 for application-level errors.
Integrations must inspect the JSON body for `Success`, `Data`, and `Error`, not
only the HTTP status code.

Safe ticket metadata is explicitly allow-listed and does not expose full ticket
or internal Perl object data. Typical safe ticket fields include:

```json
{
  "TicketID": "TICKET_ID",
  "TicketNumber": "TICKET_NUMBER",
  "Title": "Example ticket",
  "Queue": "Support",
  "State": "open",
  "StateType": "open",
  "Priority": "3 normal",
  "Created": "2026-06-18 10:00:00",
  "Changed": "2026-06-18 10:15:00"
}
```

## API Response Examples

The examples below show the package-specific response payloads integrations
should expect from `ZnunyAgentList` operations. Depending on the GenericInterface
transport/client, Znuny may wrap these values inside a top-level transport
structure. Integrations should inspect JSON body fields such as `Error`,
`Success`, `Data`, `Found`, `Warnings`, and `Errors`, not only HTTP status.

Standard GenericTicketConnector compatibility routes follow standard Znuny
GenericTicketConnector response shapes and are not documented in detail here.

### Health

`GET /Health`

```json
{
  "Plugin": "ZnunyAgentList",
  "Version": "1.2.6",
  "Success": 1,
  "Time": "2026-06-18 12:00:00"
}
```

### Package Configuration

`GET /SystemConfig`

```json
{
  "Plugin": "ZnunyAgentList",
  "Version": "1.2.6",
  "Features": {
    "AgentList": 1,
    "QueueList": 1,
    "CustomerUserSearch": 1,
    "TicketGet": 1,
    "TicketSearch": 1,
    "TicketArticleCreate": 1,
    "TicketClose": 1,
    "TicketReopen": 1,
    "ValidateTicketCreate": 1
  }
}
```

### Agents

`GET /Agent`

```json
{
  "Agents": [
    {
      "UserID": 42,
      "UserLogin": "api.integration",
      "UserFullname": "API Integration"
    }
  ]
}
```

### Queues

`GET /Queue`

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

`GET /Queue/:QueueID` and `GET /QueueByName/:Name`

```json
{
  "Queue": {
    "Found": 1,
    "QueueID": 12,
    "Name": "Support",
    "FullName": "Support",
    "ValidID": 1
  }
}
```

### Customer Users

`GET /CustomerUser?Search=example&Limit=10`

```json
{
  "CustomerUsers": [
    {
      "UserLogin": "example.customer",
      "UserCustomerID": "example-customer",
      "UserFirstname": "Example",
      "UserLastname": "Customer",
      "UserEmail": "customer@example.invalid"
    }
  ]
}
```

`GET /CustomerUser/:CustomerUserLogin`

```json
{
  "CustomerUser": {
    "Found": 1,
    "UserLogin": "example.customer",
    "UserCustomerID": "example-customer",
    "UserFirstname": "Example",
    "UserLastname": "Customer",
    "UserEmail": "customer@example.invalid"
  }
}
```

Wildcard-only or too-short customer searches return an empty result and warning:

```json
{
  "CustomerUsers": [],
  "Warnings": [
    "Search must contain at least 2 non-wildcard characters."
  ]
}
```

### Ticket Dictionaries

`GET /TicketState`

```json
{
  "TicketStates": [
    {
      "ID": 4,
      "StateID": 4,
      "Name": "open",
      "State": "open",
      "StateTypeID": 2,
      "StateType": "open",
      "ValidID": 1
    }
  ]
}
```

`GET /TicketPriority`

```json
{
  "TicketPriorities": [
    {
      "ID": 3,
      "PriorityID": 3,
      "Name": "normal",
      "Priority": "normal",
      "ValidID": 1
    }
  ]
}
```

`GET /TicketType`

```json
{
  "TicketTypes": [
    {
      "ID": 1,
      "TypeID": 1,
      "Name": "Incident",
      "ValidID": 1
    }
  ],
  "Warnings": []
}
```

`GET /Service`

```json
{
  "Services": [
    {
      "ID": 10,
      "ServiceID": 10,
      "Name": "Example Service",
      "ValidID": 1
    }
  ],
  "Warnings": []
}
```

`GET /SLA`

```json
{
  "SLAs": [
    {
      "ID": 5,
      "SLAID": 5,
      "Name": "Example SLA",
      "ValidID": 1
    }
  ],
  "Warnings": []
}
```

### Defaults And TicketCreate Validation

`GET /ResolveTicketDefaults?Hostname=Support-host`

```json
{
  "Input": {
    "HostName": "Support-host"
  },
  "Detected": {
    "QueueName": "Support-host",
    "CustomerUserLogin": "Support-hostClients"
  },
  "Queue": {
    "Found": 0
  },
  "CustomerUser": {
    "Found": 0
  },
  "Warnings": [
    "Queue not found.",
    "CustomerUser not found."
  ]
}
```

`POST /ValidateTicketCreate`

```json
{
  "Valid": 1,
  "Errors": [],
  "Warnings": []
}
```

Validation failures keep HTTP transport success but return `Valid: 0`:

```json
{
  "Valid": 0,
  "Errors": [
    "Queue not found.",
    "CustomerUser not found."
  ],
  "Warnings": []
}
```

### Safe Ticket Lookup

`GET /ZnunyAgentListTicket/:TicketID`

```json
{
  "Found": 1,
  "Ticket": {
    "TicketID": 12345,
    "TicketNumber": "202601010000001",
    "Title": "Example ticket",
    "QueueID": 12,
    "Queue": "Support",
    "OwnerID": 42,
    "Owner": "api.integration",
    "CustomerUserID": "example-customer",
    "CustomerUser": "example.customer",
    "StateID": 4,
    "State": "open",
    "StateType": "open",
    "PriorityID": 3,
    "Priority": "normal",
    "Created": "2026-01-01 10:00:00",
    "Changed": "2026-01-01 10:15:00"
  },
  "Warnings": []
}
```

`GET /ZnunyAgentListTicketNumber/:TicketNumber` returns the same safe ticket
shape using `TicketNumber` lookup.

Not found:

```json
{
  "Found": 0,
  "Ticket": null,
  "Warnings": [
    "Ticket not found."
  ]
}
```

### Safe Ticket Search

`GET /ZnunyAgentListTicketSearch`

```json
{
  "Tickets": [],
  "Count": 0,
  "Limit": 50,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": [
    "At least one search filter is required."
  ]
}
```

`GET /ZnunyAgentListTicketSearch?TicketNumber=202601010000001`

```json
{
  "Tickets": [
    {
      "TicketID": 12345,
      "TicketNumber": "202601010000001",
      "Title": "Example ticket",
      "Queue": "Support",
      "State": "open",
      "StateType": "open"
    }
  ],
  "Count": 1,
  "Limit": 50,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": []
}
```

`GET /ZnunyAgentListTicketSearch?Queue=Support&StateType=open&Limit=5`

```json
{
  "Tickets": [
    {
      "TicketID": 12345,
      "TicketNumber": "202601010000001",
      "Title": "Example ticket",
      "Queue": "Support",
      "State": "open",
      "StateType": "open"
    }
  ],
  "Count": 1,
  "Limit": 5,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": []
}
```

### Controlled Write Responses

`POST /TicketArticle`

```json
{
  "TicketID": 12345,
  "TicketNumber": "202601010000001",
  "ArticleID": 67890,
  "Kind": "internal_note",
  "Warnings": []
}
```

`POST /TicketClose`

```json
{
  "Ticket": {
    "TicketID": 12345,
    "TicketNumber": "202601010000001",
    "Title": "Example ticket",
    "Queue": "Support",
    "State": "closed successful",
    "StateType": "closed"
  },
  "ArticleID": 67891,
  "State": "closed successful",
  "Reason": "Problem resolved from integration workflow.",
  "Warnings": []
}
```

`POST /TicketReopen`

```json
{
  "Ticket": {
    "TicketID": 12345,
    "TicketNumber": "202601010000001",
    "Title": "Example ticket",
    "Queue": "Support",
    "State": "open",
    "StateType": "open"
  },
  "ArticleID": 67892,
  "State": "open",
  "Reason": "Problem reappeared in monitoring.",
  "Warnings": []
}
```

### Error Responses

Authentication or read authorization failure:

```json
{
  "Error": {
    "ErrorCode": "ZnunyAgentList.AuthFail",
    "ErrorMessage": "ZnunyAgentList: Authentication failed."
  }
}
```

Write authorization failure:

```json
{
  "Error": {
    "ErrorCode": "ZnunyAgentList.WriteForbidden",
    "ErrorMessage": "ZnunyAgentList: Write operation is forbidden."
  }
}
```

## Installation And Update Workflow

Use the real Znuny server for package verification, build, install, upgrade, and
runtime validation.

Users can either download the verified `.opm` package from the GitHub Release or
build it themselves in their own Znuny/Linux environment. Do not commit generated
`.opm` files or checksum files to Git.

1. Clone or update the repository on the Znuny server:

```bash
git clone <REPOSITORY_URL> /path/to/ZnunyAgentList
cd /path/to/ZnunyAgentList
git pull --ff-only
```

2. Run read-only source verification:

```bash
bash scripts/verify-source.sh
```

3. Build the `.opm` package on the Znuny server:

```bash
bash scripts/build-package.sh /path/to/ZnunyAgentList /path/to/output
```

This creates:

```text
/path/to/output/ZnunyAgentList-1.2.6.opm
```

4. Install or upgrade with the Znuny console as `otrs`.

Install:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Install /path/to/output/ZnunyAgentList-1.2.6.opm" otrs
```

Upgrade:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Upgrade /path/to/output/ZnunyAgentList-1.2.6.opm" otrs
```

5. Rebuild configuration and delete cache:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Maint::Config::Rebuild" otrs
su -s /bin/bash -c "bin/otrs.Console.pl Maint::Cache::Delete" otrs
```

6. Restart the web server using the site's normal service-management process.

7. Import or re-import the Web Service template if route mappings changed:

```text
examples/webservices/AdvancedZnunyAgentListREST.yml
```

Because Web Service configuration is stored in the Znuny database, updating the
repository or installing a new `.opm` does not automatically update an already
imported Web Service.

## Testing Workflow

Run source verification:

```bash
cd /path/to/ZnunyAgentList
bash scripts/verify-source.sh
```

Run the full integration smoke test:

```bash
bash scripts/test-advanced-znuny-agentlist-all.sh
```

On first run, the smoke test creates:

```text
scripts/test-advanced-znuny-agentlist-all.env
```

The generated env file contains local test configuration and must not be
committed. It is ignored by `.gitignore`.

The smoke test is read-only by default. Controlled write lifecycle tests run only
when explicitly enabled:

```bash
RUN_WRITE_TESTS=yes bash scripts/test-advanced-znuny-agentlist-all.sh
```

The smoke test covers:

- health and package config;
- session compatibility;
- agents;
- queues;
- customer users;
- ticket dictionaries;
- default resolution and validation;
- safe ticket get/search;
- GenericTicketConnector read compatibility;
- optional controlled write lifecycle.

The smoke test requires local configuration values such as base URL, API user,
ticket ID, ticket number, queue name, customer login, hostname, and log
directory. Do not hardcode those values into the repository.

## Source Layout

Package runtime files:

```text
ZnunyAgentList.sopm
Kernel/Config/Files/XML/ZnunyAgentList.xml
Kernel/GenericInterface/Operation/ZnunyAgentList/Common.pm
Kernel/GenericInterface/Operation/ZnunyAgentList/Config.pm
Kernel/GenericInterface/Operation/ZnunyAgentList/Health.pm
Kernel/GenericInterface/Operation/User/AgentList.pm
Kernel/GenericInterface/Operation/Queue/*.pm
Kernel/GenericInterface/Operation/CustomerUser/*.pm
Kernel/GenericInterface/Operation/Ticket/*.pm
```

Repository-only helpers:

```text
scripts/verify-source.sh
scripts/build-package.sh
scripts/test-advanced-znuny-agentlist-all.sh
examples/webservices/AdvancedZnunyAgentListREST.yml
```

The package does not install README, scripts, Web Service YAML templates, Git
metadata, logs, review files, or generated `.opm` files.

## Troubleshooting

- If every package request returns `ZnunyAgentList.AuthFail`, check the API
  credentials, `UserType`, `ZnunyAgentList::AllowedGroups`, and group `ro`
  permission.
- If write operations return `ZnunyAgentList.WriteForbidden`, check
  `ZnunyAgentList::EnableTicketWriteOperations`, `AllowedWriteGroups`, and write
  group membership.
- If `/CustomerUser/:CustomerUserLogin` fails with authentication errors, verify
  the imported Web Service route uses `CustomerUserLogin`, not `UserLogin`.
- If `ResolveTicketDefaults` returns warnings, verify that the hostname first
  token maps to the intended queue and customer user naming rule.
- If the smoke test reports a missing route after a YAML route change, re-import
  or update the Web Service in Znuny Admin.
- If operations do not appear in Web Service configuration, verify package
  installation, config rebuild, cache cleanup, and SysConfig operation
  registration.

## Development Notes

- Keep runtime changes, Web Service template changes, scripts, and documentation
  in sync.
- Do not commit generated `.opm` files, local smoke-test env files, logs,
  credentials, tokens, or session IDs.
- Do not add raw SQL, migrations, Znuny core modifications, or automatic
  deployment actions.
- Local Windows checks are Git hygiene only. Runtime validation belongs on the
  real Znuny server.
