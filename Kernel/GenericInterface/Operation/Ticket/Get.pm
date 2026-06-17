package Kernel::GenericInterface::Operation::Ticket::Get;

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

    my ( $AuthOK, $AuthError, $UserID ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateReadAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my @Warnings;

    my $TicketID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' ),
    );
    my $TicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketNumber' ),
        64,
    );

    if ( $TicketID && $TicketNumber ) {
        push @Warnings, 'TicketNumber was ignored because TicketID was provided.';
    }

    if ( !$TicketID && !$TicketNumber ) {
        return {
            Success => 1,
            Data    => {
                Found    => 0,
                Ticket   => undef,
                Warnings => ['TicketID or TicketNumber is required.'],
            },
        };
    }

    my $Ticket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
        TicketID     => $TicketID,
        TicketNumber => $TicketNumber,
        UserID       => $UserID,
    );

    if ( !$Ticket ) {
        push @Warnings, 'Ticket not found.';

        return {
            Success => 1,
            Data    => {
                Found    => 0,
                Ticket   => undef,
                Warnings => \@Warnings,
            },
        };
    }

    return {
        Success => 1,
        Data    => {
            Found    => 1,
            Ticket   => $Ticket,
            Warnings => \@Warnings,
        },
    };
}

1;
