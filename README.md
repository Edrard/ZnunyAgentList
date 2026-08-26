# ZnunyAgentList

`ZnunyAgentList` is a standalone Znuny 6.5 LTS GenericInterface extension for
integration systems, monitoring tools, and service automation jobs.

Current package version: `1.6.4`.

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
authorization checks. They expose only controlled queue, customer user, and
owner targets, prevalidate the complete change before modifying the ticket, and
use standard Znuny `TicketQueueSet()`, `TicketCustomerSet()`, and
`TicketOwnerSet()` APIs. No raw SQL or custom unrestricted runtime
`TicketUpdate` operation is used.

## What The Package Does Not Do

- It does not create tickets.
- It does not expose a custom unrestricted runtime `TicketUpdate` wrapper.
- It does not modify queues, users, services, SLAs, states, priorities, types,
  groups, roles, or preferences.
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
- Znuny home: set as `ZNUNY_HOME` in local shell examples
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
  "https://znuny.example.com/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Session" \
  -H "Content-Type: application/json" \
  -d '{"UserLogin":"API_USER","Password":"API_PASSWORD"}'
```

GET request with query-string authentication:

```bash
curl -sk \
  "https://znuny.example.com/otrs/nph-genericinterface.pl/Webservice/AdvancedZnunyAgentListREST/Health?UserLogin=API_USER&Password=API_PASSWORD"
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
| `GET` | `/Agent/:UserID/AssignableQueues` | `User::AssignableQueues` | List valid queues where an active agent may own tickets | `UserID` path parameter | `Success`, safe user fields, `Queues[]`, `Errors[]` |
| `GET` | `/Queue` | `Queue::List` | List valid queues | none | `Queues[]` |
| `GET` | `/Queue/:QueueID` | `Queue::Get` | Get queue by numeric ID | `QueueID` path parameter | `Queue.Found`, queue metadata |
| `GET` | `/QueueByName/:Name` | `Queue::Get` | Get queue by name | `Name` path parameter | `Queue.Found`, queue metadata |
| `GET` | `/Queue/:QueueID/AssignableAgents` | `Queue::AssignableAgents` | List active agents allowed to own tickets in a queue | `QueueID` path parameter | `Success`, `QueueID`, `QueueName`, `Agents[]`, `Errors[]` |
| `GET` | `/CustomerUser?Search=...&Limit=...` | `CustomerUser::Search` | Search customer users | `Search`, optional `Limit` capped at `50` | `CustomerUsers[]`, optional `Warnings[]` |
| `GET` | `/CustomerUser/:CustomerUserLogin` | `CustomerUser::Get` | Get one customer user | `CustomerUserLogin` path parameter | `CustomerUser.Found`, safe customer fields |
| `GET` | `/CustomerUserLookup` | `CustomerUser::Lookup` | Exact customer existence lookup | `Login` and/or `Email` | `Found`, `CustomerUser`, `Errors[]` |
| `GET` | `/CustomerCompany` | `CustomerCompany::List` | List valid customer company IDs | optional `Search`, `Limit`, `Offset`; default `Limit=50`, max `100`, default `Offset=0` | `CustomerCompanies[]`, `Count`, `TotalCount`, `Limit`, `Offset`, `HasMore`, `Errors[]` |
| `GET` | `/TicketState` | `Ticket::StateList` | List ticket states | none | `TicketStates[]` |
| `GET` | `/TicketPriority` | `Ticket::PriorityList` | List ticket priorities | none | `TicketPriorities[]` |
| `GET` | `/TicketType` | `Ticket::TypeList` | List ticket types | none | `TicketTypes[]`, optional warnings |
| `GET` | `/Service` | `Ticket::ServiceList` | List services | none | `Services[]`, optional warnings |
| `GET` | `/SLA` | `Ticket::SLAList` | List SLAs | none | `SLAs[]`, optional warnings |
| `GET` | `/ResolveTicketDefaults?Hostname=...` | `Ticket::ResolveTicketDefaults` | Resolve queue/customer defaults from host name | `Hostname` | `Input`, `Detected`, `Queue`, `CustomerUser`, `Warnings[]` |
| `GET` | `/ResolveTicketDefaults?HostName=...` | `Ticket::ResolveTicketDefaults` | Same as above with alternate parameter spelling | `HostName` | `Input`, `Detected`, `Queue`, `CustomerUser`, `Warnings[]` |
| `POST` | `/ValidateTicketCreate` | `Ticket::ValidateTicketCreate` | Validate future TicketCreate data without creating a ticket | `OwnerID`, `Queue`, `CustomerUser`, `State`, `Lock` as available | `Valid`, `Errors[]`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicket/:TicketID` | `Ticket::Get` | Safe ticket lookup by ID | `TicketID` path parameter; optional `AllArticles=1` | `Found`, safe ticket metadata, optional top-level `Articles[]`, HTML alternative fields, article sync summary, `SyncFingerprint`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicketNumber/:TicketNumber` | `Ticket::Get` | Safe ticket lookup by number | `TicketNumber` path parameter; optional `AllArticles=1` | `Found`, safe ticket metadata, optional top-level `Articles[]`, HTML alternative fields, article sync summary, `SyncFingerprint`, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicketSearch` | `Ticket::Search` | Safe filtered ticket search and total counting | filters such as `TicketNumber`, `Queue`, `StateType`, `CountOnly`, `Limit`, `Offset`, `Page`, `SortBy`, `SortDirection` | Safe `Tickets[]` with `InlineAttachmentCount`, page `Count`, matching `TotalCount`, pagination, `Warnings[]` |
| `GET` | `/ZnunyAgentListTicket/:TicketID/Article/:ArticleID/InlineAttachment` | `Ticket::InlineAttachmentGet` | Fetch one inline image attachment | `TicketID` and `ArticleID` path parameters; `ContentID` query parameter | base64 image content and safe metadata |

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
| `POST` | `/TicketMoveAssign/Validate` | `Ticket::MoveAssignValidate` | Validate a queue, customer, and/or owner change without changing the ticket | `TicketID`, optional `QueueID`/`QueueName`, optional `OwnerID`/`OwnerLogin`, optional `CustomerUserID`, conditional `Note` | `Valid`, `RequiredNote`, `CustomerChanged`, `Current`, `Target`, `Errors[]`, `Warnings[]` |
| `POST` | `/TicketMoveAssign` | `Ticket::MoveAssign` | Apply a prevalidated queue, customer, and/or owner change | `TicketID`, optional `QueueID`/`QueueName`, optional `OwnerID`/`OwnerLogin`, optional `CustomerUserID`, conditional `Note` | `Success`, `QueueChanged`, `CustomerChanged`, `OwnerChanged`, `NoteCreated`, `Before`, `After`, `Errors[]`, `Warnings[]` |
| `POST` | `/CustomerUser` | `CustomerUser::Create` | Create a customer user | `FirstName`, `LastName`, `Login`, `Email`, `CustomerID` | `Created`, safe `CustomerUser`, `Errors[]` |
| `PATCH` | `/CustomerUser/:CustomerUserLogin` | `CustomerUser::Update` | Update a customer user | `CurrentLogin`/path login, optional changed fields | `Updated`, safe `CustomerUser`, `Errors[]` |

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
  "TicketNumber": "202601010000001"
}
```

