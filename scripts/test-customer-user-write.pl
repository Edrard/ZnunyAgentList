#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    my $ScriptDir = $0;
    $ScriptDir =~ s{\\}{/}g;
    $ScriptDir =~ s{/[^/]*\z}{};
    unshift @INC, "$ScriptDir/..";

    package Kernel::GenericInterface::Operation::Common;

    sub Auth {
        return ( 2, 'User' );
    }

    sub ReturnError {
        my ( $Self, %Param ) = @_;
        return { Error => \%Param };
    }

    $INC{'Kernel/GenericInterface/Operation/Common.pm'} = 1;
}

use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;
use Kernel::GenericInterface::Operation::CustomerUser::Lookup;
use Kernel::GenericInterface::Operation::CustomerUser::Search;
use Kernel::GenericInterface::Operation::CustomerUser::Update;

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

{
    package Test::CustomerCompany;

    sub CustomerCompanyGet {
        my ( $Self, %Param ) = @_;

        return if $Param{CustomerID} eq 'missing-company';
        return (
            CustomerID          => $Param{CustomerID},
            CustomerCompanyName => 'Example Company',
            ValidID             => 1,
        );
    }

    sub CustomerCompanyList {
        return (
            'example-customer' => 'Example Company',
            'second-customer'  => 'Second Company',
        );
    }
}

{
    package Test::CustomerUser;

    sub CustomerUserDataGet {
        my ( $Self, %Param ) = @_;

        my $User = $Self->{Users}->{ lc( $Param{User} || q{} ) };
        return if !$User;

        return %{$User};
    }

    sub CustomerSearch {
        my ( $Self, %Param ) = @_;

        my $Valid = defined $Param{Valid} ? $Param{Valid} : 1;
        my $Email = lc( $Param{PostMasterSearch} || q{} );
        my $Search = lc( $Param{Search} || q{} );
        return if $Email eq q{} && $Search eq q{};

        my %Result;
        for my $Login ( sort keys %{ $Self->{Users} || {} } ) {
            my $User = $Self->{Users}->{$Login};
            next if $Valid && ( $User->{ValidID} || 0 ) != 1;
            if ( $Email ne q{} ) {
                next if lc( $User->{UserEmail} || q{} ) ne $Email;
            }
            if ( $Search ne q{} ) {
                next if index( lc( $User->{UserLogin} || q{} ), $Search ) < 0
                    && index( lc( $User->{UserEmail} || q{} ), $Search ) < 0
                    && index( lc( $User->{UserFirstname} || q{} ), $Search ) < 0
                    && index( lc( $User->{UserLastname} || q{} ), $Search ) < 0;
            }
            $Result{ $User->{UserLogin} } = $User->{UserFirstname} . q{ } . $User->{UserLastname};
        }

        return %Result;

    }

    sub CustomerUserAdd {
        my ( $Self, %Param ) = @_;

        $Self->{AddCount}++;
        $Self->{LastAdd} = { %Param };
        $Self->{Users}->{ lc $Param{UserLogin} } = {
            UserLogin      => $Param{UserLogin},
            UserCustomerID => $Param{UserCustomerID},
            UserFirstname  => $Param{UserFirstname},
            UserLastname   => $Param{UserLastname},
            UserEmail      => $Param{UserEmail},
            ValidID        => $Param{ValidID},
        };
        return 1;
    }

    sub CustomerUserUpdate {
        my ( $Self, %Param ) = @_;

        $Self->{UpdateCount}++;
        $Self->{LastUpdate} = { %Param };
        delete $Self->{Users}->{ lc $Param{ID} };
        $Self->{Users}->{ lc $Param{UserLogin} } = {
            UserLogin      => $Param{UserLogin},
            UserCustomerID => $Param{UserCustomerID},
            UserFirstname  => $Param{UserFirstname},
            UserLastname   => $Param{UserLastname},
            UserEmail      => $Param{UserEmail},
            ValidID        => $Param{ValidID},
        };
        return 1;
    }

    sub GenerateRandomPassword {
        my ( $Self, %Param ) = @_;

        $Self->{GenerateCount}++;
        $Self->{LastGenerateSize} = $Param{Size};
        return $Self->{NextPassword} if exists $Self->{NextPassword};

        return 'A' x 24;
    }
}

