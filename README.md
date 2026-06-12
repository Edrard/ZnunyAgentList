# ZnunyAgentList

ZnunyAgentList is a lightweight Znuny 6.5 extension that provides a secure, read-only GenericInterface REST operation for retrieving active agents with their ID, login, and display name.

## Supported Environment

- Supported Znuny version: Znuny 6.5 LTS
- Intended validation version: Znuny 6.5.20
- Intended Znuny installation path: `/opt/otrs`
- Intended server OS: Rocky Linux 8
- Intended Znuny runtime user: `otrs`

The authoritative build, validation, installation, upgrade, and uninstall environment is the real Rocky Linux 8 Znuny 6.5.20 server. Local Windows development is limited to editing repository source files.

## Verified Znuny 6.5.20 Behavior

The following details have been verified against the installed Znuny 6.5.20 source code:

- `UserList(Type => 'Long')` returns user IDs as hash keys and formatted full names as hash values.
- `NoOutOfOffice => 1` in `UserList()` does not filter out users. It prevents status and out-of-office messages from being appended to the displayed full name.
- `GetUserData()` creates `OutOfOfficeMessage` only when the current time is within the configured out-of-office start and end dates.
- `Dev::Package::Build` supports `--module-directory`.
- GenericInterface operation registration uses `GenericInterface::Operation::ModuleRegistration` navigation.

These confirmations do not mean the package itself has already built, installed, or run successfully.

## Operation

- GenericInterface operation name: `User::AgentList`
- Controller: `User`
- Operation: `AgentList`
- Access: authenticated Znuny agent users only
- Behavior: returns active agents and excludes users currently marked out of office.

The operation accepts the standard GenericInterface provider authentication handled by `Kernel::GenericInterface::Operation::Common`:

- `SessionID`
- `UserLogin` plus `Password`

Customer users and unauthenticated requests are rejected. Invalid credentials are rejected by the standard GenericInterface authentication layer.

## Response

The response uses an explicit allow-list. Each agent record contains exactly:

- `UserID`
- `UserLogin`
- `UserFullname`

No password hashes, session identifiers, preferences, email addresses, roles, groups, permissions, complete user records, or arbitrary internal fields are returned.

Example successful JSON payload after GenericInterface serialization:

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

Results are sorted deterministically by `UserFullname`, then `UserLogin`, then numeric `UserID`.

On Znuny 6.5.20, `UserList(Type => 'Long', Valid => 1, NoOutOfOffice => 1)` returns user IDs as hash keys and clean formatted full names as hash values. `NoOutOfOffice => 1` does not filter out current out-of-office users; it prevents runtime status and out-of-office suffixes from being appended to the full name. Current out-of-office users are excluded by checking `OutOfOfficeMessage` from `GetUserData(UserID => ...)`.

If `GetUserData()` cannot return a consistent record with `UserID` and `UserLogin`, that individual user is skipped rather than returning partial internal data. `OutOfOfficeMessage` is used only for filtering and is never returned in the API response.

## Package Source

This repository contains the source package definition (`ZnunyAgentList.sopm`) and package-owned runtime files.

The SOPM file installs only these runtime files:

- `Kernel/GenericInterface/Operation/User/AgentList.pm`
- `Kernel/Config/Files/XML/ZnunyAgentList.xml`

Repository-only files such as documentation, helper scripts, and Git metadata are not installed by the SOPM file.

The GenericInterface operation registration uses this verified Znuny 6.5.20 SysConfig navigation:

```text
GenericInterface::Operation::ModuleRegistration
```

These SOPM compatibility values are intentional but still require validation against the real Znuny 6.5.20 Package Manager or an authoritative package from the same installation:

- `<otrs_package version="1.1">`
- `<Framework>6.5.x</Framework>`

## Transfer To Server

Transfer the source tree to a non-production staging path on the Znuny server using one of these approaches:

```bash
git clone <REPOSITORY_URL> /path/to/ZnunyAgentList
```

```bash
scp -r /local/path/ZnunyAgentList <ssh-user>@<znuny-host>:/path/to/ZnunyAgentList
```

```bash
rsync -a --exclude .git /local/path/ZnunyAgentList/ <ssh-user>@<znuny-host>:/path/to/ZnunyAgentList/
```

Use placeholders only in shared documentation and scripts. Do not store passwords, tokens, or session IDs in this repository.

## Server-Side Source Verification

From the unpacked or cloned source tree on Rocky Linux 8, you may run the optional read-only helper:

```bash
cd /path/to/ZnunyAgentList
bash scripts/verify-source.sh
```

The helper requires `xmllint` for XML checks. If `xmllint` is unavailable, install the standard Rocky Linux `libxml2` package or perform equivalent XML validation manually. The helper does not build, install, uninstall, rebuild configuration, clear cache, or call the REST endpoint.

Run the Perl syntax check from the Znuny installation path:

