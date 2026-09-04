package Kernel::GenericInterface::Operation::CustomerUser::Create;

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

    my ( $AuthOK, $AuthError, $UserID ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateWriteAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my %Input = map {
        $_ => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, $_ )
    } qw(FirstName LastName Login Email CustomerID);
    $Input{PasswordProvided}
        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserPasswordInputProvided( \%Param );

    my ( $CustomerUser, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserCreateData(
        %Input,
        UserID => $UserID,
    );

    return {
        Success => 1,
        Data    => {
            Created      => $CustomerUser ? 1 : 0,
            CustomerUser => $CustomerUser,
            Errors       => $Errors || [],
        },
    };
}

1;
