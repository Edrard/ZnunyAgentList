package Kernel::GenericInterface::Operation::Ticket::MoveAssign;

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

    my $Ticket = $Validation->{Ticket} || {};
    my $Response = {
        Success       => 0,
        TicketID      => $Ticket->{TicketID} || 0,
        TicketNumber  => $Ticket->{TicketNumber} // q{},
        QueueChanged  => 0,
        OwnerChanged  => 0,
        NoteCreated   => 0,
        Before        => $Validation->{Current},
        After         => $Validation->{Current},
        Errors        => [ @{ $Validation->{Errors} || [] } ],
        Warnings      => [ @{ $Validation->{Warnings} || [] } ],
    };

    if ( !$Validation->{Valid} ) {
        return {
            Success => 1,
            Data    => $Response,
        };
    }

    if ( $Validation->{QueueChanged} ) {
        my $QueueUpdated = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketQueueUpdate(
            TicketID => $Ticket->{TicketID},
            QueueID  => $Validation->{Target}->{QueueID},
            UserID   => $UserID,
        );
        if ( !$QueueUpdated ) {
            push @{ $Response->{Errors} }, 'Ticket queue could not be changed.';
            return {
                Success => 1,
                Data    => $Response,
            };
        }
        $Response->{QueueChanged} = 1;
    }

    if ( $Validation->{OwnerChanged} ) {
        my $OwnerUpdated = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketOwnerUpdate(
            TicketID => $Ticket->{TicketID},
            OwnerID  => $Validation->{Target}->{OwnerID},
            Comment  => $Validation->{Note},
            UserID   => $UserID,
        );
        if ( !$OwnerUpdated ) {
            push @{ $Response->{Errors} }, 'Ticket owner could not be changed.';
        }
        else {
            $Response->{OwnerChanged} = 1;
        }
    }

    if ( $Validation->{QueueChanged} && !$Validation->{OwnerChanged} && $Validation->{Note} ne q{} ) {
        my $ArticleID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketArticleCreate(
            TicketID       => $Ticket->{TicketID},
            Kind           => 'internal_note',
            Subject        => 'Ticket queue changed',
            Body           => $Validation->{Note},
            ContentType    => 'text/plain; charset=utf8',
            HistoryComment => 'Controlled queue move note',
            UserID         => $UserID,
        );
        if (!$ArticleID) {
            push @{ $Response->{Errors} }, 'Queue was changed, but the internal note could not be created.';
        }
        else {
            $Response->{NoteCreated} = 1;
        }
    }

    my $UpdatedTicket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
        TicketID => $Ticket->{TicketID},
        UserID   => $UserID,
    );
    if ($UpdatedTicket) {
        $Response->{After} = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketAssignmentSnapshot(
            Ticket => $UpdatedTicket,
        );
    }

    $Response->{Success} = @{ $Response->{Errors} } ? 0 : 1;

    return {
        Success => 1,
        Data    => $Response,
    };
}

1;
