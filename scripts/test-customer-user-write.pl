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
use Kernel::GenericInterface::Operation::CustomerUser::Create;
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
    package Test::Ticket;

    sub TicketSearch {
        my ( $Self, %Param ) = @_;

        $Self->{SearchCount}++;
        $Self->{LastSearch} = { %Param };

        my $Login = $Param{CustomerUserLoginRaw} || q{};
        return @{ $Self->{SearchResults}->{$Login} || [] };
    }

    sub TicketGet {
        my ( $Self, %Param ) = @_;

        $Self->{GetCount}++;
        push @{ $Self->{GetCalls} }, { %Param };

        my $Ticket = $Self->{Tickets}->{ $Param{TicketID} };
        return if !$Ticket;

        return %{$Ticket};
    }

    sub TicketCustomerSet {
        my ( $Self, %Param ) = @_;

        $Self->{SetCount}++;
        push @{ $Self->{SetCalls} }, { %Param };

        return if $Self->{FailSet}->{ $Param{TicketID} };

        $Self->{Tickets}->{ $Param{TicketID} }->{CustomerID} = $Param{No}
            if exists $Self->{Tickets}->{ $Param{TicketID} } && defined $Param{No};

        return 1;
    }

    sub Reset {
        my ($Self) = @_;

        delete @{$Self}{qw(SearchCount LastSearch GetCount GetCalls SetCount SetCalls FailSet SearchResults Tickets)};
        $Self->{SearchResults} = {};
        $Self->{Tickets}       = {};
        $Self->{FailSet}       = {};

        return 1;
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
my $TicketObject = bless {}, 'Test::Ticket';
$TicketObject->Reset();

my $OM = bless {
    'Kernel::System::CustomerCompany' => bless( {}, 'Test::CustomerCompany' ),
    'Kernel::System::CustomerUser'    => $CustomerUserObject,
    'Kernel::System::Ticket'          => $TicketObject,
    'Kernel::Config'                  => bless( {}, 'Test::Config' ),
    'Kernel::System::Group'           => bless( {}, 'Test::Group' ),
    'Kernel::System::Valid'           => bless( {}, 'Test::Valid' ),
}, 'Test::OM';

my $LookupKeys = 'CustomerID,Email,FirstName,LastName,Login,Status,UserCustomerID,UserEmail,UserFirstname,UserLastname,UserLogin';
my $SearchKeys = 'Status,UserCustomerID,UserEmail,UserFirstname,UserLastname,UserLogin';

{
    local $Kernel::OM = $OM;

    my ( $ByLogin, $ByLoginErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Login => 'existing@example.com',
    );
    Assert( $ByLogin->{Login} eq 'existing@example.com', 'lookup by login must be exact' );
    Assert( $ByLogin->{UserLogin} eq 'existing@example.com', 'lookup by login must retain legacy UserLogin alias' );
    Assert( $ByLogin->{UserEmail} eq 'existing@example.com', 'lookup by login must retain legacy UserEmail alias' );
    Assert( $ByLogin->{UserCustomerID} eq 'example-customer', 'lookup by login must retain legacy UserCustomerID alias' );
    Assert( $ByLogin->{UserFirstname} eq 'Existing', 'lookup by login must retain legacy UserFirstname alias' );
    Assert( $ByLogin->{UserLastname} eq 'Customer', 'lookup by login must retain legacy UserLastname alias' );
    Assert( $ByLogin->{Status} eq 'active', 'lookup by active login returns active status' );
    Assert(
        join( q{,}, sort keys %{$ByLogin} ) eq $LookupKeys,
        'lookup response exposes canonical fields and legacy aliases',
    );
    Assert( !@{$ByLoginErrors}, 'lookup by login must not return errors' );

    my ( $DisabledByLogin, $DisabledByLoginErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Login => 'disabled@example.com',
    );
    Assert( $DisabledByLogin->{Login} eq 'disabled@example.com', 'lookup by disabled login must find disabled user' );
    Assert( $DisabledByLogin->{UserLogin} eq 'disabled@example.com', 'lookup by disabled login must retain legacy UserLogin alias' );
    Assert( $DisabledByLogin->{Status} eq 'disabled', 'lookup by disabled login returns disabled status' );
    Assert( !@{$DisabledByLoginErrors}, 'lookup by disabled login must not return errors' );

    my ( $ByEmail, $ByEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => 'existing@example.com',
    );
    Assert( $ByEmail->{Email} eq 'existing@example.com', 'lookup by active email must cross-check exact email' );
    Assert( $ByEmail->{UserEmail} eq 'existing@example.com', 'lookup by active email must retain legacy UserEmail alias' );
    Assert( $ByEmail->{Status} eq 'active', 'lookup by active email returns active status' );
    Assert( !@{$ByEmailErrors}, 'lookup by email must not return errors' );

    my ( $DisabledByEmail, $DisabledByEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => 'disabled@example.com',
    );
    Assert( $DisabledByEmail->{Email} eq 'disabled@example.com', 'lookup by disabled email must find disabled user' );
    Assert( $DisabledByEmail->{UserEmail} eq 'disabled@example.com', 'lookup by disabled email must retain legacy UserEmail alias' );
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
    Assert( exists $LookupResponse->{Data}->{Errors}, 'Lookup operation preserves Errors envelope field' );
    Assert( exists $LookupResponse->{Data}->{CustomerUser}, 'Lookup operation preserves CustomerUser envelope field' );
    Assert(
        join( q{,}, sort keys %{ $LookupResponse->{Data}->{CustomerUser} } ) eq $LookupKeys,
        'Lookup operation CustomerUser object exposes canonical fields and legacy aliases',
    );
    Assert( $LookupResponse->{Data}->{CustomerUser}->{Status} eq 'disabled', 'Lookup operation returns disabled status' );
    Assert( $LookupResponse->{Data}->{CustomerUser}->{UserLogin} eq 'disabled@example.com', 'Lookup operation retains legacy UserLogin alias' );

    my $SearchOperation = bless {}, 'Kernel::GenericInterface::Operation::CustomerUser::Search';
    my $SearchResponse = $SearchOperation->Run(
        Data => {
            Search => 'disabled',
            Limit  => 10,
        },
    );
    Assert(
        exists $SearchResponse->{Success} && exists $SearchResponse->{Data} && exists $SearchResponse->{Data}->{CustomerUsers},
        'Search operation preserves Success/Data/CustomerUsers envelope',
    );
    Assert(
        scalar( grep { $_->{UserLogin} eq 'disabled@example.com' && $_->{Status} eq 'disabled' } @{ $SearchResponse->{Data}->{CustomerUsers} } ),
        'Search operation includes disabled customer users',
    );
    Assert(
        join( q{,}, sort keys %{ $SearchResponse->{Data}->{CustomerUsers}->[0] } ) eq $SearchKeys,
        'Search operation CustomerUser items preserve legacy public fields plus Status',
    );
    Assert( !exists $SearchResponse->{Data}->{CustomerUsers}->[0]->{Login}, 'Search operation must not replace legacy UserLogin with canonical Login' );
    Assert( exists $SearchResponse->{Data}->{CustomerUsers}->[0]->{UserEmail}, 'Search operation must retain legacy UserEmail' );
    Assert( exists $SearchResponse->{Data}->{CustomerUsers}->[0]->{UserCustomerID}, 'Search operation must retain legacy UserCustomerID' );
    Assert( exists $SearchResponse->{Data}->{CustomerUsers}->[0]->{UserFirstname}, 'Search operation must retain legacy UserFirstname' );
    Assert( exists $SearchResponse->{Data}->{CustomerUsers}->[0]->{UserLastname}, 'Search operation must retain legacy UserLastname' );

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
    Assert( scalar( grep { $_ eq 'Email is required and must be valid.' } @{$InvalidEmailErrors} ), 'invalid email error must be present' );

    my ( $MissingCompanyCreate, $MissingCompanyErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'New',
        LastName   => 'Customer',
        Login      => 'new@example.com',
        Email      => 'new@example.com',
        CustomerID => 'missing-company',
        UserID     => 2,
    );
    Assert( !$MissingCompanyCreate, 'missing company create must fail' );
    Assert( scalar( grep { $_ eq 'CustomerID was not found or is not valid.' } @{$MissingCompanyErrors} ), 'missing company error must be present' );

    my ( $DuplicateCreate, $DuplicateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        FirstName  => 'Existing',
        LastName   => 'Customer',
        Login      => 'existing@example.com',
        Email      => 'existing@example.com',
        CustomerID => 'example-customer',
        UserID     => 2,
    );
    Assert( !$DuplicateCreate, 'duplicate login create must fail' );
    Assert( scalar( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateErrors} ), 'duplicate active login error must be present' );
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
    Assert( scalar( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateDisabledLoginErrors} ), 'duplicate disabled login error must be present' );
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
    Assert( scalar( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateActiveEmailErrors} ), 'duplicate active email error must be present' );
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
    Assert( scalar( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateDisabledEmailErrors} ), 'duplicate disabled email error must be present' );
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
        scalar( grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{$PasswordCreateErrors} ),
        'create must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'create with supplied password must not call CustomerUserAdd' );

    my $CreateOperation = bless {}, 'Kernel::GenericInterface::Operation::CustomerUser::Create';

    $TicketObject->Reset();
    my $AuthPasswordCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin  => 'api-user',
            Password   => 'api-auth-secret',
            FirstName  => 'Auth',
            LastName   => 'Create',
            Login      => 'auth-create@example.com',
            Email      => 'auth-create@example.com',
            CustomerID => 'second-customer',
        },
    );
    Assert( $AuthPasswordCreateResponse->{Data}->{Created}, 'Create operation must allow GenericInterface auth Password in transport data' );
    Assert( !@{ $AuthPasswordCreateResponse->{Data}->{Errors} }, 'Create operation auth Password must not produce supplied-password validation error' );
    Assert( $CustomerUserObject->{LastAdd}->{UserLogin} eq 'auth-create@example.com', 'Create operation must still write the intended customer Login' );
    Assert( exists $CustomerUserObject->{LastAdd}->{UserPassword}, 'Create operation must still generate a private customer password' );
    Assert(
        !$AuthPasswordCreateResponse->{Data}->{CustomerUser}->{UserPassword}
            && !$AuthPasswordCreateResponse->{Data}->{CustomerUser}->{Password},
        'Create operation auth Password response must not expose any password',
    );
    Assert( !exists $AuthPasswordCreateResponse->{Data}->{ReconcileTickets}, 'Create operation without ReconcileTickets must preserve original response shape' );
    Assert( !( $TicketObject->{SearchCount} || 0 ), 'Create operation without ReconcileTickets must not search tickets' );
    Assert( !( $TicketObject->{SetCount} || 0 ), 'Create operation without ReconcileTickets must not update tickets' );
    Assert(
        !scalar( grep { $_ eq 'ReconcileTickets must be 0 or 1.' } @{ $AuthPasswordCreateResponse->{Data}->{Errors} } ),
        'Create operation without ReconcileTickets must not return ReconcileTickets validation error',
    );

    $TicketObject->Reset();
    delete $CustomerUserObject->{LastAdd};
    my $UndefinedReconcileCreateResponse = $CreateOperation->Run(
        ReconcileTickets => undef,
        Data             => {
            UserLogin  => 'api-user',
            Password   => 'api-auth-secret',
            FirstName  => 'Undefined',
            LastName   => 'Reconcile',
            Login      => 'undefined-reconcile@example.com',
            Email      => 'undefined-reconcile@example.com',
            CustomerID => 'second-customer',
        },
    );
    Assert( $UndefinedReconcileCreateResponse->{Data}->{Created}, 'Create operation with transport-level undef ReconcileTickets must create customer user' );
    Assert( !exists $UndefinedReconcileCreateResponse->{Data}->{ReconcileTickets}, 'Create operation with undef ReconcileTickets must preserve original response shape' );
    Assert(
        !scalar( grep { $_ eq 'ReconcileTickets must be 0 or 1.' } @{ $UndefinedReconcileCreateResponse->{Data}->{Errors} } ),
        'Create operation with undef ReconcileTickets must not return validation error',
    );
    Assert( !( $TicketObject->{SearchCount} || 0 ), 'Create operation with undef ReconcileTickets must not search tickets' );
    Assert( !( $TicketObject->{SetCount} || 0 ), 'Create operation with undef ReconcileTickets must not update tickets' );

    $TicketObject->Reset();
    delete $CustomerUserObject->{LastAdd};
    my $ReconcileZeroCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin         => 'api-user',
            Password          => 'api-auth-secret',
            FirstName         => 'No',
            LastName          => 'Reconcile',
            Login             => 'reconcile-zero@example.com',
            Email             => 'reconcile-zero@example.com',
            CustomerID        => 'second-customer',
            ReconcileTickets  => 0,
        },
    );
    Assert( $ReconcileZeroCreateResponse->{Data}->{Created}, 'Create operation with ReconcileTickets 0 must still create customer user' );
    Assert( !exists $ReconcileZeroCreateResponse->{Data}->{ReconcileTickets}, 'Create operation with ReconcileTickets 0 must not add reconciliation stats' );
    Assert( !( $TicketObject->{SearchCount} || 0 ), 'Create operation with ReconcileTickets 0 must not search tickets' );
    Assert( !( $TicketObject->{SetCount} || 0 ), 'Create operation with ReconcileTickets 0 must not update tickets' );

    $TicketObject->Reset();
    delete $CustomerUserObject->{LastAdd};
    my $InvalidReconcileCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin        => 'api-user',
            Password         => 'api-auth-secret',
            FirstName        => 'Bad',
            LastName         => 'Reconcile',
            Login            => 'invalid-reconcile@example.com',
            Email            => 'invalid-reconcile@example.com',
            CustomerID       => 'second-customer',
            ReconcileTickets => 'true',
        },
    );
    Assert( !$InvalidReconcileCreateResponse->{Data}->{Created}, 'Create operation must reject non-0/1 ReconcileTickets values' );
    Assert(
        scalar( grep { $_ eq 'ReconcileTickets must be 0 or 1.' } @{ $InvalidReconcileCreateResponse->{Data}->{Errors} } ),
        'invalid ReconcileTickets must return deterministic validation error',
    );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'invalid ReconcileTickets must prevent CustomerUserAdd' );
    Assert( !( $TicketObject->{SearchCount} || 0 ), 'invalid ReconcileTickets must not search tickets' );

    $TicketObject->Reset();
    my $RefReconcileCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin        => 'api-user',
            Password         => 'api-auth-secret',
            FirstName        => 'Ref',
            LastName         => 'Reconcile',
            Login            => 'ref-reconcile@example.com',
            Email            => 'ref-reconcile@example.com',
            CustomerID       => 'second-customer',
            ReconcileTickets => [1],
        },
    );
    Assert( !$RefReconcileCreateResponse->{Data}->{Created}, 'Create operation must reject ref-valued ReconcileTickets' );
    Assert(
        scalar( grep { $_ eq 'ReconcileTickets must be 0 or 1.' } @{ $RefReconcileCreateResponse->{Data}->{Errors} } ),
        'ref-valued ReconcileTickets must return deterministic validation error',
    );
    Assert( !( $TicketObject->{SearchCount} || 0 ), 'ref-valued ReconcileTickets must not search tickets' );

    $TicketObject->Reset();
    my $DuplicateReconcileCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin        => 'api-user',
            Password         => 'api-auth-secret',
            FirstName        => 'Duplicate',
            LastName         => 'Reconcile',
            Login            => 'existing@example.com',
            Email            => 'duplicate-reconcile@example.com',
            CustomerID       => 'second-customer',
            ReconcileTickets => 1,
        },
    );
    Assert( !$DuplicateReconcileCreateResponse->{Data}->{Created}, 'failed create with ReconcileTickets 1 must keep Created 0' );
    Assert( !exists $DuplicateReconcileCreateResponse->{Data}->{ReconcileTickets}, 'failed create must not return reconciliation stats' );
    Assert( !( $TicketObject->{SearchCount} || 0 ), 'failed create with ReconcileTickets 1 must not search tickets' );

    $TicketObject->Reset();
    delete $CustomerUserObject->{LastAdd};
    my $NoMatchReconcileCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin        => 'api-user',
            Password         => 'api-auth-secret',
            FirstName        => 'NoMatch',
            LastName         => 'Reconcile',
            Login            => 'reconcile-nomatch@example.com',
            Email            => 'reconcile-nomatch@example.com',
            CustomerID       => 'second-customer',
            ReconcileTickets => 1,
        },
    );
    my $NoMatchStats = $NoMatchReconcileCreateResponse->{Data}->{ReconcileTickets};
    Assert( $NoMatchReconcileCreateResponse->{Data}->{Created}, 'Create operation with ReconcileTickets 1 must create before no-match reconciliation' );
    Assert( $NoMatchStats->{Requested} == 1, 'no-match reconciliation reports Requested 1' );
    Assert( $NoMatchStats->{Found} == 0, 'no-match reconciliation reports Found 0' );
    Assert( $NoMatchStats->{Changed} == 0, 'no-match reconciliation reports Changed 0' );
    Assert( $NoMatchStats->{Skipped} == 0, 'no-match reconciliation reports Skipped 0' );
    Assert( $NoMatchStats->{Failed} == 0, 'no-match reconciliation reports Failed 0' );
    Assert( !@{ $NoMatchStats->{Errors} }, 'no-match reconciliation reports no errors' );
    Assert( $TicketObject->{SearchCount} == 1, 'ReconcileTickets 1 searches tickets once' );
    Assert( $TicketObject->{LastSearch}->{CustomerUserLoginRaw} eq 'reconcile-nomatch@example.com', 'reconciliation searches by exact created login' );
    Assert( $TicketObject->{LastSearch}->{Limit} == 100_000, 'reconciliation uses native CustomerUserUpdate ticket search limit' );
    Assert( $TicketObject->{LastSearch}->{UserID} == 1, 'reconciliation search mirrors native system user search' );
    Assert( join( q{,}, @{ $TicketObject->{LastSearch}->{ArchiveFlags} } ) eq 'y,n', 'reconciliation includes archived and non-archived tickets' );
    Assert( !exists $TicketObject->{LastSearch}->{CustomerUserLogin}, 'reconciliation must not use fuzzy CustomerUserLogin search' );
    Assert( !( $TicketObject->{SetCount} || 0 ), 'no-match reconciliation must not update tickets' );

    $TicketObject->Reset();
    $TicketObject->{SearchResults}->{'reconcile-partial@example.com'} = [ 701, 702, 703 ];
    $TicketObject->{Tickets}->{701} = {
        TicketID       => 701,
        CustomerID     => 'second-customer',
        CustomerUserID => 'reconcile-partial@example.com',
    };
    $TicketObject->{Tickets}->{702} = {
        TicketID       => 702,
        CustomerID     => 'old-customer',
        CustomerUserID => 'reconcile-partial@example.com',
    };
    $TicketObject->{Tickets}->{703} = {
        TicketID       => 703,
        CustomerID     => 'old-customer',
        CustomerUserID => 'reconcile-partial@example.com',
    };
    $TicketObject->{FailSet}->{703} = 1;

    delete $CustomerUserObject->{LastAdd};
    my $PartialReconcileCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin        => 'api-user',
            Password         => 'api-auth-secret',
            FirstName        => 'Partial',
            LastName         => 'Reconcile',
            Login            => 'reconcile-partial@example.com',
            Email            => 'reconcile-partial@example.com',
            CustomerID       => 'second-customer',
            ReconcileTickets => 1,
        },
    );
    my $PartialStats = $PartialReconcileCreateResponse->{Data}->{ReconcileTickets};
    Assert( $PartialReconcileCreateResponse->{Data}->{Created}, 'partial reconciliation failure must keep Created 1' );
    Assert( $PartialStats->{Requested} == 1, 'partial reconciliation reports Requested 1' );
    Assert( $PartialStats->{Found} == 3, 'partial reconciliation reports all matched tickets' );
    Assert( $PartialStats->{Changed} == 1, 'partial reconciliation counts changed tickets' );
    Assert( $PartialStats->{Skipped} == 1, 'partial reconciliation counts already-correct tickets' );
    Assert( $PartialStats->{Failed} == 1, 'partial reconciliation counts failed ticket updates' );
    Assert(
        $PartialStats->{Found} == $PartialStats->{Changed} + $PartialStats->{Skipped} + $PartialStats->{Failed},
        'reconciliation stats keep Found equal to Changed plus Skipped plus Failed',
    );
    Assert( $PartialStats->{Errors}->[0]->{TicketID} == 703, 'partial reconciliation reports failed TicketID' );
    Assert( $TicketObject->{GetCount} == 3, 'partial reconciliation reads every matched ticket' );
    Assert( $TicketObject->{SetCount} == 2, 'partial reconciliation updates only mismatched tickets' );
    Assert( $TicketObject->{Tickets}->{702}->{CustomerID} eq 'second-customer', 'partial reconciliation updates mismatched CustomerID' );
    Assert( $TicketObject->{Tickets}->{702}->{CustomerUserID} eq 'reconcile-partial@example.com', 'partial reconciliation preserves CustomerUserID on changed ticket' );
    Assert( $TicketObject->{SetCalls}->[0]->{No} eq 'second-customer', 'TicketCustomerSet receives only target CustomerID as No' );
    Assert( $TicketObject->{SetCalls}->[0]->{UserID} == 2, 'TicketCustomerSet uses authenticated agent UserID for audit' );
    Assert( !exists $TicketObject->{SetCalls}->[0]->{User}, 'TicketCustomerSet must not receive User during create reconciliation' );
    Assert( !exists $TicketObject->{SetCalls}->[1]->{User}, 'failed TicketCustomerSet must also avoid User during create reconciliation' );

    delete $CustomerUserObject->{LastAdd};
    my $BodyPasswordCreateResponse = $CreateOperation->Run(
        Data => {
            Password   => 'customer-password',
            FirstName  => 'Body',
            LastName   => 'Password',
            Login      => 'body-password-create@example.com',
            Email      => 'body-password-create@example.com',
            CustomerID => 'second-customer',
        },
    );
    Assert( !$BodyPasswordCreateResponse->{Data}->{Created}, 'Create operation must reject visible body Password input' );
    Assert(
        scalar( grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{ $BodyPasswordCreateResponse->{Data}->{Errors} } ),
        'Create operation visible body Password must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'Create operation visible body Password must prevent CustomerUserAdd' );

    my $BodyUserPasswordCreateResponse = $CreateOperation->Run(
        Data => {
            UserLogin    => 'api-user',
            Password     => 'api-auth-secret',
            UserPassword => 'customer-password',
            FirstName    => 'Body',
            LastName     => 'UserPassword',
            Login        => 'body-userpassword-create@example.com',
            Email        => 'body-userpassword-create@example.com',
            CustomerID   => 'second-customer',
        },
    );
    Assert( !$BodyUserPasswordCreateResponse->{Data}->{Created}, 'Create operation must reject body UserPassword input even with auth Password present' );
    Assert(
        scalar( grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{ $BodyUserPasswordCreateResponse->{Data}->{Errors} } ),
        'Create operation body UserPassword must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastAdd}, 'Create operation body UserPassword must prevent CustomerUserAdd' );

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
            scalar( grep { $_ eq 'Customer user password could not be generated.' } @{$FailedPasswordErrors} ),
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
    Assert( $Created->{UserLogin} eq 'updated@example.com', 'valid create retains legacy UserLogin alias' );
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
        scalar( grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{$PasswordUpdateErrors} ),
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
        join( q{,}, sort keys %{ $RouteOnlyResponse->{Data}->{CustomerUser} } ) eq $LookupKeys,
        'update response must expose safe canonical fields and legacy aliases',
    );
    Assert( $RouteOnlyResponse->{Data}->{CustomerUser}->{LastName} eq 'RuntimePatched', 'update response must return actual updated user' );
    Assert( $RouteOnlyResponse->{Data}->{CustomerUser}->{UserLastname} eq 'RuntimePatched', 'update response must retain legacy UserLastname alias' );

    my $AuthPasswordUpdateResponse = $Operation->Run(
        CustomerUserLogin => 'existing@example.com',
        Data              => {
            UserLogin => 'api-user',
            Password  => 'api-auth-secret',
            LastName  => 'AuthPasswordPatched',
        },
    );
    Assert( $AuthPasswordUpdateResponse->{Data}->{Updated}, 'Update operation must allow GenericInterface auth Password in transport data' );
    Assert( !@{ $AuthPasswordUpdateResponse->{Data}->{Errors} }, 'Update operation auth Password must not produce supplied-password validation error' );
    Assert( $CustomerUserObject->{LastUpdate}->{ID} eq 'existing@example.com', 'Update operation auth Password must keep route CustomerUserLogin as update ID' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLastname} eq 'AuthPasswordPatched', 'Update operation auth Password must still apply intended body fields' );
    Assert( !exists $CustomerUserObject->{LastUpdate}->{UserPassword}, 'Update operation auth Password must not change customer password' );
    Assert(
        !$AuthPasswordUpdateResponse->{Data}->{CustomerUser}->{UserPassword}
            && !$AuthPasswordUpdateResponse->{Data}->{CustomerUser}->{Password},
        'Update operation auth Password response must not expose any password',
    );

    delete $CustomerUserObject->{LastUpdate};
    my $BodyPasswordUpdateResponse = $Operation->Run(
        CustomerUserLogin => 'existing@example.com',
        Data              => {
            Password => 'customer-password',
            LastName => 'BodyPasswordPatched',
        },
    );
    Assert( !$BodyPasswordUpdateResponse->{Data}->{Updated}, 'Update operation must reject visible body Password input' );
    Assert(
        scalar( grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{ $BodyPasswordUpdateResponse->{Data}->{Errors} } ),
        'Update operation visible body Password must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'Update operation visible body Password must prevent CustomerUserUpdate' );

    my $BodyUserPasswordUpdateResponse = $Operation->Run(
        CustomerUserLogin => 'existing@example.com',
        Data              => {
            UserLogin    => 'api-user',
            Password     => 'api-auth-secret',
            UserPassword => 'customer-password',
            LastName     => 'BodyUserPasswordPatched',
        },
    );
    Assert( !$BodyUserPasswordUpdateResponse->{Data}->{Updated}, 'Update operation must reject body UserPassword input even with auth Password present' );
    Assert(
        scalar( grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{ $BodyUserPasswordUpdateResponse->{Data}->{Errors} } ),
        'Update operation body UserPassword must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'Update operation body UserPassword must prevent CustomerUserUpdate' );

    my $MismatchResponse = $Operation->Run(
        CustomerUserLogin => 'existing@example.com',
        Data              => {
            CurrentLogin => 'other@example.com',
            LastName     => 'Mismatch',
        },
    );
    Assert( !$MismatchResponse->{Data}->{Updated}, 'mismatched route and body current login must not update' );
    Assert(
        scalar( grep { $_ eq 'CurrentLogin must match the route CustomerUserLogin.' } @{ $MismatchResponse->{Data}->{Errors} } ),
        'mismatched route and body current login must return validation error',
    );

    my ( $DuplicateUpdate, $DuplicateUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'duplicate@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateUpdate, 'duplicate target login update must fail' );
    Assert( scalar( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateUpdateErrors} ), 'duplicate active target login error must be present' );

    delete $CustomerUserObject->{LastUpdate};
    my ( $DuplicateDisabledLoginUpdate, $DuplicateDisabledLoginUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'disabled@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateDisabledLoginUpdate, 'duplicate disabled target login update must fail' );
    Assert( scalar( grep { $_ eq 'Login is already used by another customer user.' } @{$DuplicateDisabledLoginUpdateErrors} ), 'duplicate disabled target login error must be present' );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'duplicate disabled target login must prevent CustomerUserUpdate' );

    my ( $DuplicateActiveEmailUpdate, $DuplicateActiveEmailUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Email             => 'duplicate@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateActiveEmailUpdate, 'duplicate active target email update must fail' );
    Assert( scalar( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateActiveEmailUpdateErrors} ), 'duplicate active target email error must be present' );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'duplicate active target email must prevent CustomerUserUpdate' );

    my ( $DuplicateDisabledEmailUpdate, $DuplicateDisabledEmailUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Email             => 'disabled-collision@example.com',
        UserID            => 2,
    );
    Assert( !$DuplicateDisabledEmailUpdate, 'duplicate disabled target email update must fail' );
    Assert( scalar( grep { $_ eq 'Email is already used by another customer user.' } @{$DuplicateDisabledEmailUpdateErrors} ), 'duplicate disabled target email error must be present' );
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
    Assert( scalar( grep { $_ eq 'Customer user not found.' } @{$NotFoundUpdateErrors} ), 'missing customer update must return structured error' );

    my ( $Renamed, $RenameErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CustomerUserLogin => 'existing@example.com',
        Login             => 'renamed@example.com',
        CustomerID        => 'second-customer',
        UserID            => 2,
    );
    Assert( $CustomerUserObject->{LastUpdate}->{ID} eq 'existing@example.com', 'rename must use route login as ID' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLogin} eq 'renamed@example.com', 'update must support explicit login rename' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserFirstname} eq 'Existing', 'rename must preserve unspecified first name' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLastname} eq 'AuthPasswordPatched', 'rename must preserve prior last name' );
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
