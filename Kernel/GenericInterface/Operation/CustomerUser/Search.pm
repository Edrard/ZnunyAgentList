package Kernel::GenericInterface::Operation::CustomerUser::Search;

use strict;
use warnings;

use parent qw(Kernel::GenericInterface::Operation::Common);

use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

our $ObjectManagerDisabled = 1;

sub new {
    return Kernel::GenericInterface::Operation::ZnunyAgentList::Common->New(@_);
}

sub Run {
    my ( $Self, %Param ) = @_;

    my ( $AuthOK, $AuthError ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my $RawSearch = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Search' );
    my $RawLimit  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Limit' );

    my $Search = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawSearch,
        100,
    );
    my $Limit = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Limit(
        $RawLimit,
        20,
        50,
    );

    if ( Kernel::GenericInterface::Operation::ZnunyAgentList::Common->MeaningfulSearchLength($Search) < 2 ) {
        return {
            Success => 1,
            Data    => {
                CustomerUsers => [],
                Warnings      => ['Search must contain at least 2 non-wildcard characters.'],
            },
        };
    }

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my %SearchResult = $CustomerUserObject->CustomerSearch(
        Search => $Search,
        Valid  => 1,
        Limit  => $Limit,
    );

    my @UserLogins = sort keys %SearchResult;

    my @CustomerUsers;
    for my $UserLogin ( sort { lc($a) cmp lc($b) } grep { defined $_ && $_ ne '' } @UserLogins ) {
        my %UserData = $CustomerUserObject->CustomerUserDataGet(
            User => $UserLogin,
        );

        next if !$UserData{UserLogin};

        push @CustomerUsers, Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserData(%UserData);
    }

    return {
        Success => 1,
        Data    => {
            CustomerUsers => \@CustomerUsers,
        },
    };
}

1;
