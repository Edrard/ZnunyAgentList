package Kernel::GenericInterface::Operation::CustomerUser::Create;

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

    my ( $AuthOK, $AuthError, $UserID ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateWriteAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my %Input = map {
        $_ => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, $_ )
    } qw(FirstName LastName Login Email CustomerID);
    $Input{PasswordProvided}
        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserPasswordInputProvided( \%Param );

    my $ReconcileRequested = 0;
    if ( Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ParamExists( \%Param, 'ReconcileTickets' ) ) {
        my ( $ReconcileOK, $ReconcileValue ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->OptionalZeroOne(
            Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'ReconcileTickets' ),
        );

        if ( !$ReconcileOK ) {
            return {
                Success => 1,
                Data    => {
                    Created      => 0,
                    CustomerUser => undef,
                    Errors       => ['ReconcileTickets must be 0 or 1.'],
                },
            };
        }

        $ReconcileRequested = $ReconcileValue;
    }

    my ( $CustomerUser, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        %Input,
        UserID => $UserID,
    );

    my $ReconcileTickets;
    if ( $CustomerUser && $ReconcileRequested ) {
        $ReconcileTickets = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateTicketReconciliation(
            Login      => $CustomerUser->{Login},
            CustomerID => $CustomerUser->{CustomerID},
            UserID     => $UserID,
        );
    }

    my %Data = (
        Created      => $CustomerUser ? 1 : 0,
        CustomerUser => $CustomerUser,
        Errors       => $Errors || [],
    );
    $Data{ReconcileTickets} = $ReconcileTickets if $ReconcileTickets;

    return {
        Success => 1,
        Data    => \%Data,
    };
}

1;