Example `POST /TicketUnlock` body:

```json
{
  "TicketNumber": "202601010000001"
}
```

Lock/unlock accepts only ticket identity, does not require a reason, and does
not expose generic unrestricted `TicketUpdate` fields.

### Controlled Ticket Move / Owner / Customer Workflow

The same controlled workflow supports queue changes, owner assignment, customer
reassignment, and any supported combination of those targets.

#### Endpoints

- `POST /TicketMoveAssign/Validate` is a dry run. It resolves `Current` and
  `Target`, performs every validation, and never mutates the ticket.
- `POST /TicketMoveAssign` runs the same shared preflight and executes only when
  it returns valid. Its response contains `QueueChanged`, `OwnerChanged`,
  `CustomerChanged`, `NoteCreated`, `Before`, and `After`.

#### Request Fields

| Field | Required | Meaning |
| --- | --- | --- |
| `TicketID` | Yes | Existing ticket numeric ID. |
| `QueueID` or `QueueName` | No | Target queue. If omitted, the current queue is retained. |
| `OwnerID` or `OwnerLogin` | No | Target owner. If omitted, the current owner is retained. |
| `CustomerUserID` | No | Target customer user login/identifier. |
| `CustomerID` | No | Consistency check only when `CustomerUserID` is supplied. |
| `Note` | Conditional | Required only when the resolved owner changes. |

At least one queue, owner, or customer target must be supplied. `UserLogin` is
reserved for GenericInterface authentication; it is never a target owner or
customer. Use `OwnerLogin` for an owner login and `CustomerUserID` for a customer
user.

#### Response Fields

Validation returns `Valid`, `RequiredNote`, `CustomerChanged`, `Current`,
`Target`, `Errors`, and `Warnings`. Execution returns `Success`, `QueueChanged`,
`OwnerChanged`, `CustomerChanged`, `NoteCreated`, `Before`, `After`, `Errors`,
and `Warnings`.

The snapshots include queue and owner data plus `CustomerID`, `CustomerUserID`,
`CustomerUserFullname`, and `CustomerUserEmail`. Unavailable display values are
empty strings; raw customer records are never returned.

#### Validation And Permission Rules

- The plugin resolves `CustomerUserID` through standard Znuny customer user APIs
  and derives `CustomerID` from `UserCustomerID`.
- A `CustomerID`-only change is rejected. When supplied with `CustomerUserID`,
  `CustomerID` must match the derived value.
- Locked, inactive, or unknown target owners are rejected.
- Whenever the queue or owner changes, the resolved target owner must be
  assignable in the resolved target queue. A queue-only move therefore fails if
  the current owner cannot own tickets in the target queue.
- Execute uses this same complete preflight. A validation failure does not
  change queue, customer, or owner and does not create a note.

#### Note Rules

| Requested change | Note required |
| --- | --- |
| Queue only | No |
| Customer only | No |
| Queue + customer | No |
| Owner only | Yes |
| Queue + owner | Yes |
| Owner + customer | Yes |
| Queue + owner + customer | Yes |

`NoteCreated=1` means the ZnunyAgentList wrapper created an additional
controlled internal note. Customer-only changes never create one. Owner changes
pass `Note` to native Znuny owner-change behavior and do not create a duplicate
wrapper note. Znuny may still create a native system article, email, or history
entry for an owner change while `NoteCreated` remains `0`.

#### Execution Order

After full validation succeeds, execution order is:

1. Queue change.
2. Customer change.
3. Owner change.

#### Examples

The examples intentionally contain no authentication secrets.

##### Customer-Only Change

Validate request:

```json
{
  "TicketID": "12345",
  "CustomerUserID": "customer.user@example.com"
}
```

Validation response:

