# ZnunyAgentList

`ZnunyAgentList` is a standalone Znuny 6.5 LTS GenericInterface extension for
integration systems such as Laravel, Zabbix, monitoring tools, and service
automation jobs.

Current package version: `1.3.1`.

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

`Ticket::Lock` and `Ticket::Unlock` use the same write authorization checks.
They change only ticket lock state and do not create articles, notes, or replies.
Znuny may still record its normal internal ticket history for these actions.

`Ticket::MoveAssignValidate` and `Ticket::MoveAssign` use the same write
authorization checks. They expose only queue and owner targets, prevalidate a
combined queue/owner change before modifying the ticket, and use standard Znuny
`TicketQueueSet()` and `TicketOwnerSet()` APIs. No raw SQL or custom unrestricted
runtime `TicketUpdate` operation is used.

## What The Package Does Not Do

- It does not create tickets.
- It does not expose a custom unrestricted runtime `TicketUpdate` wrapper.
- It does not modify queues, users, customer users, services, SLAs, states,
  priorities, types, groups, roles, or preferences.
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
| `GET` | `/SystemConfig` | `ZnunyAgentList::Config` | Package capabilities/config summary | none | `Plugin`, `Version`, `Features`, `Znuny` |
| `GET` | `/Agent` | `User::AgentList` | List valid active agents | none | `Agents[]` with `UserID`, `UserLogin`, `UserFullname` |
| `GET` | `/Queue` | `Queue::List` | List valid queues | none | `Queues[]` |
| `GET` | `/Queue/:QueueID` | `Queue::Get` | Get queue by numeric ID | `QueueID` path parameter | `Queue.Found`, queue metadata |
| `GET` | `/QueueByName/:Name` | `Queue::Get` | Get queue by name | `Name` path parameter | `Queue.Found`, queue metadata |
| `GET` | `/Queue/:QueueID/AssignableAgents` | `Queue::AssignableAgents` | List active agents allowed to own tickets in a queue | `QueueID` path parameter | `Success`, `QueueID`, `QueueName`, `Agents[]`, `Errors[]` |
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
| `GET` | `/ZnunyAgentListTicket/:TicketID` | `Ticket::Get` | Safe ticket lookup by ID | `TicketID` path parameter | `Found`, safe ticket metadata, article sync summary, `SyncFingerprint`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicketNumber/:TicketNumber` | `Ticket::Get` | Safe ticket lookup by number | `TicketNumber` path parameter | `Found`, safe ticket metadata, article sync summary, `SyncFingerprint`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicketSearch` | `Ticket::Search` | Safe filtered ticket search and total counting | filters such as `TicketNumber`, `Queue`, `StateType`, `CountOnly`, `Limit`, `Offset`, `Page`, `SortBy`, `SortDirection` | Safe `Tickets[]`, page `Count`, matching `TotalCount`, pagination, `Warnings[]` |

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
| `POST` | `/TicketLock` | `Ticket::Lock` | Change only the ticket lock state to `lock` | `TicketID` or `TicketNumber` | Safe ticket metadata including `LockID` and `Lock`, `Warnings[]` |
| `POST` | `/TicketUnlock` | `Ticket::Unlock` | Change only the ticket lock state to `unlock` | `TicketID` or `TicketNumber` | Safe ticket metadata including `LockID` and `Lock`, `Warnings[]` |
| `POST` | `/TicketMoveAssign/Validate` | `Ticket::MoveAssignValidate` | Validate a queue move and/or owner assignment without changing the ticket | `TicketID`, optional queue target, optional owner target, conditional `Note` | `Valid`, `RequiredNote`, `Current`, `Target`, `Errors[]`, `Warnings[]` |
| `POST` | `/TicketMoveAssign` | `Ticket::MoveAssign` | Apply a prevalidated queue move and/or owner assignment | `TicketID`, optional queue target, optional owner target, conditional `Note` | `Success`, `QueueChanged`, `OwnerChanged`, `NoteCreated`, `Before`, `After`, `Errors[]`, `Warnings[]` |

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

Example `POST /TicketLock` body:

```json
{
  "TicketNumber": "2026062346000357"
}
```

Example `POST /TicketUnlock` body:

```json
{
  "TicketNumber": "2026062346000357"
}
```

