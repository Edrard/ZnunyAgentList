# ZnunyAgentList Changelog

## 1.0.0 - 2026-06-12

- Added the initial `User::AgentList` GenericInterface provider operation for Znuny 6.5 LTS.
- Added explicit agent response allow-list containing only `UserID`, `UserLogin`, and `UserFullname`.
- Added authentication through the standard `Kernel::GenericInterface::Operation::Common` GenericInterface provider authentication flow.
- Added authorization restriction to authenticated agent users.
- Added SysConfig operation registration metadata.
- Added SOPM source package metadata for the package-owned runtime files.
- Added Linux source verification helper.
- Added Linux package build helper using the confirmed Znuny 6.5.20 `Dev::Package::Build` workflow.
- Corrected active out-of-office filtering to use `GetUserData()` `OutOfOfficeMessage`.
- Corrected GenericInterface operation registration navigation to `GenericInterface::Operation::ModuleRegistration`.
- Hardened Linux package build helper permission checks for the `otrs` user.
- Documented that `UserList(... NoOutOfOffice => 1)` provides clean display names but does not filter out-of-office users.
- Documented preferred header authentication examples for GET requests.

Server-side validation on Znuny 6.5.20 is still required.