```json
{
  "Valid": 1,
  "RequiredNote": 0,
  "CustomerChanged": 1,
  "Current": {
    "CustomerID": "previous-customer",
    "CustomerUserID": "previous.customer@example.com"
  },
  "Target": {
    "CustomerID": "example-customer",
    "CustomerUserID": "customer.user@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

Execute uses the same request. Example response:

```json
{
  "Success": 1,
  "QueueChanged": 0,
  "OwnerChanged": 0,
  "CustomerChanged": 1,
  "NoteCreated": 0,
  "Errors": [],
  "Warnings": []
}
```

##### CustomerID-Only Rejection

```json
{
  "TicketID": "12345",
  "CustomerID": "example-customer"
}
```

```json
{
  "Valid": 0,
  "RequiredNote": 0,
  "CustomerChanged": 0,
  "Errors": [
    "CustomerUserID is required when changing customer."
  ],
  "Warnings": []
}
```

##### Queue And Customer Without Note

```json
{
  "TicketID": "12345",
  "QueueID": "49",
  "CustomerUserID": "previous.customer@example.com"
}
```

```json
{
  "Valid": 1,
  "RequiredNote": 0,
  "CustomerChanged": 1,
  "Target": {
    "QueueID": 49,
    "QueueName": "Example Projects",
    "CustomerID": "previous-customer",
    "CustomerUserID": "previous.customer@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

##### Owner And Customer

Without the required owner note:

```json
{
  "TicketID": "12345",
  "OwnerID": "31",
  "CustomerUserID": "customer.user@example.com"
}
```

```json
{
  "Valid": 0,
  "RequiredNote": 1,
  "CustomerChanged": 1,
  "Errors": [
    "Note is required when owner changes."
  ],
  "Warnings": []
}
```

With the required note:

```json
{
  "TicketID": "12345",
  "OwnerID": "31",
  "CustomerUserID": "customer.user@example.com",
  "Note": "Assigning owner and customer from integration UI."
}
```

```json
{
  "Valid": 1,
  "RequiredNote": 1,
  "CustomerChanged": 1,
  "Target": {
    "OwnerID": 31,
    "OwnerLogin": "owner@example.com",
    "CustomerID": "example-customer",
    "CustomerUserID": "customer.user@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

##### Owner-Only Change

```json
{
  "TicketID": "12345",
  "OwnerLogin": "target.owner@example.com",
  "Note": "Assigning the ticket from integration UI."
}
```

```json
{
  "Valid": 1,
  "RequiredNote": 1,
  "CustomerChanged": 0,
  "Target": {
    "OwnerID": 31,
    "OwnerLogin": "target.owner@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

##### Queue And Owner

```json
{
  "TicketID": "12345",
  "QueueID": "49",
  "OwnerID": "31",
  "Note": "Moving and assigning the ticket."
}
```

```json
{
  "Valid": 1,
  "RequiredNote": 1,
  "CustomerChanged": 0,
  "Target": {
    "QueueID": 49,
    "QueueName": "Example Projects",
    "OwnerID": 31,
    "OwnerLogin": "target.owner@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

##### Queue, Owner, And Customer

```json
{
  "TicketID": "12345",
  "QueueID": "49",
  "OwnerID": "31",
  "CustomerUserID": "customer.user@example.com",
  "Note": "Moving and assigning owner and customer."
}
```

```json
{
  "Valid": 1,
  "RequiredNote": 1,
  "CustomerChanged": 1,
  "Target": {
    "QueueID": 49,
    "QueueName": "Example Projects",
    "OwnerID": 31,
    "OwnerLogin": "target.owner@example.com",
    "CustomerID": "example-customer",
    "CustomerUserID": "customer.user@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

##### Locked Owner Rejection

```json
{
  "TicketID": "12345",
  "OwnerID": "5",
  "Note": "Assigning locked owner test."
}
```

```json
{
  "Valid": 0,
  "RequiredNote": 0,
  "CustomerChanged": 0,
  "Errors": [
    "Target owner not found or is not active."
  ],
  "Warnings": []
}
```

##### Queue-Only Permission Failure

In this example, current `OwnerID=6` is not assignable in target `QueueID=3`.

```json
{
  "TicketID": "12345",
  "QueueID": "3"
}
```

```json
{
  "Valid": 0,
  "RequiredNote": 0,
  "CustomerChanged": 0,
  "Target": {
    "QueueID": 3,
    "QueueName": "Junk",
    "OwnerID": 6,
    "OwnerLogin": "current.owner@example.com"
  },
  "Errors": [
    "Target owner is not assignable in target queue."
  ],
  "Warnings": []
}
```

##### Queue-Only Permission Success

When the current owner is assignable in the target queue:

```json
{
  "TicketID": "12345",
  "QueueID": "49"
}
```

```json
{
  "Valid": 1,
  "RequiredNote": 0,
  "CustomerChanged": 0,
  "Target": {
    "QueueID": 49,
    "QueueName": "Example Projects",
    "OwnerID": 2,
    "OwnerLogin": "current.owner@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

##### TicketID-Only Rejection

```json
{
  "TicketID": "12345"
}
```

```json
{
  "Valid": 0,
  "RequiredNote": 0,
  "CustomerChanged": 0,
  "Errors": [
    "At least one target change is required."
  ],
  "Warnings": []
}
```

#### Curl Examples

Set `ZNUNY_BASE_URL`, `ZNUNY_API_USER`, and `ZNUNY_API_PASS` in the shell. Do
not commit their real values.

Validate customer-only:

```bash
curl -sS -X POST "$ZNUNY_BASE_URL/TicketMoveAssign/Validate?UserLogin=$ZNUNY_API_USER&Password=$ZNUNY_API_PASS" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":"12345","CustomerUserID":"customer.user@example.com"}'
```

Execute customer-only:

```bash
curl -sS -X POST "$ZNUNY_BASE_URL/TicketMoveAssign?UserLogin=$ZNUNY_API_USER&Password=$ZNUNY_API_PASS" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":"12345","CustomerUserID":"customer.user@example.com"}'
```

Validate owner and customer with a note:

```bash
curl -sS -X POST "$ZNUNY_BASE_URL/TicketMoveAssign/Validate?UserLogin=$ZNUNY_API_USER&Password=$ZNUNY_API_PASS" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":"12345","OwnerID":"31","CustomerUserID":"customer.user@example.com","Note":"Assigning owner and customer from integration UI."}'
```

Validate a queue-only move before attempting execution:

```bash
curl -sS -X POST "$ZNUNY_BASE_URL/TicketMoveAssign/Validate?UserLogin=$ZNUNY_API_USER&Password=$ZNUNY_API_PASS" \
  -H "Content-Type: application/json" \
  -d '{"TicketID":"12345","QueueID":"3"}'
```

#### Integration Guidance

A UI can use `/Agent/{UserID}/AssignableQueues` and
`/Queue/{QueueID}/AssignableAgents` to constrain owner and queue choices, but it
must still call `/TicketMoveAssign/Validate` as the final preflight. Validation
checks the resolved target owner and target queue together and rejects
queue-only moves with `Target owner is not assignable in target queue.` when the
current owner cannot operate in the target queue, as shown in the permission
failure example above.

An integration UI should use customer user search to select a customer, send
`CustomerUserID` to `/TicketMoveAssign/Validate`, show `Current`, `Target`,
`Errors`, and `Warnings` to the operator, and call `/TicketMoveAssign` only
after `Valid=1`.

After `QueueChanged`, `OwnerChanged`, or `CustomerChanged`, refresh safe ticket
metadata. Customer-only changes usually leave `ArticleCount` and
`LastArticleID` unchanged, but update `Changed` and `SyncFingerprint`. Native
owner changes may add system article/history data, so refresh articles when
`ArticleCount` or `LastArticleID` changes.

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
  "Owner": "api.owner@example.com",
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
needed for synchronization. Clients that require article bodies should use the
custom `Ticket::Get` routes with `AllArticles=1`, and clients that require inline
images should use `Ticket::InlineAttachmentGet`.

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
  "Version": "1.6.4",
  "Success": 1,
  "Time": "2026-01-01 10:00:00"
}
```

### Package Configuration

`GET /SystemConfig`

```json
{
  "Plugin": "ZnunyAgentList",
  "Version": "1.6.4",
  "Features": {
    "AgentList": 1,
    "AgentAssignableQueues": 1,
    "QueueList": 1,
    "QueueAssignableAgents": 1,
    "CustomerUserSearch": 1,
    "CustomerUserLookup": 1,
    "CustomerUserCreate": 1,
    "CustomerUserUpdate": 1,
    "CustomerCompanyList": 1,
    "TicketGet": 1,
    "TicketSearch": 1,
    "TicketInlineAttachmentGet": 1,
    "TicketArticleCreate": 1,
    "TicketClose": 1,
    "TicketReopen": 1,
    "TicketLock": 1,
    "TicketUnlock": 1,
    "TicketMoveAssignValidate": 1,
    "TicketMoveAssign": 1,
    "TicketMoveAssignCustomer": 1,
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

### GET /Agent/{UserID}/AssignableQueues

Returns valid queues where the selected active agent can be assigned as ticket
owner. It is the reverse lookup for `GET /Queue/{QueueID}/AssignableAgents`.

#### Input And Authentication

| Value | Meaning |
| --- | --- |
| Path `UserID` | Target agent numeric ID. |
| Query `UserLogin` | GenericInterface authentication login only. |
| Query `Password` | GenericInterface authentication password. |

Authentication `UserLogin` is never interpreted as the target agent. The
endpoint uses normal read authorization and does not require
`ZnunyAgentList::EnableTicketWriteOperations`.

```bash
curl -skG "$ZNUNY_BASE_URL/Agent/6/AssignableQueues" \
  --data-urlencode "UserLogin=$ZNUNY_API_USER" \
  --data-urlencode "Password=$ZNUNY_API_PASS"
```

#### Response Contract

The response contains only `Success`, `UserID`, `UserLogin`, `UserFullname`,
`Queues`, and `Errors`. Each queue contains only `QueueID`, `Name`, and
`FullName`.

- The agent must exist and be active.
- Only valid queues are returned.
- Queue access uses standard Znuny `owner` permission logic without raw SQL.
- An active agent with no assignable queues returns `Success=1`, `Queues=[]`,
  and `Errors=[]`.
- A missing, inactive, or locked agent returns `Success=0`, empty user details,
  `Queues=[]`, and a clear error.

#### Active Limited Owner

This example shows an active owner who can be assigned only in `QueueID=49`:

```json
{
  "Success": 1,
  "UserID": 6,
  "UserLogin": "limited.owner@example.com",
  "UserFullname": "Limited Owner",
  "Queues": [
    {
      "QueueID": 49,
      "Name": "Example Projects",
      "FullName": "Example Projects"
    }
  ],
  "Errors": []
}
```

In this example, the agent can be assigned only in `QueueID=49` and does not
appear in `QueueID=3` (`Junk`).

#### Active Owner With Many Queues

This shortened example shows an active owner with access to many valid queues:

```json
{
  "Success": 1,
  "UserID": 2,
  "UserLogin": "owner@example.com",
  "UserFullname": "Example Owner",
  "Queues": [
    {
      "QueueID": 3,
      "Name": "Junk",
      "FullName": "Junk"
    },
    {
      "QueueID": 49,
      "Name": "Example Projects",
      "FullName": "Example Projects"
    }
  ],
  "Errors": []
}
```

#### Active Agent With No Queues

This is a successful lookup with an empty assignment set:

```json
{
  "Success": 1,
  "UserID": 42,
  "UserLogin": "unassigned.owner@example.com",
  "UserFullname": "Unassigned Owner",
  "Queues": [],
  "Errors": []
}
```

#### Inactive Or Locked Agent

Locked or inactive agents are rejected with the same safe response shape:

```json
{
  "Success": 0,
  "UserID": 5,
  "UserLogin": "",
  "UserFullname": "",
  "Queues": [],
  "Errors": [
    "Agent not found or is not active."
  ]
}
```

#### Missing Agent

Missing agents use the same safe error contract:

```json
{
  "Success": 0,
  "UserID": 999999,
  "UserLogin": "",
  "UserFullname": "",
  "Queues": [],
  "Errors": [
    "Agent not found or is not active."
  ]
}
```

#### Relationship To Queue Lookup

- `GET /Agent/6/AssignableQueues` answers: Which queues can this owner work in?
- `GET /Queue/49/AssignableAgents` answers: Which owners can work in this queue?

For example, if an owner is assignable in `QueueID=49` but not in `QueueID=3`,
the queue lookup for `QueueID=49` can include that owner while
`/Agent/6/AssignableQueues` returns only `QueueID=49`.

For an integration UI, use `/Agent/{UserID}/AssignableQueues` after owner
selection and `/Queue/{QueueID}/AssignableAgents` after queue selection. These
lookups guide the UI, but `/TicketMoveAssign/Validate` remains the final
authority before execution.

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
      "UserLogin": "owner@example.com",
      "UserFullname": "Example Owner"
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
      "UserEmail": "customer@example.com"
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
    "UserEmail": "customer@example.com"
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

`GET /CustomerUserLookup?Login=example.customer`

```json
{
  "Found": 1,
  "CustomerUser": {
    "Found": 1,
    "UserLogin": "example.customer",
    "UserCustomerID": "example-customer",
    "UserFirstname": "Example",
    "UserLastname": "Customer",
    "UserEmail": "customer@example.com"
  },
  "Errors": []
}
```

`CustomerUser::Get` is the exact login lookup. `CustomerUser::Lookup` exists for
exact existence checks by `Login` or exact email checks by `Email`; it does not
use fuzzy customer search semantics, and wildcard-like email values are rejected.
Email is not treated as unique unless the exact lookup finds exactly one active
customer user.

Missing login:

```json
{
  "Found": 0,
  "CustomerUser": null,
  "Errors": []
}
```

Duplicate exact email:

```json
{
  "Found": 0,
  "CustomerUser": null,
  "Errors": [
    "Email matches multiple customer users."
  ]
}
```

If an email matches multiple active customer users, the lookup returns
`Found: 0` with that error instead of choosing one arbitrarily.

`GET /CustomerCompany?Search=example&Limit=20&Offset=0`

```json
{
  "CustomerCompanies": [
    {
      "CustomerID": "example-customer",
      "CustomerCompanyName": "Example Customer"
    }
  ],
  "Count": 1,
  "TotalCount": 1,
  "Limit": 20,
  "Offset": 0,
  "HasMore": 0,
  "Errors": []
}
```

The UI label `Company ID` maps to Znuny `CustomerID`. Use
`CustomerCompany::List` to populate a selector/autocomplete, then send the
selected `CustomerID` as `CustomerID` when creating or updating a customer user.
`Search` is optional, scalar, bounded to 100 characters, and passed to Znuny's
standard customer company search before counting and paging. `Limit` defaults
to `50` and is capped at `100`. `Offset` is optional, zero-based, and must be a
scalar decimal integer from `0` through `2147483647`; malformed or oversized
values are rejected rather than clamped. Results are sorted deterministically
before slicing by case-insensitive customer company name, case-insensitive
customer ID, raw customer company name, and raw customer ID.
`TotalCount` is the number of valid matching companies before pagination,
`Count` is the current page length, and `HasMore` is `1` when another page is
available or `0` when it is not. If `Offset` is equal to or greater than
`TotalCount`, the endpoint returns an empty `CustomerCompanies` list with
`CustomerCompanies=[]`, `Count=0`, and `HasMore=0`. Each company item exposes
only `CustomerID` and `CustomerCompanyName`.

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
    "CustomerUserLogin": "support-host-customer@example.com"
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

Existing custom routes:

```text
GET /ZnunyAgentListTicket/:TicketID
GET /ZnunyAgentListTicketNumber/:TicketNumber
```

Both routes use the same `Ticket::Get` operation. The `TicketID` route resolves
by numeric ticket ID; the `TicketNumber` route resolves by ticket number. The
standard GenericTicketConnector route `/Ticket/:TicketID` is unchanged and does
not gain the custom HTML article fields.

Without `AllArticles=1`, and also with `AllArticles=0` or another accepted false
value such as `false`, `no`, or `off`, `Ticket::Get` preserves the lightweight
response shape. It returns `Found`, `Ticket`, and `Warnings`; `Articles` is
absent. Article bodies and HTML body attachments are not loaded by the optional
article flow.

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
    "Owner": "api.owner@example.com",
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

TicketID lookup example:

```bash
curl -skG "$ZNUNY_BASE_URL/ZnunyAgentListTicket/12345" \
  --data-urlencode "UserLogin=$ZNUNY_API_USER" \
  --data-urlencode "Password=$ZNUNY_API_PASS" \
  --data-urlencode "AllArticles=1" \
  --data-urlencode "Attachments=0" \
  --data-urlencode "DynamicFields=0"
```

TicketNumber lookup example:

```bash
curl -skG "$ZNUNY_BASE_URL/ZnunyAgentListTicketNumber/202601010000001" \
  --data-urlencode "UserLogin=$ZNUNY_API_USER" \
  --data-urlencode "Password=$ZNUNY_API_PASS" \
  --data-urlencode "AllArticles=1" \
  --data-urlencode "Attachments=0" \
  --data-urlencode "DynamicFields=0"
```

With `AllArticles=1`, both custom routes return the same safe ticket metadata
plus a top-level `Articles` array. `Articles` is not nested inside `Ticket`.
Article ordering follows Znuny's native article retrieval order after HTML
lookups and content loading. `Attachments=0` prevents regular attachment output,
but it does not disable the internal HTML-body lookup. `DynamicFields=0` does
not introduce dynamic fields. No new endpoint is added for this flow.

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
  "Articles": [
    {
      "TicketID": 12345,
      "ArticleID": 67890,
      "ArticleNumber": 1,
      "Subject": "Example message",
      "Body": "Original plain-text article body.",
      "ContentType": "text/plain; charset=utf-8",
      "Charset": "utf-8",
      "MimeType": "text/plain",
      "SenderTypeID": 1,
      "SenderType": "agent",
      "CommunicationChannelID": 1,
      "CommunicationChannel": "Email",
      "IsVisibleForCustomer": 1,
      "IncomingTime": 1800000000,
      "Created": "2026-01-01 10:00:00",
      "HTMLBodyAvailable": 1,
      "HTMLBodyContentType": "text/html; charset=utf-8",
      "HTMLBodyContent": "PHA+RXhhbXBsZTwvcD4="
    },
    {
      "TicketID": 12345,
      "ArticleID": 67891,
      "ArticleNumber": 2,
      "Subject": "Plain message",
      "Body": "Plain-text article without an HTML alternative.",
      "ContentType": "text/plain; charset=utf-8",
      "Charset": "utf-8",
      "MimeType": "text/plain",
      "SenderTypeID": 1,
      "SenderType": "agent",
      "CommunicationChannelID": 1,
      "CommunicationChannel": "Email",
      "IsVisibleForCustomer": 0,
      "IncomingTime": 1800000060,
      "Created": "2026-01-01 10:01:00",
      "HTMLBodyAvailable": 0
    }
  ],
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

### Ticket Articles And HTML Alternatives

An email article can have a visible or fallback `text/plain` body while Znuny
also stores a separate hidden `text/html` MIME alternative. `Ticket::Get` does
not replace or modify the existing article `Body`, `MimeType`, or `ContentType`.
Those fields remain as Znuny returns them.

When requested with `AllArticles=1`, each returned article always includes
`HTMLBodyAvailable` as a JSON integer:

- `HTMLBodyAvailable: 1`: `HTMLBodyContentType` and `HTMLBodyContent` are both
  present.
- `HTMLBodyAvailable: 0`: `HTMLBodyContentType` and `HTMLBodyContent` are both
  absent, not `null` or empty strings.

`HTMLBodyContentType` preserves the native HTML MIME type and charset parameters,
such as `text/html; charset=utf-8`. `HTMLBodyContent` is no-wrap base64 of the
original, unmodified HTML bytes. Decoding it returns the exact original byte
sequence. The plugin performs no HTML charset conversion, sanitization, CID
rewriting, HTML normalization, newline normalization, or image-position
heuristics.

HTML alternatives are selected through Znuny's native HTML body attachment index.
Existing `cid:` references in the HTML already determine the correct inline
image positions. Use the existing `Ticket::InlineAttachmentGet` operation to
retrieve allowed inline images by `TicketID`, `ArticleID`, and `ContentID`.

Consuming applications must treat decoded email HTML as untrusted input and
apply appropriate HTML sanitization before browser rendering.

PDF, plain text, inline images, ordinary attachments, SVG, malformed MIME types,
and other non-HTML parts are not treated as HTML bodies.

Example article with an HTML alternative:

```json
{
  "ArticleID": 67890,
  "Body": "Plain text fallback body.",
  "MimeType": "text/plain",
  "ContentType": "text/plain; charset=utf-8",
  "HTMLBodyAvailable": 1,
  "HTMLBodyContentType": "text/html; charset=utf-8",
  "HTMLBodyContent": "PGh0bWw+PGJvZHk+PHA+RXhhbXBsZSDQnzwvcD48aW1nIHNyYz0iY2lkOmlubGluZS1hbHBoYSI+PGltZyBzcmM9ImNpZDppbmxpbmUtYmV0YSI+PC9ib2R5PjwvaHRtbD4="
}
```

Example article without an HTML alternative:

```json
{
  "ArticleID": 67891,
  "Body": "Plain text body.",
  "MimeType": "text/plain",
  "ContentType": "text/plain; charset=utf-8",
  "HTMLBodyAvailable": 0
}
```

### Inline Article Images

Use `Ticket::InlineAttachmentGet` only after an article body or HTML alternative
has exposed a `cid:` reference that belongs to a ticket article.

`GET /ZnunyAgentListTicket/:TicketID/Article/:ArticleID/InlineAttachment?ContentID=...`

`ContentID` is passed as a query parameter, not as a path segment. This is
intentional: MIME Content-IDs can contain URL-sensitive characters, including
slashes, and Znuny's REST transport matches path parameters as single
slash-separated segments. Clients must URL-encode the query value.

Equivalent Content-ID request forms are accepted:

```text
image003.jpg@01DD2EF7.2CE4B9D0
<image003.jpg@01DD2EF7.2CE4B9D0>
cid:image003.jpg@01DD2EF7.2CE4B9D0
cid:<image003.jpg@01DD2EF7.2CE4B9D0>
```

The operation strips only the optional `cid:` prefix and surrounding angle
brackets, then requires an exact normalized Content-ID match. Nested or
malformed angle-bracket wrappers are rejected instead of being normalized. It
verifies that the ticket exists, the article belongs to the ticket, and exactly
one attachment in that article has the requested Content-ID. Attachment `FileID`
is an article-local identifier and is never treated as a global database ID.

Allowed MIME types are `image/png`, `image/jpeg`, `image/gif`, and `image/webp`.
MIME parameters from Znuny, such as `image/jpeg; name="image003.jpg"`, are
accepted for matching but are never returned. The response `ContentType` is
always the normalized allow-listed media type only. `image/jpg` is normalized to
`image/jpeg`; SVG and non-image attachments are rejected. `Content` is returned
as base64 without line wrapping.

Success:

```json
{
  "Found": 1,
  "TicketID": 12345,
  "ArticleID": 67890,
  "FileID": 3,
  "Filename": "image003.jpg",
  "ContentType": "image/jpeg",
  "ContentID": "image003.jpg@01DD2EF7.2CE4B9D0",
  "Disposition": "inline",
  "FilesizeRaw": 12345,
  "Content": "base64-content",
  "Errors": []
}
```

Not found or unresolved:

```json
{
  "Found": 0,
  "TicketID": 12345,
  "ArticleID": 67890,
  "Errors": [
    "Inline attachment not found."
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
details, calculate article synchronization metadata, or count inline
attachments.

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

`GET /ZnunyAgentListTicketSearch?TicketNumber=202601010000001`

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

An active-ticket cache warmer can use this sequence:

```text
1. GET /ZnunyAgentListTicketSearch?StateType=new,open&CountOnly=1
2. Read TotalCount.
3. Iterate Offset from 0 to TotalCount using Limit=50.
4. GET /ZnunyAgentListTicketSearch?StateType=new,open&Limit=50&Offset=<offset>
5. Cache safe ticket metadata by TicketID, TicketNumber, and SyncFingerprint.
```

The response uses an explicit safe allow-list. It does not return article,
note, or reply bodies; article subjects; attachments; or full article metadata.
`InlineAttachmentCount` is present on every returned ticket object as a
non-negative JSON integer. It is calculated from attachment index metadata only
and counts matching attachments across all articles of the ticket. A matching
attachment must have disposition `inline`, case-insensitively, and a normalized
MIME type of `image/png`, `image/jpeg`, `image/gif`, or `image/webp`. MIME
parameters such as `image/jpeg; name="image.jpg"` are accepted, and `image/jpg`
is normalized as JPEG. Ordinary attachments, missing or non-inline
dispositions, PDF, DOCX, SVG, unknown, malformed, and other non-allowed MIME
types are not counted. The response does not include attachment content, base64
data, filenames, attachment metadata, or an attachment list through this field.
`HTMLBodyArticleCount` is also present on every returned ticket object as a
non-negative JSON integer. It counts articles that have at least one valid
stored HTML body alternative discovered with Znuny's `OnlyHTMLBody` attachment
index mode. It does not count the number of HTML attachments, and it does not
return HTML content, base64 data, filenames, attachment metadata, or attachment
lists in search results.

- `ArticleCount`: safe count of articles.
- `InlineAttachmentCount`: non-negative integer count of matching inline raster
  image attachments across all ticket articles.
- `HTMLBodyArticleCount`: non-negative integer count of articles with a stored
  `text/html` body alternative.
- `LastArticleID`: newest article ID.
- `LastArticleCreated`: creation timestamp of the newest article.
- `SyncFingerprint`: stable hash for external synchronization comparisons.

`SyncFingerprint` changes when safe ticket metadata changes or when a new
article, note, or reply is added.

Compatibility smoke testing for the 1.6.2 release against Znuny 6.5.20
confirmed that exact ticket-number search can return a ticket with
`InlineAttachmentCount: 1` for a known inline JPEG, and queue-filtered search
results include the field on every returned ticket with valid non-negative
integer values.

Example safe response:

```json
{
  "Tickets": [
    {
      "TicketID": "12345",
      "TicketNumber": "202601010000001",
      "Title": "Example ticket",
      "QueueID": "49",
      "Queue": "Customer Projects",
      "OwnerID": "2",
      "Owner": "api.owner@example.com",
      "ResponsibleID": "1",
      "Responsible": "responsible.owner@example.com",
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
      "InlineAttachmentCount": 1,
      "HTMLBodyArticleCount": 1,
      "LastArticleID": "67890",
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
      "Owner": "api.owner@example.com",
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
      "InlineAttachmentCount": 0,
      "HTMLBodyArticleCount": 0,
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
    "TicketID": "12345",
    "TicketNumber": "202601010000001",
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
    "TicketID": "12345",
    "TicketNumber": "202601010000001",
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
  "CustomerChanged": 1,
  "Current": {
    "QueueID": 49,
    "QueueName": "Support",
    "OwnerID": 2,
    "OwnerLogin": "current.owner@example.com",
    "OwnerFullname": "Current Owner",
    "CustomerID": "old-customer",
    "CustomerUserID": "old.customer",
    "CustomerUserFullname": "Old Customer",
    "CustomerUserEmail": "old.customer@example.com"
  },
  "Target": {
    "QueueID": 108,
    "QueueName": "Support::Projects",
    "OwnerID": 30,
    "OwnerLogin": "target.owner@example.com",
    "OwnerFullname": "Target Owner",
    "CustomerID": "target-customer",
    "CustomerUserID": "target.customer",
    "CustomerUserFullname": "Target Customer",
    "CustomerUserEmail": "target.customer@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

`POST /TicketMoveAssign`

```json
{
  "Success": 1,
  "TicketID": 12345,
  "TicketNumber": "202601010000001",
  "QueueChanged": 1,
  "OwnerChanged": 1,
  "CustomerChanged": 1,
  "NoteCreated": 0,
  "Before": {
    "QueueID": 49,
    "QueueName": "Support",
    "OwnerID": 2,
    "OwnerLogin": "current.owner@example.com",
    "OwnerFullname": "Current Owner",
    "CustomerID": "old-customer",
    "CustomerUserID": "old.customer",
    "CustomerUserFullname": "Old Customer",
    "CustomerUserEmail": "old.customer@example.com"
  },
  "After": {
    "QueueID": 108,
    "QueueName": "Support::Projects",
    "OwnerID": 30,
    "OwnerLogin": "target.owner@example.com",
    "OwnerFullname": "Target Owner",
    "CustomerID": "target-customer",
    "CustomerUserID": "target.customer",
    "CustomerUserFullname": "Target Customer",
    "CustomerUserEmail": "target.customer@example.com"
  },
  "Errors": [],
  "Warnings": []
}
```

See the controlled move / owner / customer workflow above for validation,
execution, and cache refresh guidance.

A consuming UI can show **Lock / Take in work** when `Lock` is `unlock`, and
**Unlock / Release** when `Lock` is `lock`. After either operation, refresh the
safe ticket metadata or update the local cache.

### Customer User Writes

`POST /CustomerUser`

```json
{
  "FirstName": "John",
  "LastName": "Doe",
  "Login": "john.doe@example.com",
  "Email": "john.doe@example.com",
  "CustomerID": "example-customer"
}
```

`FirstName`, `LastName`, `Login`, `Email`, and `CustomerID` are required.
`CustomerID` is the Znuny value shown as `Company ID` in the agent UI and must
exist as a valid customer company. Password input is not supported for this REST
endpoint. Znuny's REST transport can record raw non-GET request bodies in
GenericInterface debug output, so caller-supplied passwords are rejected. Create
generates a private random password internally and never returns it. A customer
who needs Customer Portal access must use the normal administrative or
password-reset workflow to receive a new password.

```json
{
  "Created": 1,
  "CustomerUser": {
    "UserLogin": "john.doe@example.com",
    "UserCustomerID": "example-customer",
    "UserFirstname": "John",
    "UserLastname": "Doe",
    "UserEmail": "john.doe@example.com"
  },
  "Errors": []
}
```

`PATCH /CustomerUser/:CustomerUserLogin`

```json
{
  "FirstName": "Jane",
  "LastName": "Doe",
  "Email": "jane.doe@example.com",
  "CustomerID": "example-customer"
}
```

The path `CustomerUserLogin` identifies the current customer user and is
authoritative. Clients do not need to duplicate it as `CurrentLogin` in the JSON
body. If `CurrentLogin` is supplied for compatibility, it must exactly match the
path value or the request is rejected. Unspecified fields are preserved from the
existing customer-user record: omitted `FirstName`, `LastName`, `Email`,
`CustomerID`, and `Login` keep their current values. Password input is not
supported for this REST endpoint, so Update does not change customer-user
passwords.

Login rename is supported through Znuny's native
`CustomerUserUpdate(ID => CurrentLogin, UserLogin => Login, ...)` path by
providing `Login`; if omitted or identical to the path login, the login remains
unchanged. Duplicate target logins are rejected before calling Znuny's update
API.

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

After a version is published, users can download the verified `.opm` package
from that version's GitHub Release, or build it themselves in their own
Znuny/Linux environment. Do not commit generated `.opm` files or checksum files
to Git.

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
/path/to/output/ZnunyAgentList-1.6.4.opm
```

4. Install or upgrade with the Znuny console as `otrs`.

Set `ZNUNY_HOME` to the Znuny application directory used by the server before
running these examples.

Install:

```bash
cd "$ZNUNY_HOME"
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Install /path/to/output/ZnunyAgentList-1.6.4.opm" otrs
```

Upgrade:

```bash
cd "$ZNUNY_HOME"
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Upgrade /path/to/output/ZnunyAgentList-1.6.4.opm" otrs
```

5. Rebuild configuration and delete cache:

```bash
cd "$ZNUNY_HOME"
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
Kernel/GenericInterface/Operation/User/*.pm
Kernel/GenericInterface/Operation/Queue/*.pm
Kernel/GenericInterface/Operation/CustomerUser/*.pm
Kernel/GenericInterface/Operation/Ticket/*.pm
```

Repository-only helpers:

```text
scripts/verify-source.sh
scripts/build-package.sh
scripts/test-assignable-queues.pl
scripts/test-move-assign-validation.pl
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
