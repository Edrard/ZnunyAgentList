# ZnunyAgentList Changelog

## 1.2.0 - Unreleased

### Added

- Added safe `Ticket::Get` operation.
- Added safe `Ticket::Search` operation with enforced default and maximum limits.
- Added write-control SysConfig settings for future controlled write operations.
- Added controlled `Ticket::ArticleCreate` operation.
- Added controlled `Ticket::Close` operation.
- Added controlled `Ticket::Reopen` operation.

### Changed

- Enhanced `Ticket::StateList` with state type information.
- Enforced write permission checks with `ZnunyAgentList::EnableTicketWriteOperations` and `ZnunyAgentList::AllowedWriteGroups`.
- Updated `AdvancedZnunyAgentListREST` template with full read/write ticket routes.
- Updated README with final `1.2.0` REST API documentation.
- Updated verification checks for controlled write operations.
- Strengthened source verification for controlled write security guardrails and corrected write setting descriptions.
- Updated the optional `AdvancedZnunyAgentListREST` Web Service template to preserve standard GenericTicketConnector session and ticket operations for backward compatibility.

### Validation

- Server build, package installation, Web Service YAML import, operation discovery, REST validation, upgrade, and uninstall validation are still pending.

## 1.1.0 - 2026-06-15

### Added

- Added queue list and queue lookup operations.
- Added customer user search and lookup operations.
- Added hostname-based ticket default resolver.
- Added ticket state, priority, type, service, and SLA list operations.
- Added package-specific `ZnunyAgentList::Config` and `ZnunyAgentList::Health` operations.
- Added non-mutating `Ticket::ValidateTicketCreate` preflight validation.
- Added optional `AdvancedZnunyAgentListREST.yml` Web Service import template with all ZnunyAgentList REST routes.

### Changed

- Removed generic `System::Config` and `System::Health` operation names.
- Updated Linux verification and package build helpers for the expanded runtime file set.
- Hardened Linux package build helper permission checks for the `otrs` user.

### Security

- Added group-based authorization through `ZnunyAgentList::AllowedGroups` with default group `api_group`.
- Added explicit response allow-lists for queue, customer user, ticket dictionary, config, and health responses.
- Hardened customer user search against broad enumeration and fixed Znuny 6.5.20 `CustomerSearch()` hash return handling.
- Hardened customer user search against wildcard-only broad searches.
- Added scalar-only input length limits and ASCII control-character handling.
- Strengthened source verification against obvious write-style operation calls.
- Scoped the `ZZZAAuto.pm` reference check to runtime/package files to avoid documentation false positives.

### Documentation

- Rewrote README as a production/operator guide.
- Documented required dedicated API group setup using `api_group`.
- Documented that `Health` is authenticated and group-protected.
- Documented that `ValidateTicketCreate` never creates tickets.
- Documented manual Web Service YAML import and smoke-test checks.
- Corrected pre-install Perl syntax check examples to include the package source root in `@INC`.

### Validation

- Server-side source verification and Perl syntax checks were run on Znuny 6.5.20.
- Package build still needs to be rerun after this version bump.
- Package installation, GenericInterface discovery, REST behavior, upgrade, and uninstall validation are still required.

## 1.0.0 - 2026-06-12

### Added

- Added the initial `User::AgentList` GenericInterface provider operation for Znuny 6.5 LTS.
- Added explicit agent response allow-list containing only `UserID`, `UserLogin`, and `UserFullname`.
- Added authentication through the standard GenericInterface provider authentication flow.
- Added authorization restriction to authenticated agent users.
- Added SysConfig operation registration metadata.
- Added SOPM source package metadata for the package-owned runtime files.
- Added Linux source verification helper.
- Added Linux package build helper.

### Changed

- Corrected active out-of-office filtering to use `GetUserData()` `OutOfOfficeMessage`.
- Corrected GenericInterface operation registration navigation to `GenericInterface::Operation::ModuleRegistration`.

### Documentation

- Documented that `UserList(... NoOutOfOffice => 1)` provides clean display names but does not filter out-of-office users.
