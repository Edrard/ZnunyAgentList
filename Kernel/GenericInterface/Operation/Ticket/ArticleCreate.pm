package Kernel::GenericInterface::Operation::Ticket::ArticleCreate;

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

    my @Warnings;
    my @Errors;

    my $TicketID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' ),
    );
    my $TicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketNumber' ),
        64,
    );
    my $Kind = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Kind' ),
        32,
    );
    my $Subject = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Subject' ),
        255,
    );
    my $Body = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Body' ),
        20000,
    );
    my $ContentType = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeContentType(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'ContentType' ),
    );

    push @Errors, 'TicketID or TicketNumber is required.' if !$TicketID && !$TicketNumber;
    push @Errors, 'Kind must be reply or internal_note.' if !Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ArticleKindData($Kind);
    push @Errors, 'Subject is required.' if $Subject eq q{};
    push @Errors, 'Body is required.'    if $Body eq q{};

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
                ArticleID => undef,
                Errors    => \@Errors,
                Warnings  => \@Warnings,
            },
        };
    }

    my $ArticleID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketArticleCreate(
        TicketID        => $Ticket->{TicketID},
        Kind            => $Kind,
        Subject         => $Subject,
        Body            => $Body,
        ContentType     => $ContentType,
        HistoryComment  => "%%$Subject",
        UserID          => $UserID,
    );

    if (!$ArticleID) {
        return {
            Success => 1,
            Data    => {
                TicketID     => $Ticket->{TicketID},
                TicketNumber => $Ticket->{TicketNumber},
                ArticleID    => undef,
                Kind         => $Kind,
                Errors       => ['Article could not be created.'],
                Warnings     => \@Warnings,
            },
        };
    }

    return {
        Success => 1,
        Data    => {
            TicketID     => $Ticket->{TicketID},
            TicketNumber => $Ticket->{TicketNumber},
            ArticleID    => $ArticleID,
            Kind         => $Kind,
            Created      => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->FormatLocalTime,
            Warnings     => \@Warnings,
        },
    };
}

1;
