package Kernel::GenericInterface::Operation::Ticket::Search;

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
    my %SearchParam = (
        Result     => 'ARRAY',
        Permission => 'ro',
        UserID     => $UserID,
    );
    my $HasFilter = 0;

    my $QueueID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueID' ),
    );
    if ($QueueID) {
        $SearchParam{QueueIDs} = [$QueueID];
        $HasFilter = 1;
    }

    my $Queue = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Queue' ),
        255,
    );
    if ($Queue) {
        $SearchParam{Queues} = [$Queue];
        $HasFilter = 1;
    }

    my $StateID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'StateID' ),
    );
    if ($StateID) {
        $SearchParam{StateIDs} = [$StateID];
        $HasFilter = 1;
    }

    my $State = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'State' ),
        100,
    );
    if ($State) {
        $SearchParam{States} = [$State];
        $HasFilter = 1;
    }

    my $StateType = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'StateType' ),
        100,
    );
    if ($StateType) {
        $SearchParam{StateType} = [$StateType];
        $HasFilter = 1;
    }

    my $OwnerID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'OwnerID' ),
    );
    if ($OwnerID) {
        $SearchParam{OwnerIDs} = [$OwnerID];
        $HasFilter = 1;
    }

    my $Owner = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Owner' ),
        100,
    );
    if ($Owner) {
        $SearchParam{Owner} = $Owner;
        $HasFilter = 1;
    }

    my $CustomerUser = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUser' ),
        255,
    );
    my $CustomerUserID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUserID' ),
        255,
    );
    my $CustomerUserLogin = $CustomerUser || $CustomerUserID;
    if ($CustomerUserLogin) {
        $SearchParam{CustomerUserLogin} = $CustomerUserLogin;
        $HasFilter = 1;
    }

    my $TicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketNumber' ),
        64,
    );
    if ($TicketNumber) {
        $SearchParam{TicketNumber} = $TicketNumber;
        $HasFilter = 1;
    }

    my $Title = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Title' ),
        255,
    );
    if ($Title) {
        $SearchParam{Title} = $Title;
        $HasFilter = 1;
    }

    my $Search = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Search' ),
        255,
    );
    if ($Search) {
        if ( Kernel::GenericInterface::Operation::ZnunyAgentList::Common->MeaningfulSearchLength($Search) >= 2 ) {
            $SearchParam{FullTextIndex} = $Search;
            $HasFilter = 1;
        }
        else {
            push @Warnings, 'Search must contain at least 2 non-wildcard characters.';
        }
    }

    for my $DateFilter (
        [ 'CreatedFrom', 'TicketCreateTimeNewerDate' ],
        [ 'CreatedTo',   'TicketCreateTimeOlderDate' ],
        [ 'ChangedFrom', 'TicketChangeTimeNewerDate' ],
        [ 'ChangedTo',   'TicketChangeTimeOlderDate' ],
        )
    {
        my ( $InputName, $SearchName ) = @{$DateFilter};
        my $Date = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeDate(
            Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, $InputName ),
        );

        if ($Date) {
            $SearchParam{$SearchName} = $Date;
            $HasFilter = 1;
        }
        elsif ( defined Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, $InputName ) ) {
            push @Warnings, "$InputName must use YYYY-MM-DD or YYYY-MM-DD HH:MM:SS.";
        }
    }

    my $Limit = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SearchLimit(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Limit' ),
    );
    my $Offset = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SearchOffset(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Offset' ),
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Page' ),
        $Limit,
    );
    if ( $Offset > 1000 ) {
        $Offset = 1000;
        push @Warnings, 'Offset is capped at 1000.';
    }
    my $SortBy = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SortBy(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'SortBy' ),
    );
    my $SortDirection = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SortDirection(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'SortDirection' ),
    );

    if ( !$HasFilter ) {
        push @Warnings, 'At least one search filter is required.';

        return {
            Success => 1,
            Data    => {
                Tickets       => [],
                Count         => 0,
                Limit         => $Limit,
                Offset        => 0,
                SortBy        => $SortBy,
                SortDirection => $SortDirection,
                Warnings      => \@Warnings,
            },
        };
    }

    $SearchParam{SortBy}  = $SortBy;
    $SearchParam{OrderBy} = $SortDirection;
    $SearchParam{Limit}   = $Offset + $Limit;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my @TicketIDs    = eval { $TicketObject->TicketSearch(%SearchParam) };

    if ($@) {
        return {
            Success => 1,
            Data    => {
                Tickets  => [],
                Count    => 0,
                Limit    => $Limit,
                Offset   => $Offset,
                Warnings => ['Ticket search failed.'],
            },
        };
    }

    if ($Offset) {
        @TicketIDs = splice @TicketIDs, $Offset;
    }

    if ( @TicketIDs > $Limit ) {
        @TicketIDs = @TicketIDs[ 0 .. $Limit - 1 ];
    }

    my @Tickets;
    for my $TicketID (@TicketIDs) {
        my $Ticket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
            TicketID => $TicketID,
            UserID   => $UserID,
        );
        push @Tickets, $Ticket if $Ticket;
    }

    return {
        Success => 1,
        Data    => {
            Tickets       => \@Tickets,
            Count         => 0 + scalar @Tickets,
            Limit         => $Limit,
            Offset        => $Offset,
            SortBy        => $SortBy,
            SortDirection => $SortDirection,
            Warnings      => \@Warnings,
        },
    };
}

1;
