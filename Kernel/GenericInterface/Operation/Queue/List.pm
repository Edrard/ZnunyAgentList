package Kernel::GenericInterface::Operation::Queue::List;

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

    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my %QueueList   = $QueueObject->QueueList( Valid => 1 );

    my @Queues;

    QUEUEID:
    for my $QueueID ( sort { $a <=> $b } keys %QueueList ) {
        my $QueueName = $QueueList{$QueueID};

        next QUEUEID if !$QueueID || !$QueueName;

        push @Queues, {
            QueueID  => 0 + $QueueID,
            Name     => $QueueName,
            FullName => $QueueName,
            ValidID  => 1,
        };
    }

    @Queues = sort {
        lc( $a->{FullName} // q{} ) cmp lc( $b->{FullName} // q{} )
            || lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
            || ( $a->{QueueID} || 0 ) <=> ( $b->{QueueID} || 0 )
    } @Queues;

    return {
        Success => 1,
        Data    => {
            Queues => \@Queues,
        },
    };
}

1;
