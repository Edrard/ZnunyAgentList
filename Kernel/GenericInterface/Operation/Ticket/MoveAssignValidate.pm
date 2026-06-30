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

    my $Validation = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->MoveAssignValidation(
        TicketID  => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' ),
        QueueID   => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueID' ),
        QueueName => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueName' ),
        OwnerID   => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'OwnerID' ),
        UserLogin => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'UserLogin' ),
        Note      => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Note' ),
        UserID    => $UserID,
    );

    return {
        Success => 1,
        Data    => {
            Valid        => $Validation->{Valid},
            RequiredNote => $Validation->{RequiredNote},
            Current      => $Validation->{Current},
            Target       => $Validation->{Target},
            Errors       => $Validation->{Errors},
            Warnings     => $Validation->{Warnings},
        },
    };
}

1;
