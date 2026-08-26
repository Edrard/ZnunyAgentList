package Kernel::GenericInterface::Operation::CustomerCompany::List;

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

    my ( $AuthOK, $AuthError ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateReadAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my $RawSearch = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Search' );
    my $RawLimit  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Limit' );
    my $RawOffset = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Offset' );

    my ( $Companies, $Errors, $Meta ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
        Search => $RawSearch,
        Limit  => $RawLimit,
        Offset => $RawOffset,
    );
    $Meta ||= {};

    return {
        Success => 1,
        Data    => {
            CustomerCompanies => $Companies || [],
            Count             => 0 + ( $Meta->{Count} // scalar @{ $Companies || [] } ),
            TotalCount        => 0 + ( $Meta->{TotalCount} // scalar @{ $Companies || [] } ),
            Limit             => 0 + ( $Meta->{Limit} // 50 ),
            Offset            => 0 + ( $Meta->{Offset} // 0 ),
            HasMore           => 0 + ( $Meta->{HasMore} // 0 ),
            Errors            => $Errors || [],
        },
    };
}

1;