```bash
cd /opt/otrs
perl -I/opt/otrs -c /path/to/ZnunyAgentList/Kernel/GenericInterface/Operation/User/AgentList.pm
```

This checks syntax only. It does not prove GenericInterface operation discovery, authentication, authorization, SysConfig registration, package installation, or REST behavior.

## Package Build

Build the final `.opm` package on the real Znuny 6.5.20 server. The confirmed package build command is:

```bash
cd /opt/otrs
su -s /bin/bash -c "cd /opt/otrs && bin/otrs.Console.pl Dev::Package::Build --module-directory '/path/to/ZnunyAgentList' '/path/to/ZnunyAgentList/ZnunyAgentList.sopm' '/path/to/output'" otrs
```

`--module-directory` points to the project root containing `Kernel/...`. The SOPM file is the package source definition. The expected final artifact is:

```text
/path/to/output/ZnunyAgentList-1.0.0.opm
```

Building creates the package artifact only. It does not install, upgrade, uninstall, rebuild configuration, clear cache, or deploy to production.

The repository includes a Linux helper that wraps the confirmed build command:

```bash
cd /path/to/ZnunyAgentList
bash scripts/build-package.sh /path/to/ZnunyAgentList /path/to/output
```

If no output directory is provided, the helper uses `/tmp`. The output directory must already exist and be writable by the `otrs` user. The helper verifies, as `otrs`, that the project directory is readable/searchable, the SOPM and runtime files are readable, and the output directory is writable. It then runs the build through the `otrs` user and verifies that `ZnunyAgentList-1.0.0.opm` was created.

## Installation

Installation is a later explicit server-side step after the `.opm` has been built and reviewed:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Admin::Package::Install /path/to/ZnunyAgentList-1.0.0.opm" otrs
```

Do not run installation, uninstall, configuration rebuild, cache deletion, or production deployment from the local Windows development environment.

Configuration rebuild is a separate later administrative step:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Maint::Config::Rebuild" otrs
```

Cache deletion is also a separate later administrative step:

```bash
cd /opt/otrs
su -s /bin/bash -c "bin/otrs.Console.pl Maint::Cache::Delete" otrs
```

Upgrade and uninstall must be planned and validated separately on Znuny 6.5.20. They are not performed by the build helper.

## Manual Web Service Configuration

After package installation and the required Znuny administration steps on Znuny 6.5.20, configure the REST web service manually in the Znuny Admin UI:

- Web Service: `GenericTicketConnectorREST`
- Operation: `User::AgentList`
- Route: `/Agent`
- HTTP method: `GET`
- Parser backend: `JSON`

Expected endpoint:

```text
https://otrs.vamark.net/otrs/nph-genericinterface.pl/Webservice/GenericTicketConnectorREST/Agent
```

Safe example request using a session header:

```bash
curl \
  -H "X-OTRS-Header-SessionID: <SESSION_ID>" \
  "https://otrs.vamark.net/otrs/nph-genericinterface.pl/Webservice/GenericTicketConnectorREST/Agent"
```

Safe example request using credential headers:

```bash
curl \
  -H "X-OTRS-Header-UserLogin: <AGENT_LOGIN>" \
  -H "X-OTRS-Header-Password: <PASSWORD>" \
  "https://otrs.vamark.net/otrs/nph-genericinterface.pl/Webservice/GenericTicketConnectorREST/Agent"
```

Query-string authentication may also be supported by GenericInterface, but headers are preferred for GET requests because credentials in URLs may be exposed through logs, browser history, or intermediary systems. Header authentication still requires validation on the intended Znuny 6.5.20 server.

## Znuny 6.5.20 Validation Checklist

Manual server-side validation must confirm:

- the source XML and Perl checks pass;
- the package builds successfully as a real `.opm`;
- the package installs successfully;
- package verification succeeds;
- `User::AgentList` appears in Add Operation;
- unauthenticated requests are rejected;
- invalid credentials are rejected;
- authenticated customer users are rejected;
- authenticated agent users are allowed;
- only active non-out-of-office agents are returned;
- only `UserID`, `UserLogin`, and `UserFullname` are returned;
- no sensitive user fields appear;
- sorting is deterministic;
- both supported authentication forms work;
- the manually configured REST endpoint returns valid JSON;
- package upgrade behavior works;
- package uninstall removes only package-owned files.

## Upgrade and Uninstall

Version `1.0.0` does not add database tables, migrations, daemon jobs, or install/uninstall handlers. Package ownership is limited to the runtime files listed in `ZnunyAgentList.sopm`, so normal Znuny Package Manager uninstall behavior should remove only package-owned files.

Upgrade and uninstall behavior must still be tested on Znuny 6.5.20 before production use.

## Current Validation Status

Local source editing is complete for the initial implementation. Server-side Perl syntax validation, package build, package installation, SysConfig discovery, authentication, authorization, REST behavior, upgrade, and uninstall validation remain pending for Znuny 6.5.20.
