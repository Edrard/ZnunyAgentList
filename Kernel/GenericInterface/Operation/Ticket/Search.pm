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
    my $HasFilter          = 0;
    my $InvalidStateFilter = 0;

    my $RawQueueID        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueID' );
    my $RawQueue          = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Queue' );
    my $RawStateID        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'StateID' );
    my $RawState          = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'State' );
    my $RawStateType      = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'StateType' );
    my $RawOwnerID        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'OwnerID' );
    my $RawOwner          = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Owner' );
    my $RawCustomerUser   = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUser' );
    my $RawCustomerUserID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUserID' );
    my $RawTicketNumber   = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketNumber' );
    my $RawTitle          = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Title' );
    my $RawSearch         = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Search' );
    my $RawLimit          = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Limit' );
    my $RawOffset         = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Offset' );
    my $RawPage           = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Page' );
    my $RawSortBy         = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'SortBy' );
    my $RawSortDirection  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'SortDirection' );

    my $QueueID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        $RawQueueID,
    );
    if ($QueueID) {
        $SearchParam{QueueIDs} = [$QueueID];
        $HasFilter = 1;
    }

    my $Queue = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawQueue,
        255,
    );
    if ($Queue) {
        $SearchParam{Queues} = [$Queue];
        $HasFilter = 1;
    }

    my $StateID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        $RawStateID,
    );
    if ($StateID) {
        $SearchParam{StateIDs} = [$StateID];
        $HasFilter = 1;
    }

    my $State = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawState,
        100,
    );
    if ($State) {
        $HasFilter = 1;

        my $StateObject = eval { $Kernel::OM->Get('Kernel::System::State') };
        my $ResolvedStateID = $StateObject
            ? eval { $StateObject->StateLookup( State => $State ) }
            : undef;

        if ($ResolvedStateID) {
            $SearchParam{StateIDs} ||= [];
            push @{ $SearchParam{StateIDs} }, 0 + $ResolvedStateID;
        }
        else {
            $InvalidStateFilter = 1;
            push @Warnings, 'State was not found.';
        }
    }

    my $StateType = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawStateType,
        255,
    );
    if ($StateType) {
        $HasFilter = 1;

        my %SeenStateType;
        my @StateTypes = grep { $_ ne q{} && !$SeenStateType{$_}++ }
            map {
                Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
                    $_,
                    100,
                )
            }
            split /,/, $StateType;

        my $StateObject = eval { $Kernel::OM->Get('Kernel::System::State') };
        my @StateTypeIDs;

        for my $CurrentStateType (@StateTypes) {
            my $StateTypeID = $StateObject
                ? eval { $StateObject->StateTypeLookup( StateType => $CurrentStateType ) }
                : undef;

            if (!$StateTypeID) {
                $InvalidStateFilter = 1;
                last;
            }

            push @StateTypeIDs, 0 + $StateTypeID;
        }

        if ( @StateTypeIDs == @StateTypes && @StateTypeIDs ) {
            $SearchParam{StateTypeIDs} = \@StateTypeIDs;
        }
        else {
            $InvalidStateFilter = 1;
            push @Warnings, 'StateType was not found.';
        }
    }

    my $OwnerID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        $RawOwnerID,
    );
    if ($OwnerID) {
        $SearchParam{OwnerIDs} = [$OwnerID];
        $HasFilter = 1;
    }

    my $Owner = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawOwner,
        100,
    );
    if ($Owner) {
        $SearchParam{Owner} = $Owner;
        $HasFilter = 1;
    }

    my $CustomerUser = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawCustomerUser,
        255,
    );
    my $CustomerUserID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawCustomerUserID,
        255,
    );
    my $CustomerUserLogin = $CustomerUser || $CustomerUserID;
    if ($CustomerUserLogin) {
        $SearchParam{CustomerUserLogin} = $CustomerUserLogin;
        $HasFilter = 1;
    }

    my $TicketNumber = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawTicketNumber,
        64,
    );
    if ($TicketNumber) {
        $SearchParam{TicketNumber} = $TicketNumber;
        $HasFilter = 1;
    }

    my $Title = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawTitle,
        255,
    );
    if ($Title) {
        $SearchParam{Title} = $Title;
        $HasFilter = 1;
    }

    my $Search = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawSearch,
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
        my $RawDate = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, $InputName );
        my $Date = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeDate(
            $RawDate,
        );

        if ($Date) {
            $SearchParam{$SearchName} = $Date;
            $HasFilter = 1;
        }
        elsif ( defined $RawDate ) {
            push @Warnings, "$InputName must use YYYY-MM-DD or YYYY-MM-DD HH:MM:SS.";
        }
    }

    my $Limit = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SearchLimit(
        $RawLimit,
    );
    my $Offset = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SearchOffset(
        $RawOffset,
        $RawPage,
        $Limit,
    );
    if ( $Offset > 1000 ) {
        $Offset = 1000;
        push @Warnings, 'Offset is capped at 1000.';
    }
    my $SortBy = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SortBy(
        $RawSortBy,
    );
    my $SortDirection = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SortDirection(
        $RawSortDirection,
    );

    if ( !$HasFilter ) {
        my @NoFilterWarnings = ( @Warnings, 'At least one search filter is required.' );

        return {
            Success => 1,
            Data    => {
                Tickets       => [],
                Count         => 0,
                Limit         => $Limit,
                Offset        => 0,
                SortBy        => $SortBy,
                SortDirection => $SortDirection,
                Warnings      => \@NoFilterWarnings,
            },
        };
    }

    if ($TicketNumber) {
        my $Ticket = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketLookup(
            TicketNumber => $TicketNumber,
            UserID       => $UserID,
        );
        my @Tickets = $Ticket ? ($Ticket) : ();

        return {
            Success => 1,
            Data    => {
                Tickets       => \@Tickets,
                Count         => 0 + scalar @Tickets,
                Limit         => $Limit,
                Offset        => 0,
                SortBy        => $SortBy,
                SortDirection => $SortDirection,
                Warnings      => \@Warnings,
            },
        };
    }

    if ($InvalidStateFilter) {
        return {
            Success => 1,
            Data    => {
                Tickets       => [],
                Count         => 0,
                Limit         => $Limit,
                Offset        => $Offset,
                SortBy        => $SortBy,
                SortDirection => $SortDirection,
                Warnings      => \@Warnings,
            },
        };
    }

    $SearchParam{SortBy}  = $SortBy;
    $SearchParam{OrderBy} = $SortDirection eq 'ASC' ? 'Up' : 'Down';
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
