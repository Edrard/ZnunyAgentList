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

    my $RawTicketID     = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' );
    my $RawTicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketNumber' );
    my $RawAllArticles  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'AllArticles' );

    my $TicketID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        $RawTicketID,
    );
    my $TicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawTicketNumber,
        64,
    );
    my $AllArticles = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Boolean($RawAllArticles);

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

    my $Data = {
        Found    => 1,
        Ticket   => $Ticket,
        Warnings => \@Warnings,
    };

    if ($AllArticles) {
        my ( $Articles, $ArticleWarnings ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketArticlesData(
            TicketID => $Ticket->{TicketID},
            UserID   => $UserID,
        );

        if ($Articles) {
            $Data->{Articles} = $Articles;
        }
        else {
            $Data->{Articles} = [];
            push @Warnings, @{$ArticleWarnings || []};
        }
    }

    return {
        Success => 1,
        Data    => $Data,
    };
}

1;
