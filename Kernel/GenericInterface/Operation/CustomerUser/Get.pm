package Kernel::GenericInterface::Operation::CustomerUser::Get;

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

    my $RawCustomerUserLogin = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUserLogin' );
    my $RawCustomerUser      = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUser' );

    my $CustomerUserLogin = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        defined $RawCustomerUserLogin ? $RawCustomerUserLogin : $RawCustomerUser,
        255,
    );

    my %UserData;
    if ($CustomerUserLogin) {
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
        %UserData = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserLogin,
        );
    }

    if ( !$UserData{UserLogin} ) {
        return {
            Success => 1,
            Data    => {
                CustomerUser => { Found => 0 },
                Warnings     => ['CustomerUser not found.'],
            },
        };
    }

    my $CustomerUser = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->CustomerUserData(%UserData);
    $CustomerUser->{Found} = 1;

    return {
        Success => 1,
        Data    => {
            CustomerUser => $CustomerUser,
        },
    };
}

1;
