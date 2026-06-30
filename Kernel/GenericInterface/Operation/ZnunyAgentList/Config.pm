package Kernel::GenericInterface::Operation::ZnunyAgentList::Config;

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

    return {
        Success => 1,
        Data    => {
            Plugin  => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PACKAGE_NAME,
            Version => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PACKAGE_VERSION,
            Features => {
                AgentList             => 1,
                QueueList             => 1,
                QueueGet              => 1,
                QueueAssignableAgents => 1,
                CustomerUserSearch    => 1,
                CustomerUserGet       => 1,
                TicketGet             => 1,
                TicketSearch          => 1,
                TicketArticleCreate   => 1,
                TicketClose           => 1,
                TicketReopen          => 1,
                TicketLock            => 1,
                TicketUnlock          => 1,
                TicketMoveAssignValidate => 1,
                TicketMoveAssign      => 1,
                ResolveTicketDefaults => 1,
                TicketStateList       => 1,
                TicketPriorityList    => 1,
                TicketTypeList        => 1,
                ServiceList           => 1,
                SLAList               => 1,
                ValidateTicketCreate  => 1,
                SystemConfig          => 1,
                Health                => 1,
            },
            Znuny => {
                Version => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ZnunyVersion,
            },
        },
    };
}

1;
