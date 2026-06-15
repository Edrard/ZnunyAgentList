# ZnunyAgentList Changelog

## 1.0.0 - 2026-06-12

### Added

- Added the initial `User::AgentList` GenericInterface provider operation for Znuny 6.5 LTS.
- Added queue list and queue lookup operations.
- Added customer user search and lookup operations.
- Added hostname-based ticket default resolver.
- Added ticket state, priority, type, service, and SLA list operations.
- Added package-specific `ZnunyAgentList::Config` and `ZnunyAgentList::Health` operations.
- Added non-mutating `Ticket::ValidateTicketCreate` preflight validation.
- Added SOPM source package metadata for package-owned runtime files.
- Added Linux source verification helper.
- Added Linux package build helper using the confirmed Znuny 6.5.20 `Dev::Package::Build` workflow.

### Changed

- Corrected active out-of-office filtering to use `GetUserData()` `OutOfOfficeMessage`.
- Corrected GenericInterface operation registration navigation to `GenericInterface::Operation::ModuleRegistration`.
- Removed generic `System::Config` and `System::Health` operation names.
- Updated Linux verification and package build helpers for the expanded runtime file set.
- Hardened Linux package build helper permission checks for the `otrs` user.

### Security

- Added authentication through the standard `Kernel::GenericInterface::Operation::Common` GenericInterface provider authentication flow.
- Added authorization restriction to authenticated Znuny agent users.
- Added group-based authorization through `ZnunyAgentList::AllowedGroups` with default group `api_group`.
- Added explicit response allow-lists for agent, queue, customer user, ticket dictionary, config, and health responses.
- Hardened customer user search against broad enumeration and fixed Znuny 6.5.20 `CustomerSearch()` hash return handling.
- Hardened customer user search against wildcard-only broad searches.
- Added scalar-only input length limits and ASCII control-character handling.
- Strengthened source verification against obvious write-style operation calls.

### Documentation

- Documented that `UserList(... NoOutOfOffice => 1)` provides clean display names but does not filter out-of-office users.
- Documented required dedicated API group setup using `api_group`.
- Documented that `Health` is authenticated and group-protected.
- Documented that `ValidateTicketCreate` never creates tickets.

### Validation

- Scoped the `ZZZAAuto.pm` reference check to runtime/package files to avoid documentation false positives.
- Server-side validation on Znuny 6.5.20 is still required.
- Perl syntax, package build, package installation, GenericInterface discovery, REST behavior, upgrade, and uninstall validation are not claimed by local Windows checks.
