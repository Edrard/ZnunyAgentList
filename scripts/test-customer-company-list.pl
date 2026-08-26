#!/usr/bin/env perl

use strict;
use warnings;

use JSON::PP ();

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

use Kernel::GenericInterface::Operation::CustomerCompany::List;
use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

sub AssertKeys {
    my ( $HashRef, $Expected, $Message ) = @_;

    Assert(
        join( q{,}, sort keys %{$HashRef} ) eq join( q{,}, sort @{$Expected} ),
        $Message,
    );
}

sub AssertJsonNumber {
    my ( $Data, $Key, $Value, $Message ) = @_;

    my $JSON = JSON::PP->new->canonical->encode($Data);
    my $ExpectedFragment = q{"} . $Key . q{":} . $Value;

    Assert( index( $JSON, $ExpectedFragment ) >= 0, $Message );
    Assert( $JSON !~ m{"\Q$Key\E":"\Q$Value\E"}, "$Message must not be serialized as a string" );
}

sub CompanyIDs {
    my ($Companies) = @_;

    return join q{,}, map { $_->{CustomerID} } @{ $Companies || [] };
}

{
    package Test::Config;

    sub Get {
        my ( $Self, $Name ) = @_;

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

{
    package Test::CustomerCompany;

    sub new {
        my ( $Class, %Param ) = @_;

        return bless { %Param, Calls => [], GetCalls => [] }, $Class;
    }

    sub CustomerCompanyList {
        my ( $Self, %Param ) = @_;

        push @{ $Self->{Calls} }, { %Param };

        my @Rows = grep { !$_->{Deleted} } @{ $Self->{Rows} || [] };
        if ( $Param{Valid} ) {
            @Rows = grep { ( $_->{ValidID} || 0 ) == 1 } @Rows;
        }

        if ( defined $Param{Search} && $Param{Search} ne q{} ) {
            my $Search = lc $Param{Search};
            @Rows = grep {
                index( lc( $_->{CustomerID} || q{} ), $Search ) >= 0
                    || index( lc( $_->{CustomerCompanyName} || q{} ), $Search ) >= 0
            } @Rows;
        }

        @Rows = sort { $a->{CustomerID} cmp $b->{CustomerID} } @Rows;

        if ( $Param{Limit} && $Param{Limit} > 0 && @Rows > $Param{Limit} ) {
            @Rows = @Rows[ 0 .. $Param{Limit} - 1 ];
        }

        return map { $_->{CustomerID} => $_->{CustomerCompanyName} } @Rows;
    }

    sub CustomerCompanyGet {
        my ( $Self, %Param ) = @_;

        push @{ $Self->{GetCalls} }, { %Param };

        my ($Row) = grep { $_->{CustomerID} eq $Param{CustomerID} } @{ $Self->{Rows} || [] };
        return if !$Row || ( $Row->{ValidID} || 0 ) != 1;

        return %{$Row};
    }
}

{
    package Test::OM;

    sub new {
        my ( $Class, %Param ) = @_;

        return bless \%Param, $Class;
    }

    sub Get {
        my ( $Self, $Name ) = @_;

        return $Self->{$Name};
    }
}

my @Rows;
for my $Number ( reverse 1 .. 224 ) {
    push @Rows, {
        CustomerID          => sprintf( 'company-%03d', $Number ),
        CustomerCompanyName => sprintf( '%s Company %03d', $Number % 10 == 0 ? 'Special' : 'Example', $Number ),
        ValidID             => 1,
    };
}
push @Rows, (
    {
        CustomerID          => 'alpha-002',
        CustomerCompanyName => 'alpha duplicate',
        ValidID             => 1,
    },
    {
        CustomerID          => 'alpha-001',
        CustomerCompanyName => 'Alpha Duplicate',
        ValidID             => 1,
    },
    {
        CustomerID          => 'same-003',
        CustomerCompanyName => 'Same Name',
        ValidID             => 1,
    },
    {
        CustomerID          => 'same-001',
        CustomerCompanyName => 'Same Name',
        ValidID             => 1,
    },
    {
        CustomerID          => 'same-002',
        CustomerCompanyName => 'Same Name',
        ValidID             => 1,
    },
    {
        CustomerID          => 'empty-name',
        ValidID             => 1,
    },
);
push @Rows, {
    CustomerID          => 'invalid-company',
    CustomerCompanyName => 'Invalid Company',
    ValidID             => 2,
};

sub ExpectedRows {
    my ($Search) = @_;

    my @Expected = grep { ( $_->{ValidID} || 0 ) == 1 } @Rows;
    if ( defined $Search && $Search ne q{} ) {
        my $LowerSearch = lc $Search;
        @Expected = grep {
            index( lc( $_->{CustomerID} || q{} ), $LowerSearch ) >= 0
                || index( lc( $_->{CustomerCompanyName} || q{} ), $LowerSearch ) >= 0
        } @Expected;
    }

    return sort {
        lc( $a->{CustomerCompanyName} // q{} ) cmp lc( $b->{CustomerCompanyName} // q{} )
            || lc( $a->{CustomerID} // q{} ) cmp lc( $b->{CustomerID} // q{} )
            || ( $a->{CustomerCompanyName} // q{} ) cmp ( $b->{CustomerCompanyName} // q{} )
            || ( $a->{CustomerID} // q{} ) cmp ( $b->{CustomerID} // q{} )
    } @Expected;
}

my $CustomerCompanyObject = Test::CustomerCompany->new( Rows => \@Rows );
my $OM = Test::OM->new(
    'Kernel::Config'          => bless( {}, 'Test::Config' ),
    'Kernel::System::Group'   => bless( {}, 'Test::Group' ),
    'Kernel::System::CustomerCompany' => $CustomerCompanyObject,
);

sub RunOperation {
    my (%Param) = @_;

    local $Kernel::OM = $OM;
    my $Operation = Kernel::GenericInterface::Operation::CustomerCompany::List->new(
        DebuggerObject => 1,
        WebserviceID   => 1,
    );

    return $Operation->Run(%Param);
}

my @ExpectedAll = ExpectedRows();
my $DefaultResponse = RunOperation();
my $DefaultData = $DefaultResponse->{Data};

Assert( $DefaultResponse->{Success} == 1, 'default customer company list succeeds' );
AssertKeys( $DefaultResponse, [qw(Data Success)], 'final Run success response preserves top-level Success and Data keys' );
AssertKeys(
    $DefaultData,
    [qw(Count CustomerCompanies Errors HasMore Limit Offset TotalCount)],
    'final Run success Data adds only pagination keys to CustomerCompanies and Errors',
);
Assert( @{ $DefaultData->{CustomerCompanies} } == 50, 'default customer company list returns 50 rows' );
Assert( $DefaultData->{Count} == 50, 'default Count is page length' );
Assert( $DefaultData->{TotalCount} == scalar @ExpectedAll, 'default TotalCount includes all matching valid companies' );
Assert( $DefaultData->{Limit} == 50, 'default Limit is 50' );
Assert( $DefaultData->{Offset} == 0, 'default Offset is 0' );
Assert( $DefaultData->{HasMore} == 1, 'default HasMore is 1' );
Assert( !@{ $DefaultData->{Errors} }, 'default customer company list has no errors' );
Assert( $CustomerCompanyObject->{Calls}->[-1]->{Limit} == 0, 'native CustomerCompanyList is called with Limit 0 for full count before slicing' );
Assert( @{ $CustomerCompanyObject->{Calls} } == 1, 'default request calls CustomerCompanyList exactly once' );
Assert( @{ $CustomerCompanyObject->{GetCalls} } == 0, 'default request does not call CustomerCompanyGet per company' );
AssertKeys( $DefaultData->{CustomerCompanies}->[0], [qw(CustomerCompanyName CustomerID)], 'company list item exposes only CustomerID and CustomerCompanyName' );
Assert( $DefaultData->{CustomerCompanies}->[0]->{CustomerID} eq $ExpectedAll[0]->{CustomerID}, 'default page uses deterministic order before slicing' );
AssertJsonNumber( $DefaultData, 'Count', 50, 'Count serializes as JSON number' );
AssertJsonNumber( $DefaultData, 'TotalCount', scalar @ExpectedAll, 'TotalCount serializes as JSON number' );
AssertJsonNumber( $DefaultData, 'Limit', 50, 'Limit serializes as JSON number' );
AssertJsonNumber( $DefaultData, 'Offset', 0, 'Offset serializes as JSON number' );
AssertJsonNumber( $DefaultData, 'HasMore', 1, 'HasMore serializes as JSON number' );
Assert( $DefaultData->{HasMore} == 0 || $DefaultData->{HasMore} == 1, 'HasMore is an integer 0 or 1' );

my $StringZeroResponse = RunOperation( Data => { Limit => 50, Offset => '0' } );
my $StringZeroData = $StringZeroResponse->{Data};
Assert( $StringZeroResponse->{Success} == 1, 'query-style string Offset 0 succeeds' );
Assert( !@{ $StringZeroData->{Errors} }, 'query-style string Offset 0 has no errors' );
Assert( $StringZeroData->{Offset} == 0, 'query-style string Offset 0 returns numeric Offset 0' );
Assert( $StringZeroData->{Count} == $DefaultData->{Count}, 'query-style string Offset 0 Count matches omitted Offset' );
Assert( $StringZeroData->{TotalCount} == $DefaultData->{TotalCount}, 'query-style string Offset 0 TotalCount matches omitted Offset' );
Assert( $StringZeroData->{Limit} == $DefaultData->{Limit}, 'query-style string Offset 0 Limit matches omitted Offset' );
Assert( $StringZeroData->{HasMore} == $DefaultData->{HasMore}, 'query-style string Offset 0 HasMore matches omitted Offset' );
Assert(
    CompanyIDs( $StringZeroData->{CustomerCompanies} ) eq CompanyIDs( $DefaultData->{CustomerCompanies} ),
    'query-style string Offset 0 returns the same first page companies as omitted Offset',
);
AssertJsonNumber( $StringZeroData, 'Offset', 0, 'query-style string Offset 0 serializes Offset as JSON number 0' );

my $NumericZeroResponse = RunOperation( Data => { Limit => 50, Offset => 0 } );
Assert( !@{ $NumericZeroResponse->{Data}->{Errors} }, 'numeric Offset 0 has no errors' );
Assert(
    CompanyIDs( $NumericZeroResponse->{Data}->{CustomerCompanies} ) eq CompanyIDs( $DefaultData->{CustomerCompanies} ),
    'numeric Offset 0 returns the same first page companies as omitted Offset',
);

my $LimitResponse = RunOperation( Data => { Limit => 250 } );
Assert( $LimitResponse->{Data}->{Limit} == 100, 'Limit is capped at 100' );
Assert( @{ $LimitResponse->{Data}->{CustomerCompanies} } == 100, 'Limit 250 returns at most 100 rows' );

my @Combined;
for my $Offset ( 0, 100, 200 ) {
    my $Response = RunOperation( Data => { Limit => 100, Offset => $Offset } );
    my $Data = $Response->{Data};

    push @Combined, @{ $Data->{CustomerCompanies} };
    Assert( $Data->{TotalCount} == scalar @ExpectedAll, "TotalCount is stable for Offset $Offset" );
    Assert( $Data->{Offset} == $Offset, "Offset $Offset is reflected as JSON numeric data" );
    Assert( $Data->{Count} == ( $Offset == 200 ? scalar(@ExpectedAll) - 200 : 100 ), "Count is correct for Offset $Offset" );
    Assert( $Data->{HasMore} == ( $Offset == 200 ? 0 : 1 ), "HasMore is correct for Offset $Offset" );
}
Assert( @Combined == scalar @ExpectedAll, 'consecutive pages cover all valid companies without gaps' );
for my $Index ( 0 .. $#ExpectedAll ) {
    Assert(
        $Combined[$Index]->{CustomerID} eq $ExpectedAll[$Index]->{CustomerID},
        'consecutive pages preserve deterministic sorted order',
    );
}

my %SeenCompanyID;
for my $Company (@Combined) {
    Assert( !$SeenCompanyID{ $Company->{CustomerID} }++, 'consecutive pages contain no duplicate CustomerID values' );
}

my %ExpectedPosition = map { $ExpectedAll[$_]->{CustomerID} => $_ } 0 .. $#ExpectedAll;
Assert( $ExpectedPosition{'empty-name'} == 0, 'empty or missing company names sort safely as empty strings' );
Assert( $ExpectedPosition{'alpha-001'} < $ExpectedPosition{'alpha-002'}, 'case-insensitive duplicate names use CustomerID tie-breaker' );
Assert( $ExpectedPosition{'same-001'} < $ExpectedPosition{'same-002'} && $ExpectedPosition{'same-002'} < $ExpectedPosition{'same-003'}, 'identical names use CustomerID tie-breaker' );

my $DuplicateBoundaryOffset = $ExpectedPosition{'same-002'};
my $DuplicateBoundaryResponse = RunOperation( Data => { Limit => 2, Offset => $DuplicateBoundaryOffset } );
Assert(
    join( q{,}, map { $_->{CustomerID} } @{ $DuplicateBoundaryResponse->{Data}->{CustomerCompanies} } ) eq 'same-002,same-003',
    'page boundary inside identical-name group remains deterministic',
);

my $StringOneResponse = RunOperation( Data => { Limit => 50, Offset => '1' } );
Assert( $StringOneResponse->{Data}->{Offset} == 1, 'query-style string Offset 1 is accepted' );
Assert( $StringOneResponse->{Data}->{Count} == 50, 'query-style string Offset 1 returns a full page' );
Assert( !@{ $StringOneResponse->{Data}->{Errors} }, 'query-style string Offset 1 has no errors' );

my $StringFiftyResponse = RunOperation( Data => { Limit => 50, Offset => '50' } );
Assert( $StringFiftyResponse->{Data}->{Offset} == 50, 'query-style string Offset 50 is accepted' );
Assert( $StringFiftyResponse->{Data}->{Count} == 50, 'query-style string Offset 50 returns the second page' );
Assert( $StringFiftyResponse->{Data}->{HasMore} == 1, 'query-style string Offset 50 reports more data' );
Assert( !@{ $StringFiftyResponse->{Data}->{Errors} }, 'query-style string Offset 50 has no errors' );

my $BoundaryResponse = RunOperation( Data => { Limit => 100, Offset => scalar @ExpectedAll } );
Assert( @{ $BoundaryResponse->{Data}->{CustomerCompanies} } == 0, 'Offset equal to TotalCount returns an empty page' );
Assert( $BoundaryResponse->{Data}->{Count} == 0, 'boundary Count is 0' );
Assert( $BoundaryResponse->{Data}->{TotalCount} == scalar @ExpectedAll, 'boundary TotalCount is preserved' );
Assert( $BoundaryResponse->{Data}->{HasMore} == 0, 'boundary HasMore is 0' );
Assert( !@{ $BoundaryResponse->{Data}->{Errors} }, 'boundary page is not an error' );

my $BeyondResponse = RunOperation( Data => { Limit => 100, Offset => 500 } );
Assert( @{ $BeyondResponse->{Data}->{CustomerCompanies} } == 0, 'Offset greater than TotalCount returns an empty page' );
Assert( $BeyondResponse->{Data}->{TotalCount} == scalar @ExpectedAll, 'beyond page TotalCount is preserved' );
Assert( $BeyondResponse->{Data}->{HasMore} == 0, 'beyond page HasMore is 0' );
Assert( !@{ $BeyondResponse->{Data}->{Errors} }, 'beyond page is not an error' );

my @ExpectedSpecial = ExpectedRows('Special');
my $SearchResponse = RunOperation( Data => { Search => 'Special', Limit => 10, Offset => 10 } );
Assert( $SearchResponse->{Data}->{TotalCount} == scalar @ExpectedSpecial, 'Search is applied before count and pagination' );
Assert( $SearchResponse->{Data}->{Count} == 10, 'searched middle page Count is correct' );
Assert( $SearchResponse->{Data}->{CustomerCompanies}->[0]->{CustomerID} eq $ExpectedSpecial[10]->{CustomerID}, 'searched page starts at sorted Offset' );
Assert( $SearchResponse->{Data}->{HasMore} == 1, 'searched middle page HasMore is 1' );

my $SearchFinalResponse = RunOperation( Data => { Search => 'Special', Limit => 10, Offset => 20 } );
Assert( $SearchFinalResponse->{Data}->{Count} == scalar(@ExpectedSpecial) - 20, 'searched final partial page Count is correct' );
Assert( $SearchFinalResponse->{Data}->{HasMore} == 0, 'searched final partial page HasMore is 0' );

for my $BadOffset ( -1, '+1', ' ', '1.5', '1e2', '10abc', '999999999999999999999999', '2147483648' ) {
    my $BadResponse = RunOperation( Data => { Offset => $BadOffset } );
    Assert( $BadResponse->{Success} == 1, "bad Offset $BadOffset preserves business-error success envelope" );
    Assert( @{ $BadResponse->{Data}->{CustomerCompanies} } == 0, "bad Offset $BadOffset returns no companies" );
    Assert( $BadResponse->{Data}->{Errors}->[0] eq 'Offset must be a non-negative integer no larger than 2147483647.', "bad Offset $BadOffset returns structured error" );
}

my $MaxOffsetResponse = RunOperation( Data => { Offset => 2147483647 } );
Assert( $MaxOffsetResponse->{Data}->{Offset} == 2147483647, 'maximum documented Offset is accepted' );
Assert( @{ $MaxOffsetResponse->{Data}->{CustomerCompanies} } == 0, 'maximum documented Offset returns empty page when beyond TotalCount' );
Assert( !@{ $MaxOffsetResponse->{Data}->{Errors} }, 'maximum documented Offset is not an error' );

my ( $RefSearchCompanies, $RefSearchErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
    Search => ['example'],
);
Assert( !@{$RefSearchCompanies}, 'ref-valued Search is rejected' );
Assert( $RefSearchErrors->[0] eq 'Search must be a scalar string.', 'ref-valued Search returns safe error' );

my ( $RefLimitCompanies, $RefLimitErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
    Limit => { value => 50 },
);
Assert( !@{$RefLimitCompanies}, 'ref-valued Limit is rejected' );
Assert( $RefLimitErrors->[0] eq 'Limit must be a scalar integer.', 'ref-valued Limit returns safe error' );

my ( $RefOffsetCompanies, $RefOffsetErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
    Offset => [0],
);
Assert( !@{$RefOffsetCompanies}, 'ref-valued Offset is rejected' );
Assert( $RefOffsetErrors->[0] eq 'Offset must be a scalar integer.', 'ref-valued Offset returns safe error' );

{
    package Test::GroupDenied;

    sub PermissionUserGet {
        return;
    }
}

my $DeniedOM = Test::OM->new(
    'Kernel::Config'          => bless( {}, 'Test::Config' ),
    'Kernel::System::Group'   => bless( {}, 'Test::GroupDenied' ),
    'Kernel::System::CustomerCompany' => $CustomerCompanyObject,
);

{
    local $Kernel::OM = $DeniedOM;
    my $Operation = Kernel::GenericInterface::Operation::CustomerCompany::List->new(
        DebuggerObject => 1,
        WebserviceID   => 1,
    );
    my $DeniedResponse = $Operation->Run();
    Assert( exists $DeniedResponse->{Error}, 'authorization failure uses GenericInterface ReturnError convention' );
    Assert( $DeniedResponse->{Error}->{ErrorCode} eq 'ZnunyAgentList.AuthFail', 'authorization failure returns auth error code' );
}

print "PASS: customer company list pagination regression checks\n";
