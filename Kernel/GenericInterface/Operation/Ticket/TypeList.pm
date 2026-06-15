package Kernel::GenericInterface::Operation::Ticket::TypeList;

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

    my @Warnings;
    my @TicketTypes;

    my $TypeObject = eval { $Kernel::OM->Get('Kernel::System::Type') };
    if (!$TypeObject) {
        push @Warnings, 'Ticket type support is unavailable.';
    }
    else {
        my %TypeList = eval {
            $TypeObject->TypeList(
                Valid => 1,
            );
        };

        if ($@) {
            push @Warnings, 'Ticket type support is unavailable.';
            %TypeList = ();
        }

        for my $ID ( sort { $a <=> $b } keys %TypeList ) {
            push @TicketTypes, {
                ID      => 0 + $ID,
                Name    => $TypeList{$ID} || q{},
                ValidID => 1,
            };
        }

        @TicketTypes = sort {
            lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
                || ( $a->{ID} || 0 ) <=> ( $b->{ID} || 0 )
        } @TicketTypes;
    }

    return {
        Success => 1,
        Data    => {
            TicketTypes => \@TicketTypes,
            Warnings    => \@Warnings,
        },
    };
}

1;
