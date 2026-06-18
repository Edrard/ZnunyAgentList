package Kernel::GenericInterface::Operation::Queue::Get;

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
    my $RawQueueID  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'QueueID' );
    my $RawName     = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Name' );

    my $QueueID     = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        $RawQueueID,
    );
    my $Name = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawName,
        255,
    );

    my %Queue;

    if ($QueueID) {
        %Queue = $QueueObject->QueueGet( ID => $QueueID );
    }
    elsif ($Name) {
        %Queue = $QueueObject->QueueGet( Name => $Name );
    }

    if ( !$Queue{QueueID} || !$Queue{Name} || ( $Queue{ValidID} && $Queue{ValidID} != 1 ) ) {
        return {
            Success => 1,
            Data    => {
                Queue    => { Found => 0 },
                Warnings => ['Queue not found.'],
            },
        };
    }

    return {
        Success => 1,
        Data    => {
            Queue => {
                Found    => 1,
                QueueID  => 0 + $Queue{QueueID},
                Name     => $Queue{Name},
                FullName => $Queue{FullName} || $Queue{Name},
                ValidID  => 0 + ( $Queue{ValidID} || 1 ),
            },
        },
    };
}

1;