Lock/unlock accepts only ticket identity, does not require a reason, and does
not expose generic unrestricted `TicketUpdate` fields.

Example `POST /TicketMoveAssign/Validate` body:

```json
{
  "TicketID": "57250",
  "QueueID": "108",
  "OwnerID": "30",
  "Note": "Moving the ticket to the responsible engineer."
}
```

Example `POST /TicketMoveAssign` body:

```json
{
  "TicketID": "57250",
  "QueueName": "Support::Projects",
  "UserLogin": "assigned.agent",
  "Note": "Assigning the ticket to the responsible engineer."
}
```

`TicketID` is required. A queue target may be supplied as `QueueID` or
`QueueName`, and an owner target as `OwnerID` or `UserLogin`. When both forms of
one identity are supplied, the numeric ID is authoritative and a mismatch is
reported as a warning. The ticket, queue, active owner, target queue owner
permission, and move permission are checked before either mutation runs.

Queue fields are optional for owner-only changes; when omitted, the current
ticket queue becomes the target queue for owner permission validation. Owner
fields are optional for queue-only changes; when omitted, the current owner is
preserved in the `Target` snapshot. Target-owner `UserLogin` is read only from
the JSON request body; the GenericInterface authentication query parameter
`UserLogin` is never treated as a target owner. Validation returns populated
`Current` data once the ticket is resolved and populated `Target` data once both
target values can be resolved, including when a later validation rule fails.

Owner changes require a non-empty `Note`. Queue-only changes do not require a
note. A queue-only change with a note creates one controlled internal note;
owner changes pass the note to the standard Znuny owner-change API and do not
create a duplicate article. Queue-plus-owner requests change the queue first and
then the owner after all validation succeeds. Validation failures modify
nothing.

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

Safe ticket lookup and search responses include `LockID` and `Lock` so clients
can display and synchronize the current ticket lock state.

Depending on Znuny/GenericInterface serialization, numeric identifiers and
counts such as `TicketID`, `QueueID`, `ArticleCount`, and `LastArticleID` may be
returned as JSON numbers or JSON strings. Integrations should treat them as
numeric identifiers or counts and normalize them client-side if strict typing is
required.

```json
{
  "TicketID": "TICKET_ID",
  "TicketNumber": "TICKET_NUMBER",
  "Title": "Example ticket",
  "QueueID": "10",
  "Queue": "Support",
  "OwnerID": "2",
  "Owner": "api.agent@example.invalid",
  "ResponsibleID": "0",
  "Responsible": "",
  "LockID": "1",
  "Lock": "unlock",
  "CustomerID": "example-customer",
  "CustomerUserID": "example-customer-user",
  "CustomerUser": "example-customer-user",
  "StateID": "4",
  "State": "open",
  "StateType": "open",
  "PriorityID": "3",
  "Priority": "3 normal",
  "TypeID": "1",
  "Type": "Incident",
  "ServiceID": "0",
  "Service": "",
  "SLAID": "0",
  "SLA": "",
  "Created": "2026-01-01 10:00:00",
  "Changed": "2026-01-01 10:30:00",
  "ArticleCount": "2",
  "LastArticleID": "67890",
  "LastArticleCreated": "2026-01-01 10:30:00",
  "SyncFingerprint": "4d967f2b7a1f4c7e9d0cbb7f3f7e2b8c4b3f0d4e2a1c9f8e7d6c5b4a3f2e1d0c"
}
```

`ArticleCount`, `LastArticleID`, and `LastArticleCreated` are derived from
Znuny's metadata-only article list. `SyncFingerprint` changes when ticket
metadata changes or when a new article, note, or reply is added. Safe ticket
search never returns article subjects, bodies, note text, reply text,
attachments, or full article metadata.

### SyncFingerprint

`SyncFingerprint` is a deterministic safe synchronization marker. It is based on
safe ticket metadata and article summary metadata, not on article body content.
It changes when ticket metadata changes or when a new article, note, or reply is
added. Integrations can store it locally and compare it on the next sync pass to
detect whether a linked ticket needs to be refreshed.