{
    package Test::Valid;

    sub ValidIDsGet {
        return (1);
    }
}

{
    package Test::OM;

    sub Get {
        my ( $Self, $Name ) = @_;

        return $Self->{$Name};
    }
}

{
    package Test::Config;

    sub Get {
        my ( $Self, $Name ) = @_;

        return 1             if $Name eq 'ZnunyAgentList::EnableTicketWriteOperations';
        return ['api_group'] if $Name eq 'ZnunyAgentList::AllowedWriteGroups';
        return ['api_group'] if $Name eq 'ZnunyAgentList::AllowedGroups';

        return;
    }
}

{
    package Test::Group;

    sub PermissionUserGet {
        return ( 1 => 'api_group' );
    }
}

my $CustomerUserObject = bless {
    Users => {
        'existing@example.com' => {
            UserLogin      => 'existing@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'Existing',
            UserLastname   => 'Customer',
            UserEmail      => 'existing@example.com',
            ValidID        => 1,
        },
        'duplicate@example.com' => {
            UserLogin      => 'duplicate@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'Duplicate',
            UserLastname   => 'Customer',
            UserEmail      => 'duplicate@example.com',
            ValidID        => 1,
        },
        'disabled@example.com' => {
            UserLogin      => 'disabled@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'Disabled',
            UserLastname   => 'Customer',
            UserEmail      => 'disabled@example.com',
            ValidID        => 2,
        },
        'disabled-email-owner@example.com' => {
            UserLogin      => 'disabled-email-owner@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'DisabledEmail',
            UserLastname   => 'Customer',
            UserEmail      => 'disabled-collision@example.com',
            ValidID        => 2,
        },
        'ambiguous-one@example.com' => {
            UserLogin      => 'ambiguous-one@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'Ambiguous',
            UserLastname   => 'One',
            UserEmail      => 'ambiguous@example.com',
            ValidID        => 1,
        },
        'ambiguous-two@example.com' => {
            UserLogin      => 'ambiguous-two@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'Ambiguous',
            UserLastname   => 'Two',
            UserEmail      => 'ambiguous@example.com',
            ValidID        => 2,
        },
    },
}, 'Test::CustomerUser';
my $OM = bless {
    'Kernel::System::CustomerCompany' => bless( {}, 'Test::CustomerCompany' ),
    'Kernel::System::CustomerUser'    => $CustomerUserObject,
    'Kernel::Config'                  => bless( {}, 'Test::Config' ),
    'Kernel::System::Group'           => bless( {}, 'Test::Group' ),
    'Kernel::System::Valid'           => bless( {}, 'Test::Valid' ),
}, 'Test::OM';

