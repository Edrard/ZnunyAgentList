package Kernel::GenericInterface::Operation::Ticket::MoveAssignValidate;

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

    my $RawTicketID  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' );
    my $RawQueueID   = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueID' );
    my $RawQueueName = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueName' );
    my $RawOwnerID   = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'OwnerID' );
    my $RawOwnerLogin = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'OwnerLogin' );
    my $RawCustomerUserID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUserID' );
    my $RawCustomerID     = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerID' );
    my $RawNote           = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Note' );

    my $Validation = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->MoveAssignValidation(
        TicketID  => $RawTicketID,
        QueueID   => $RawQueueID,
        QueueName => $RawQueueName,
        OwnerID   => $RawOwnerID,
        OwnerLogin => $RawOwnerLogin,
        CustomerUserID => $RawCustomerUserID,
        CustomerID     => $RawCustomerID,
        Note      => $RawNote,
        UserID    => $UserID,
    );

    return {
        Success => 1,
        Data    => {
            Valid        => $Validation->{Valid},
            RequiredNote => $Validation->{RequiredNote},
            CustomerChanged => $Validation->{CustomerChanged},
            Current      => $Validation->{Current},
            Target       => $Validation->{Target},
            Errors       => $Validation->{Errors},
            Warnings     => $Validation->{Warnings},
        },
    };
}

1;
