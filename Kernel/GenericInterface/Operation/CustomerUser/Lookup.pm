package Kernel::GenericInterface::Operation::CustomerUser::Lookup;

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

    my $RawLogin = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Login' );
    my $RawEmail = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Email' );

    my ( $CustomerUser, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserLookupData(
        Login => $RawLogin,
        Email => $RawEmail,
    );

    if ( !$CustomerUser ) {
        return {
            Success => 1,
            Data    => {
                Found        => 0,
                CustomerUser => undef,
                Errors       => $Errors || [],
            },
        };
    }

    return {
        Success => 1,
        Data    => {
            Found        => 1,
            CustomerUser => $CustomerUser,
            Errors       => [],
        },
    };
}

1;
