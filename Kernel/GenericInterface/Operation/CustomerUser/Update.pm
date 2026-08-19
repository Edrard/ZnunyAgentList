package Kernel::GenericInterface::Operation::CustomerUser::Update;

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

    my %Input;

    my $HasBody = ref $Param{Data} eq 'HASH' ? 1 : 0;

    if ( Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ParamExists( \%Param, 'CustomerUserLogin' ) ) {
        $Input{CustomerUserLogin} = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUserLogin' );
    }

    for my $Field (qw(CurrentLogin FirstName LastName Login Email CustomerID)) {
        if ( Kernel::GenericInterface::Operation::ZnunyAgentList::Common->BodyParamExists( \%Param, $Field ) ) {
            $Input{$Field} = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->BodyParam( \%Param, $Field );
        }
        elsif ( !$HasBody && Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ParamExists( \%Param, $Field ) ) {
            $Input{$Field} = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, $Field );
        }
    }

    $Input{PasswordProvided} = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ParamExists( \%Param, 'Password' )
        || Kernel::GenericInterface::Operation::ZnunyAgentList::Common->ParamExists( \%Param, 'UserPassword' );

    my ( $CustomerUser, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserUpdateData(
        %Input,
        UserID => $UserID,
    );

    return {
        Success => 1,
        Data    => {
            Updated      => $CustomerUser ? 1 : 0,
            CustomerUser => $CustomerUser,
            Errors       => $Errors || [],
        },
    };
}

1;
