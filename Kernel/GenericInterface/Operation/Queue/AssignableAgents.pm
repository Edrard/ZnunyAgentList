package Kernel::GenericInterface::Operation::Queue::AssignableAgents;

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

    my ( $AuthOK, $AuthError ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateReadAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my @Errors;
    my $RawQueueID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueID' );
    my $QueueID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt($RawQueueID);

    push @Errors, 'QueueID is required and must be a positive integer.' if !$QueueID;

    my ( $Queue, $Agents );
    if ( !@Errors ) {
        ( $Queue, $Agents ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AssignableAgents(
            QueueID => $QueueID,
        );
        push @Errors, 'Queue not found or is not valid.' if !$Queue;
    }

    return {
        Success => 1,
        Data    => {
            Success   => @Errors ? 0 : 1,
            QueueID   => $Queue ? $Queue->{QueueID} : ( $QueueID || 0 ),
            QueueName => $Queue ? $Queue->{QueueName} : q{},
            Agents    => $Agents || [],
            Errors    => \@Errors,
        },
    };
}

1;
