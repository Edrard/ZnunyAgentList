package Kernel::GenericInterface::Operation::ZnunyAgentList::Health;

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
            Success => 1,
            Plugin  => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PACKAGE_NAME,
            Version => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PACKAGE_VERSION,
            Time    => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->FormatLocalTime,
        },
    };
}

1;
