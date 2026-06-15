package Kernel::GenericInterface::Operation::Ticket::StateList;

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

    my ( $AuthOK, $AuthError, $UserID ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my $StateObject = $Kernel::OM->Get('Kernel::System::State');
    my %StateList   = $StateObject->StateList(
        UserID => $UserID,
        Valid  => 1,
    );

    my @TicketStates;

    for my $ID ( sort { $a <=> $b } keys %StateList ) {
        push @TicketStates, {
            ID      => 0 + $ID,
            Name    => $StateList{$ID} || q{},
            ValidID => 1,
        };
    }

    @TicketStates = sort {
        lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
            || ( $a->{ID} || 0 ) <=> ( $b->{ID} || 0 )
    } @TicketStates;

    return {
        Success => 1,
        Data    => {
            TicketStates => \@TicketStates,
        },
    };
}

1;
