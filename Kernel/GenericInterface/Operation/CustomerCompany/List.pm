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

    my ( $Companies, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerCompanyListData(
        Search => $RawSearch,
        Limit  => $RawLimit,
    );

    return {
        Success => 1,
        Data    => {
            CustomerCompanies => $Companies || [],
            Errors            => $Errors || [],
        },
    };
}

1;
