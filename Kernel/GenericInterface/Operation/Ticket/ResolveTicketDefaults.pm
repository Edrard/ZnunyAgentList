package Kernel::GenericInterface::Operation::Ticket::ResolveTicketDefaults;

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

    my $HostName = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'HostName' ),
        255,
    );

    my @Warnings;
    my $QueueName         = q{};
    my $CustomerUserLogin = q{};

    if ($HostName) {
        $QueueName = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->FirstToken( $HostName, 64 );
        $CustomerUserLogin = $QueueName . 'Clients' if $QueueName;
        if ( !$QueueName ) {
            push @Warnings, 'HostName first token is invalid.';
        }
    }
    else {
        push @Warnings, 'HostName is required.';
    }

    my $Queue = { Found => 0 };
    if ($QueueName) {
        my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
        my %QueueData   = $QueueObject->QueueGet( Name => $QueueName );

        if ( $QueueData{QueueID} && $QueueData{Name} && ( !$QueueData{ValidID} || $QueueData{ValidID} == 1 ) ) {
            $Queue = {
                Found    => 1,
                QueueID  => 0 + $QueueData{QueueID},
                Name     => $QueueData{Name},
                FullName => $QueueData{FullName} || $QueueData{Name},
            };
        }
        else {
            push @Warnings, 'Queue not found.';
        }
    }

    my $CustomerUser = { Found => 0 };
    if ($CustomerUserLogin) {
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
        my %UserData           = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserLogin,
        );

        if ( $UserData{UserLogin} ) {
            $CustomerUser = {
                Found          => 1,
                UserLogin      => $UserData{UserLogin},
                UserCustomerID => $UserData{UserCustomerID} // q{},
            };
        }
        else {
            push @Warnings, 'CustomerUser not found.';
        }
    }

    return {
        Success => 1,
        Data    => {
            Input => {
                HostName => $HostName,
            },
            Detected => {
                QueueName         => $QueueName,
                CustomerUserLogin => $CustomerUserLogin,
            },
            Queue        => $Queue,
            CustomerUser => $CustomerUser,
            Warnings     => \@Warnings,
        },
    };
}

1;
