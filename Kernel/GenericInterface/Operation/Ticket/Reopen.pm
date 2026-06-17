package Kernel::GenericInterface::Operation::Ticket::Reopen;

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
    my $Reason = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Reason' ),
        4000,
    );
    my $State = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'State' ),
        100,
    ) || Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ConfigString(
        'ZnunyAgentList::ReopenState',
        'open',
        100,
    );
    my $Kind = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Kind' ),
        32,
    ) || 'internal_note';
    my $Subject = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Subject' ),
        255,
    ) || 'Ticket reopened by integration';
    my $Body = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Body' ),
        20000,
    ) || "Reason:\n$Reason";

    push @Errors, 'TicketID or TicketNumber is required.' if !$TicketID && !$TicketNumber;
    push @Errors, 'Reason is required.' if $Reason eq q{};
    push @Errors, 'Kind must be reply or internal_note.' if !Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ArticleKindData($Kind);

    my $StateData = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->StateData($State);
    if (!$StateData) {
        push @Errors, 'Target reopen state not found.';
    }
    elsif ( Kernel::GenericInterface::Operation::ZnunyAgentList::Common->IsClosedStateType( $StateData->{StateType} ) ) {
        push @Errors, 'Target reopen state must not have a closed state type.';
    }

    my $Ticket;
    if ( !@Errors ) {
        $Ticket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
            TicketID     => $TicketID,
            TicketNumber => $TicketNumber,
            UserID       => $UserID,
        );
        push @Errors, 'Ticket not found.' if !$Ticket;
    }

    if ( $Ticket && !Kernel::GenericInterface::Operation::ZnunyAgentList::Common->IsClosedStateType( $Ticket->{StateType} ) ) {
        push @Errors, 'Ticket is not closed.';
    }

    if (@Errors) {
        return {
            Success => 1,
            Data    => {
                Ticket   => $Ticket,
                Errors   => \@Errors,
                Warnings => \@Warnings,
            },
        };
    }

    my $ArticleID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketArticleCreate(
        TicketID       => $Ticket->{TicketID},
        Kind           => $Kind,
        Subject        => $Subject,
        Body           => $Body,
        ContentType    => 'text/plain; charset=utf8',
        HistoryComment => "%%$Subject",
        UserID         => $UserID,
    );
    if (!$ArticleID) {
        return {
            Success => 1,
            Data    => {
                Ticket   => $Ticket,
                Errors   => ['Reopen article could not be created.'],
                Warnings => \@Warnings,
            },
        };
    }

    my $StateUpdated = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketStateUpdate(
        TicketID => $Ticket->{TicketID},
        State    => $StateData->{State},
        UserID   => $UserID,
    );
    if (!$StateUpdated) {
        return {
            Success => 1,
            Data    => {
                Ticket    => $Ticket,
                ArticleID => $ArticleID,
                Errors    => ['Ticket state could not be changed.'],
                Warnings  => \@Warnings,
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
            Ticket    => $UpdatedTicket || $Ticket,
            ArticleID => $ArticleID,
            State     => $StateData->{State},
            Reason    => $Reason,
            Warnings  => \@Warnings,
        },
    };
}

1;
