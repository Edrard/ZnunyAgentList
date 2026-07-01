package Kernel::GenericInterface::Operation::User::AssignableQueues;

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
    my $RawUserID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'UserID' );
    my $UserID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt($RawUserID);

    push @Errors, 'UserID is required and must be a positive integer.' if !$UserID;

    my ( $Agent, $Queues );
    if ( !@Errors ) {
        ( $Agent, $Queues ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AssignableQueues(
            UserID => $UserID,
        );
        push @Errors, 'Agent not found or is not active.' if !$Agent;
    }

    return {
        Success => 1,
        Data    => {
            Success      => @Errors ? 0 : 1,
            UserID       => $Agent ? $Agent->{UserID} : ( $UserID || 0 ),
            UserLogin    => $Agent ? $Agent->{UserLogin} : q{},
            UserFullname => $Agent ? $Agent->{UserFullname} : q{},
            Queues       => $Queues || [],
            Errors       => \@Errors,
        },
    };
}

1;