{
    local $Kernel::OM = $OM;

    my ( $ByLogin, $ByLoginErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Login => 'existing@example.com',
    );
    Assert( $ByLogin->{Login} eq 'existing@example.com', 'lookup by login must be exact' );
    Assert( $ByLogin->{Status} eq 'active', 'lookup by active login returns active status' );
    Assert(
        join( q{,}, sort keys %{$ByLogin} ) eq 'CustomerID,Email,FirstName,LastName,Login,Status',
        'lookup response exposes exactly the public customer user fields',
    );
    Assert( !@{$ByLoginErrors}, 'lookup by login must not return errors' );

    my ( $DisabledByLogin, $DisabledByLoginErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Login => 'disabled@example.com',
    );
    Assert( $DisabledByLogin->{Login} eq 'disabled@example.com', 'lookup by disabled login must find disabled user' );
    Assert( $DisabledByLogin->{Status} eq 'disabled', 'lookup by disabled login returns disabled status' );
    Assert( !@{$DisabledByLoginErrors}, 'lookup by disabled login must not return errors' );

    my ( $ByEmail, $ByEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => 'existing@example.com',
    );
    Assert( $ByEmail->{Email} eq 'existing@example.com', 'lookup by active email must cross-check exact email' );
    Assert( $ByEmail->{Status} eq 'active', 'lookup by active email returns active status' );
    Assert( !@{$ByEmailErrors}, 'lookup by email must not return errors' );

    my ( $DisabledByEmail, $DisabledByEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => 'disabled@example.com',
    );
    Assert( $DisabledByEmail->{Email} eq 'disabled@example.com', 'lookup by disabled email must find disabled user' );
    Assert( $DisabledByEmail->{Status} eq 'disabled', 'lookup by disabled email returns disabled status' );
    Assert( !@{$DisabledByEmailErrors}, 'lookup by disabled email must not return errors' );

    my ( $AmbiguousEmail, $AmbiguousEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => 'ambiguous@example.com',
    );
    Assert( !$AmbiguousEmail, 'lookup by ambiguous email must not choose an arbitrary user' );
    Assert( $AmbiguousEmailErrors->[0] eq 'Email matches multiple customer users.', 'ambiguous email must return deterministic error' );

    my $LookupOperation = bless {}, 'Kernel::GenericInterface::Operation::CustomerUser::Lookup';
    my $LookupResponse = $LookupOperation->Run(
        Data => {
            Login => 'disabled@example.com',
        },
    );
    Assert( $LookupResponse->{Data}->{Found} == 1, 'Lookup operation finds disabled users' );
    Assert(
        join( q{,}, sort keys %{ $LookupResponse->{Data}->{CustomerUser} } ) eq 'CustomerID,Email,FirstName,LastName,Login,Status',
        'Lookup operation CustomerUser object exposes exactly public fields',
    );
    Assert( $LookupResponse->{Data}->{CustomerUser}->{Status} eq 'disabled', 'Lookup operation returns disabled status' );

    my $SearchOperation = bless {}, 'Kernel::GenericInterface::Operation::CustomerUser::Search';
    my $SearchResponse = $SearchOperation->Run(
        Data => {
            Search => 'disabled',
            Limit  => 10,
        },
    );
    Assert(
        grep { $_->{Login} eq 'disabled@example.com' && $_->{Status} eq 'disabled' } @{ $SearchResponse->{Data}->{CustomerUsers} },
        'Search operation includes disabled customer users',
    );
    Assert(
        join( q{,}, sort keys %{ $SearchResponse->{Data}->{CustomerUsers}->[0] } ) eq 'CustomerID,Email,FirstName,LastName,Login,Status',
        'Search operation CustomerUser items expose exactly public fields',
    );

    my ( $WildcardEmail, $WildcardEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => '*@example.com',
    );
    Assert( !$WildcardEmail, 'lookup by email must reject wildcard-like email values' );
    Assert( $WildcardEmailErrors->[0] eq 'Email must be valid.', 'wildcard-like email must return a validation error' );

    my ( $InvalidEmailCreate, $InvalidEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'New',
        LastName   => 'Customer',
        Login      => 'new@example.com',
        Email      => 'not-an-email',
        CustomerID => 'example-customer',
        UserID     => 2,
    );
    Assert( !$InvalidEmailCreate, 'invalid email create must fail' );
    Assert( grep { $_ eq 'Email is required and must be valid.' } @{$InvalidEmailErrors}, 'invalid email error must be present' );

    my ( $MissingCompanyCreate, $MissingCompanyErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'New',
        LastName   => 'Customer',
        Login      => 'new@example.com',
        Email      => 'new@example.com',
        CustomerID => 'missing-company',
        UserID     => 2,
    );
    Assert( !$MissingCompanyCreate, 'missing company create must fail' );
    Assert( grep { $_ eq 'CustomerID was not found or is not valid.' } @{$MissingCompanyErrors}, 'missing company error must be present' );

    my ( $DuplicateCreate, $DuplicateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'Existing',
        LastName   => 'Customer',
        Login      => 'existing@example.com',
        Email      => 'existing@example.com',
        CustomerID => 'example-customer',
        UserID     => 2,
    );
    Assert( !$DuplicateCreate, 'duplicate login create must fail' );
    Assert( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateErrors}, 'duplicate active login error must be present' );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'duplicate active login must prevent CustomerUserAdd' );

    my ( $DuplicateDisabledLoginCreate, $DuplicateDisabledLoginErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'Existing',
        LastName   => 'Customer',
        Login      => 'disabled@example.com',
        Email      => 'unique-disabled-login@example.com',
        CustomerID => 'example-customer',
        UserID     => 2,
    );
    Assert( !$DuplicateDisabledLoginCreate, 'duplicate disabled login create must fail' );
    Assert( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateDisabledLoginErrors}, 'duplicate disabled login error must be present' );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'duplicate disabled login must prevent CustomerUserAdd' );

    my ( $DuplicateActiveEmailCreate, $DuplicateActiveEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'Email',
        LastName   => 'Customer',
        Login      => 'unique-active-email@example.com',
        Email      => 'existing@example.com',
        CustomerID => 'example-customer',
        UserID     => 2,
    );
    Assert( !$DuplicateActiveEmailCreate, 'duplicate active email create must fail' );
    Assert( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateActiveEmailErrors}, 'duplicate active email error must be present' );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'duplicate active email must prevent CustomerUserAdd' );

    my ( $DuplicateDisabledEmailCreate, $DuplicateDisabledEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'Email',
        LastName   => 'Customer',
        Login      => 'unique-disabled-email@example.com',
        Email      => 'disabled-collision@example.com',
        CustomerID => 'example-customer',
        UserID     => 2,
    );
    Assert( !$DuplicateDisabledEmailCreate, 'duplicate disabled email create must fail' );
    Assert( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateDisabledEmailErrors}, 'duplicate disabled email error must be present' );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'duplicate disabled email must prevent CustomerUserAdd' );

    my ( $PasswordCreate, $PasswordCreateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName        => 'Updated',
        LastName         => 'Customer',
        Login            => 'updated@example.com',
        Email            => 'updated@example.com',
        CustomerID       => 'second-customer',
        UserID           => 2,
        PasswordProvided => 1,
    );
    Assert( !$PasswordCreate, 'create must reject supplied password input' );
    Assert(
        grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{$PasswordCreateErrors},
        'create must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'create with supplied password must not call CustomerUserAdd' );

    {
        local $CustomerUserObject->{NextPassword} = q{};
        my ( $FailedPasswordCreate, $FailedPasswordErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
            FirstName  => 'Updated',
            LastName   => 'Customer',
            Login      => 'updated@example.com',
            Email      => 'updated@example.com',
            CustomerID => 'second-customer',
            UserID     => 2,
        );
        Assert( !$FailedPasswordCreate, 'empty generated password must fail create safely' );
        Assert(
            grep { $_ eq 'Customer user password could not be generated.' } @{$FailedPasswordErrors},
            'empty generated password must return safe generic error',
        );
        Assert( !exists $CustomerUserObject->{LastAdd}, 'empty generated password must prevent CustomerUserAdd' );
    }

    my ( $Created, $CreateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'Updated',
        LastName   => 'Customer',
        Login      => 'updated@example.com',
        Email      => 'updated@example.com',
        CustomerID => 'second-customer',
        UserID     => 2,
    );
    Assert( $CustomerUserObject->{GenerateCount}, 'create must invoke native customer-user random password generator' );
    Assert( $CustomerUserObject->{LastGenerateSize} == 24, 'create must request a 24-character generated password' );
    Assert( exists $CustomerUserObject->{LastAdd}->{UserPassword}, 'create must pass generated password to native CustomerUserAdd' );
    Assert( length $CustomerUserObject->{LastAdd}->{UserPassword} >= 24, 'generated password passed to CustomerUserAdd must be non-empty and long enough' );
    Assert( !$Created->{UserPassword} && !$Created->{Password}, 'create response must not return password' );
    Assert( $Created->{Login} eq 'updated@example.com', 'valid create returns public Login' );
    Assert( $Created->{Status} eq 'active', 'valid create returns active status' );
    Assert( !@{$CreateErrors}, 'valid create must not return errors' );

    delete $CustomerUserObject->{LastAdd};

    my ( $PasswordUpdate, $PasswordUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        CustomerID        => 'second-customer',
        UserID            => 2,
        PasswordProvided  => 1,
    );
    Assert( !$PasswordUpdate, 'update must reject supplied password input' );
    Assert(
        grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{$PasswordUpdateErrors},
        'update must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'update with supplied password must not call CustomerUserUpdate' );

    my $Operation = bless {}, 'Kernel::GenericInterface::Operation::CustomerUser::Update';

    my $RouteOnlyResponse = $Operation->Run(
        CustomerUserLogin => 'existing@example.com',
        Data              => {
            LastName => 'RuntimePatched',
        },
    );
    Assert( $RouteOnlyResponse->{Data}->{Updated}, 'route-only LastName PATCH must update' );
    Assert( !@{ $RouteOnlyResponse->{Data}->{Errors} }, 'route-only LastName PATCH must not return errors' );
    Assert( $CustomerUserObject->{LastUpdate}->{ID} eq 'existing@example.com', 'route CustomerUserLogin must be current update ID' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLogin} eq 'existing@example.com', 'omitted Login must preserve original login' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLogin} ne 'Login', 'literal field name must not become UserLogin value' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLogin} ne 'Email', 'literal Email field name must not become UserLogin value' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserFirstname} eq 'Existing', 'LastName-only PATCH must preserve first name' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLastname} eq 'RuntimePatched', 'LastName-only PATCH must use supplied last name' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserEmail} eq 'existing@example.com', 'LastName-only PATCH must preserve valid stored email' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserCustomerID} eq 'example-customer', 'LastName-only PATCH must preserve customer ID' );
    Assert( !exists $CustomerUserObject->{LastUpdate}->{UserPassword}, 'omitted password must remain unchanged' );
    Assert( !$RouteOnlyResponse->{Data}->{CustomerUser}->{UserPassword} && !$RouteOnlyResponse->{Data}->{CustomerUser}->{Password}, 'update response must not return password' );
    Assert(
        join( q{,}, sort keys %{ $RouteOnlyResponse->{Data}->{CustomerUser} } ) eq 'CustomerID,Email,FirstName,LastName,Login,Status',
        'update response must expose only safe customer user fields',
    );
    Assert( $RouteOnlyResponse->{Data}->{CustomerUser}->{LastName} eq 'RuntimePatched', 'update response must return actual updated user' );

    my $MismatchResponse = $Operation->Run(
        CustomerUserLogin => 'existing@example.com',
        Data              => {
            CurrentLogin => 'other@example.com',
            LastName     => 'Mismatch',
        },
    );
    Assert( !$MismatchResponse->{Data}->{Updated}, 'mismatched route and body current login must not update' );
    Assert(
        grep { $_ eq 'CurrentLogin must match the route CustomerUserLogin.' } @{ $MismatchResponse->{Data}->{Errors} },
        'mismatched route and body current login must return validation error',
    );

    my ( $DuplicateUpdate, $DuplicateUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'duplicate@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateUpdate, 'duplicate target login update must fail' );
    Assert( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateUpdateErrors}, 'duplicate active target login error must be present' );

    delete $CustomerUserObject->{LastUpdate};
    my ( $DuplicateDisabledLoginUpdate, $DuplicateDisabledLoginUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'disabled@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateDisabledLoginUpdate, 'duplicate disabled target login update must fail' );
    Assert( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateDisabledLoginUpdateErrors}, 'duplicate disabled target login error must be present' );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'duplicate disabled target login must prevent CustomerUserUpdate' );

    my ( $DuplicateActiveEmailUpdate, $DuplicateActiveEmailUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Email             => 'duplicate@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateActiveEmailUpdate, 'duplicate active target email update must fail' );
    Assert( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateActiveEmailUpdateErrors}, 'duplicate active target email error must be present' );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'duplicate active target email must prevent CustomerUserUpdate' );

    my ( $DuplicateDisabledEmailUpdate, $DuplicateDisabledEmailUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Email             => 'disabled-collision@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateDisabledEmailUpdate, 'duplicate disabled target email update must fail' );
    Assert( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateDisabledEmailUpdateErrors}, 'duplicate disabled target email error must be present' );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'duplicate disabled target email must prevent CustomerUserUpdate' );

    my ( $UnchangedIdentity, $UnchangedIdentityErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'existing@example.com',
        Email             => 'existing@example.com',
        UserID            => 2,
    );
    Assert( $UnchangedIdentity, 'unchanged Login and Email must not conflict with the same user' );
    Assert( !@{$UnchangedIdentityErrors}, 'unchanged Login and Email must not return uniqueness errors' );

    my ( $NotFoundUpdate, $NotFoundUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'missing@example.com',
        LastName          => 'Missing',
        UserID            => 2,
    );
    Assert( !$NotFoundUpdate, 'missing customer update must fail' );
    Assert( grep { $_ eq 'Customer user not found.' } @{$NotFoundUpdateErrors}, 'missing customer update must return structured error' );

    my ( $Renamed, $RenameErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'renamed@example.com',
        CustomerID        => 'second-customer',
        UserID            => 2,
    );
    Assert( $CustomerUserObject->{LastUpdate}->{ID} eq 'existing@example.com', 'rename must use route login as ID' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLogin} eq 'renamed@example.com', 'update must support explicit login rename' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserFirstname} eq 'Existing', 'rename must preserve unspecified first name' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLastname} eq 'RuntimePatched', 'rename must preserve prior last name' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserEmail} eq 'existing@example.com', 'rename must preserve valid stored email' );
    Assert( $Renamed->{Login} eq 'renamed@example.com', 'rename response must return actual renamed user' );
    Assert( !@{$RenameErrors}, 'valid rename must not return errors' );

    my ( $Companies, $CompanyErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
        Search => 'example',
        Limit  => 10,
    );
    Assert( @{$Companies} == 2, 'company list must return valid companies' );
    Assert(
        join( q{,}, sort keys %{ $Companies->[0] } ) eq 'CustomerCompanyName,CustomerID',
        'company list response must expose only CustomerID and CustomerCompanyName',
    );
    Assert( !@{$CompanyErrors}, 'company list must not return errors' );

    my ( $RefCompanies, $RefCompanyErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
        Search => ['example'],
        Limit  => 10,
    );
    Assert( !@{$RefCompanies}, 'company list must not broaden ref-valued Search to an unfiltered lookup' );
    Assert( $RefCompanyErrors->[0] eq 'Search must be a scalar string.', 'company list must report ref-valued Search safely' );
}

my $ScriptDir = $0;
$ScriptDir =~ s{\\}{/}g;
$ScriptDir =~ s{/[^/]*\z}{};

for my $Path ( "$ScriptDir/../README.md", "$ScriptDir/../examples/webservices/AdvancedZnunyAgentListREST.yml" ) {
    open my $Handle, '<', $Path or die "FAIL: cannot read documentation fixture\n";
    my $Content = do { local $/; <$Handle> };
    close $Handle;

    Assert( $Content =~ m{Password input is not supported}smx, 'documentation must state password input is unsupported' );
    Assert( $Content =~ m{generates a private random password}smx, 'documentation must state create generates a private random password' );
}

print "PASS: customer user write regression checks\n";
