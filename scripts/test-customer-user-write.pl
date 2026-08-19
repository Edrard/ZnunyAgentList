#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    my $ScriptDir = $0;
    $ScriptDir =~ s{\\}{/}g;
    $ScriptDir =~ s{/[^/]*\z}{};
    unshift @INC, "$ScriptDir/..";
}

use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

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

        return (
            UserLogin      => 'existing@example.com',
            UserCustomerID => 'example-customer',
            UserFirstname  => 'Existing',
            UserLastname   => 'Customer',
            UserEmail      => 'existing@example.com',
        ) if lc $Param{User} eq 'existing@example.com';

        return (
            UserLogin      => 'updated@example.com',
            UserCustomerID => 'second-customer',
            UserFirstname  => 'Updated',
            UserLastname   => 'Customer',
            UserEmail      => 'updated@example.com',
        ) if lc $Param{User} eq 'updated@example.com' && ( $Self->{LastAdd} || $Self->{LastUpdate} );

        return;
    }

    sub CustomerSearch {
        my ( $Self, %Param ) = @_;

        return ( 'existing@example.com' => 'Existing Customer' )
            if lc( $Param{PostMasterSearch} || q{} ) eq 'existing@example.com';

        return;
    }

    sub CustomerUserAdd {
        my ( $Self, %Param ) = @_;

        $Self->{LastAdd} = { %Param };
        return 1;
    }

    sub CustomerUserUpdate {
        my ( $Self, %Param ) = @_;

        $Self->{LastUpdate} = { %Param };
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
    package Test::OM;

    sub Get {
        my ( $Self, $Name ) = @_;

        return $Self->{$Name};
    }
}

my $CustomerUserObject = bless {}, 'Test::CustomerUser';
my $OM = bless {
    'Kernel::System::CustomerCompany' => bless( {}, 'Test::CustomerCompany' ),
    'Kernel::System::CustomerUser'    => $CustomerUserObject,
}, 'Test::OM';

{
    local $Kernel::OM = $OM;

    my ( $ByLogin, $ByLoginErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Login => 'existing@example.com',
    );
    Assert( $ByLogin->{UserLogin} eq 'existing@example.com', 'lookup by login must be exact' );
    Assert( !@{$ByLoginErrors}, 'lookup by login must not return errors' );

    my ( $ByEmail, $ByEmailErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Email => 'existing@example.com',
    );
    Assert( $ByEmail->{UserEmail} eq 'existing@example.com', 'lookup by email must cross-check exact email' );
    Assert( !@{$ByEmailErrors}, 'lookup by email must not return errors' );

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
    Assert( grep { $_ eq 'Customer user login already exists.' } @{$DuplicateErrors}, 'duplicate login error must be present' );

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
    Assert( !@{$CreateErrors}, 'valid create must not return errors' );

    delete $CustomerUserObject->{LastAdd};

    my ( $PasswordUpdate, $PasswordUpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CurrentLogin     => 'existing@example.com',
        CustomerID       => 'second-customer',
        UserID           => 2,
        PasswordProvided => 1,
    );
    Assert( !$PasswordUpdate, 'update must reject supplied password input' );
    Assert(
        grep { $_ eq 'Password input is not supported. Use the normal password reset workflow.' } @{$PasswordUpdateErrors},
        'update must return safe supplied-password validation error',
    );
    Assert( !exists $CustomerUserObject->{LastUpdate}, 'update with supplied password must not call CustomerUserUpdate' );

    my ( $Updated, $UpdateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        CurrentLogin => 'existing@example.com',
        Login        => 'updated@example.com',
        CustomerID   => 'second-customer',
        UserID       => 2,
    );
    Assert( $CustomerUserObject->{LastUpdate}->{ID} eq 'existing@example.com', 'update must use CurrentLogin as ID' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLogin} eq 'updated@example.com', 'update must support explicit login rename' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserFirstname} eq 'Existing', 'update must preserve unspecified first name' );
    Assert( $CustomerUserObject->{LastUpdate}->{UserLastname} eq 'Customer', 'update must preserve unspecified last name' );
    Assert( !exists $CustomerUserObject->{LastUpdate}->{UserPassword}, 'omitted password must remain unchanged' );
    Assert( !$Updated->{UserPassword} && !$Updated->{Password}, 'update response must not return password' );
    Assert( !@{$UpdateErrors}, 'valid update must not return errors' );

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