`SyncFingerprint` is not an authentication token and is not a security secret.
Safe ticket search returns only the article count and latest-article metadata
needed for synchronization. Clients that require full article content should use
an intentionally designed endpoint rather than `Ticket::Search`; this package
does not add such an endpoint.

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
  "Version": "1.3.1",
  "Success": 1,
  "Time": "2026-01-01 10:00:00"
}
```

### Package Configuration

`GET /SystemConfig`

```json
{
  "Plugin": "ZnunyAgentList",
  "Version": "1.3.1",
  "Features": {
    "AgentList": 1,
    "QueueList": 1,
    "QueueAssignableAgents": 1,
    "CustomerUserSearch": 1,
    "TicketGet": 1,
    "TicketSearch": 1,
    "TicketArticleCreate": 1,
    "TicketClose": 1,
    "TicketReopen": 1,
    "TicketLock": 1,
    "TicketUnlock": 1,
    "TicketMoveAssignValidate": 1,
    "TicketMoveAssign": 1,
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

`GET /Queue/:QueueID/AssignableAgents`

```json
{
  "Success": 1,
  "QueueID": 49,
  "QueueName": "Support::Projects",
  "Agents": [
    {
      "UserID": 2,
      "UserLogin": "assigned.agent",
      "UserFullname": "Assigned Agent"
    }
  ],
  "Errors": []
}
```

The list contains only active users allowed by Znuny's queue owner permission
logic and exposes only user ID, login, and formatted full name.

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
    "TicketID": "12345",
    "TicketNumber": "202601010000001",
    "Title": "Example ticket",
    "QueueID": "10",
    "Queue": "Support",
    "OwnerID": "2",
    "Owner": "api.agent@example.invalid",
    "ResponsibleID": "0",
    "Responsible": "",
    "LockID": "1",
    "Lock": "unlock",
    "CustomerID": "example-customer",
    "CustomerUserID": "example-customer-user",
    "CustomerUser": "example-customer-user",
    "StateID": "4",
    "State": "open",
    "StateType": "open",
    "PriorityID": "3",
    "Priority": "3 normal",
    "TypeID": "1",
    "Type": "Incident",
    "ServiceID": "0",
    "Service": "",
    "SLAID": "0",
    "SLA": "",
    "Created": "2026-01-01 10:00:00",
    "Changed": "2026-01-01 10:30:00",
    "ArticleCount": "2",
    "LastArticleID": "67890",
    "LastArticleCreated": "2026-01-01 10:30:00",
    "SyncFingerprint": "4d967f2b7a1f4c7e9d0cbb7f3f7e2b8c4b3f0d4e2a1c9f8e7d6c5b4a3f2e1d0c"
  },
  "Warnings": []
}
```

`GET /ZnunyAgentListTicketNumber/:TicketNumber` returns the same safe ticket
shape, including the article sync summary and `SyncFingerprint`, using
`TicketNumber` lookup:

```json
{
  "Found": 1,
  "Ticket": {
    "TicketID": "12345",
    "TicketNumber": "202601010000001",
    "QueueID": "10",
    "Queue": "Support",
    "LockID": "1",
    "Lock": "unlock",
    "ArticleCount": "2",
    "LastArticleID": "67890",
    "LastArticleCreated": "2026-01-01 10:30:00",
    "SyncFingerprint": "4d967f2b7a1f4c7e9d0cbb7f3f7e2b8c4b3f0d4e2a1c9f8e7d6c5b4a3f2e1d0c"
  },
  "Warnings": []
}
```

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

Endpoint:

```text
GET /ZnunyAgentListTicketSearch
```

At least one meaningful filter is required. An unfiltered request returns an
empty result with the warning `At least one search filter is required.`:

`GET /ZnunyAgentListTicketSearch`

```json
{
  "Tickets": [],
  "Count": 0,
  "TotalCount": 0,
  "Limit": 50,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": [
    "At least one search filter is required."
  ]
}
```

The count fields have distinct meanings:

```text
Count      = number of tickets returned in this page
TotalCount = total number of tickets matching the filters
CountOnly  = return only the total count, without ticket objects
```

`CountOnly` accepts `1`, `true`, `yes`, or `on`. Values `0`, `false`, `no`,
and `off` select normal paginated search.

Count active tickets without fetching ticket objects:

`GET /ZnunyAgentListTicketSearch?StateType=new,open&CountOnly=1`

```json
{
  "Tickets": [],
  "Count": 137,
  "TotalCount": 137,
  "CountOnly": 1,
  "Limit": 0,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": []
}
```

`CountOnly=1` uses the same filters as normal search. It does not fetch ticket
details or calculate article synchronization metadata.

`GET /ZnunyAgentListTicketSearch?CountOnly=1` still returns an empty safe result
with `TotalCount: 0`, `Limit: 0`, and the required-filter warning.

```json
{
  "Tickets": [],
  "Count": 0,
  "TotalCount": 0,
  "CountOnly": 1,
  "Limit": 0,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": [
    "At least one search filter is required."
  ]
}
```

Exact ticket number:

`GET /ZnunyAgentListTicketSearch?TicketNumber=2026062346000357`

State name:

```text
GET /ZnunyAgentListTicketSearch?State=new
GET /ZnunyAgentListTicketSearch?State=open
GET /ZnunyAgentListTicketSearch?State=closed%20successful
```

State type:

```text
GET /ZnunyAgentListTicketSearch?StateType=new
GET /ZnunyAgentListTicketSearch?StateType=open
GET /ZnunyAgentListTicketSearch?StateType=closed
```

Multiple state types can be supplied as a comma-separated value:

```text
GET /ZnunyAgentListTicketSearch?StateType=new,open
```

Queue, owner, and customer user:

```text
GET /ZnunyAgentListTicketSearch?Queue=Support
GET /ZnunyAgentListTicketSearch?Queue=Customer%20Projects
GET /ZnunyAgentListTicketSearch?OwnerID=2
GET /ZnunyAgentListTicketSearch?CustomerUserID=example-customer-user
```

Spaces and other reserved characters in query values must be URL encoded.

Pagination:

```text
GET /ZnunyAgentListTicketSearch?StateType=new,open&Limit=50&Offset=0
GET /ZnunyAgentListTicketSearch?StateType=new,open&Limit=50&Offset=50
GET /ZnunyAgentListTicketSearch?StateType=new,open&Limit=50&Offset=100
```

Sorting:

```text
GET /ZnunyAgentListTicketSearch?StateType=open&SortBy=Changed&SortDirection=DESC
GET /ZnunyAgentListTicketSearch?StateType=open&SortBy=Created&SortDirection=ASC
```

A Laravel active-ticket cache warmer can use this sequence:

```text
1. GET /ZnunyAgentListTicketSearch?StateType=new,open&CountOnly=1
2. Read TotalCount.
3. Iterate Offset from 0 to TotalCount using Limit=50.
4. GET /ZnunyAgentListTicketSearch?StateType=new,open&Limit=50&Offset=<offset>
5. Cache safe ticket metadata by TicketID, TicketNumber, and SyncFingerprint.
```

The response uses an explicit safe allow-list. It does not return article,
note, or reply bodies; article subjects; attachments; or full article metadata.

- `ArticleCount`: safe count of articles.
- `LastArticleID`: newest article ID.
- `LastArticleCreated`: creation timestamp of the newest article.
- `SyncFingerprint`: stable hash for external synchronization comparisons.

`SyncFingerprint` changes when safe ticket metadata changes or when a new
article, note, or reply is added.

Example safe response:

```json
{
  "Tickets": [
    {
      "TicketID": "57250",
      "TicketNumber": "2026062346000357",
      "Title": "Example ticket",
      "QueueID": "49",
      "Queue": "Customer Projects",
      "OwnerID": "2",
      "Owner": "api.agent@example.invalid",
      "ResponsibleID": "1",
      "Responsible": "root@example.invalid",
      "LockID": "1",
      "Lock": "unlock",
      "CustomerID": "example customer",
      "CustomerUserID": "example-user",
      "CustomerUser": "example-user",
      "StateID": "1",
      "State": "new",
      "StateType": "new",
      "PriorityID": "3",
      "Priority": "3 normal",
      "TypeID": "1",
      "Type": "Unclassified",
      "ServiceID": "0",
      "Service": "",
      "SLAID": "0",
      "SLA": "",
      "Created": "2026-06-23 16:44:53",
      "Changed": "2026-06-23 16:44:55",
      "ArticleCount": "2",
      "LastArticleID": "340615",
      "LastArticleCreated": "2026-06-23 16:44:54",
      "SyncFingerprint": "sha256-hex-string"
    }
  ],
  "Count": 1,
  "TotalCount": 137,
  "Limit": 50,
  "Offset": 0,
  "SortBy": "Created",
  "SortDirection": "DESC",
  "Warnings": []
}
```

Combined filters:

`GET /ZnunyAgentListTicketSearch?Queue=Support&StateType=open&Limit=5`

```json
{
  "Tickets": [
    {
      "TicketID": "12345",
      "TicketNumber": "202601010000001",
      "Title": "Example ticket",
      "QueueID": "10",
      "Queue": "Support",
      "OwnerID": "2",
      "Owner": "api.agent@example.invalid",
      "ResponsibleID": "0",
      "Responsible": "",
      "LockID": "2",
      "Lock": "lock",
      "CustomerID": "example-customer",
      "CustomerUserID": "example-customer-user",
      "CustomerUser": "example-customer-user",
      "StateID": "4",
      "State": "open",
      "StateType": "open",
      "PriorityID": "3",
      "TypeID": "1",
      "ServiceID": "0",
      "SLAID": "0",
      "Created": "2026-01-01 10:00:00",
      "Changed": "2026-01-01 10:30:00",
      "ArticleCount": "2",
      "LastArticleID": "67890",
      "LastArticleCreated": "2026-01-01 10:30:00",
      "SyncFingerprint": "4d967f2b7a1f4c7e9d0cbb7f3f7e2b8c4b3f0d4e2a1c9f8e7d6c5b4a3f2e1d0c"
    }
  ],
  "Count": 1,
  "TotalCount": 1,
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

`POST /TicketLock`

```json
{
  "Ticket": {
    "TicketID": "57250",
    "TicketNumber": "2026062346000357",
    "LockID": "2",
    "Lock": "lock",
    "State": "new",
    "StateType": "new"
  },
  "Warnings": []
}
```

`POST /TicketUnlock`

```json
{
  "Ticket": {
    "TicketID": "57250",
    "TicketNumber": "2026062346000357",
    "LockID": "1",
    "Lock": "unlock",
    "State": "new",
    "StateType": "new"
  },
  "Warnings": []
}
```

`POST /TicketMoveAssign/Validate`

```json
{
  "Valid": 1,
  "RequiredNote": 1,
  "Current": {
    "QueueID": 49,
    "QueueName": "Support",
    "OwnerID": 2,
    "OwnerLogin": "current.agent",
    "OwnerFullname": "Current Agent"
  },
  "Target": {
    "QueueID": 108,
    "QueueName": "Support::Projects",
    "OwnerID": 30,
    "OwnerLogin": "assigned.agent",
    "OwnerFullname": "Assigned Agent"
  },
  "Errors": [],
  "Warnings": []
}
```

`POST /TicketMoveAssign`

```json
{
  "Success": 1,
  "TicketID": 57250,
  "TicketNumber": "2026062346000357",
  "QueueChanged": 1,
  "OwnerChanged": 1,
  "NoteCreated": 0,
  "Before": {
    "QueueID": 49,
    "QueueName": "Support",
    "OwnerID": 2,
    "OwnerLogin": "current.agent",
    "OwnerFullname": "Current Agent"
  },
  "After": {
    "QueueID": 108,
    "QueueName": "Support::Projects",
    "OwnerID": 30,
    "OwnerLogin": "assigned.agent",
    "OwnerFullname": "Assigned Agent"
  },
  "Errors": [],
  "Warnings": []
}
```

A Laravel integration can load `/Queue/{QueueID}/AssignableAgents` after queue
selection, call `/TicketMoveAssign/Validate` before enabling or confirming
submit, then call `/TicketMoveAssign` and refresh safe ticket metadata or its
local cache after success.

A Laravel integration can show **Lock / Take in work** when `Lock` is `unlock`,
and **Unlock / Release** when `Lock` is `lock`. After either operation, refresh
the safe ticket metadata or update the local cache.

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
/path/to/output/ZnunyAgentList-1.3.1.opm
```

4. Install or upgrade with the Znuny console as `otrs`.

Install:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Install /path/to/output/ZnunyAgentList-1.3.1.opm" otrs
```

Upgrade:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Upgrade /path/to/output/ZnunyAgentList-1.3.1.opm" otrs
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
