package Kernel::GenericInterface::Operation::Ticket::PriorityList;

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

    my ( $AuthOK, $AuthError ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my %PriorityList   = $PriorityObject->PriorityList(
        Valid => 1,
    );

    my @TicketPriorities;

    for my $ID ( sort { $a <=> $b } keys %PriorityList ) {
        push @TicketPriorities, {
            ID      => 0 + $ID,
            Name    => $PriorityList{$ID} || q{},
            ValidID => 1,
        };
    }

    @TicketPriorities = sort {
        lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
            || ( $a->{ID} || 0 ) <=> ( $b->{ID} || 0 )
    } @TicketPriorities;

    return {
        Success => 1,
        Data    => {
            TicketPriorities => \@TicketPriorities,
        },
    };
}

1;
