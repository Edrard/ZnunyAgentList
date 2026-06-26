package Kernel::GenericInterface::Operation::Ticket::Unlock;

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

    my @Errors;
    my @Warnings;

    my $TicketID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' ),
    );
    my $TicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketNumber' ),
        64,
    );

    push @Errors, 'TicketID or TicketNumber is required.' if !$TicketID && !$TicketNumber;

    my $Ticket;
    if ( !@Errors ) {
        $Ticket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
            TicketID     => $TicketID,
            TicketNumber => $TicketNumber,
            UserID       => $UserID,
        );
        push @Errors, 'Ticket not found.' if !$Ticket;
    }

    if (@Errors) {
        return {
            Success => 1,
            Data    => {
                Ticket   => undef,
                Errors   => \@Errors,
                Warnings => \@Warnings,
            },
        };
    }

    my $LockUpdated = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLockUpdate(
        TicketID => $Ticket->{TicketID},
        Lock     => 'unlock',
        UserID   => $UserID,
    );
    if (!$LockUpdated) {
        return {
            Success => 1,
            Data    => {
                Ticket   => $Ticket,
                Errors   => ['Ticket lock could not be changed.'],
                Warnings => \@Warnings,
            },
        };
    }

    my $UpdatedTicket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
        TicketID => $Ticket->{TicketID},
        UserID   => $UserID,
    );

    return {
        Success => 1,
        Data    => {
            Ticket   => $UpdatedTicket || $Ticket,
            Warnings => \@Warnings,
        },
    };
}

1;
