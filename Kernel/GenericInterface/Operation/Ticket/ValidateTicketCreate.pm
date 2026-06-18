package Kernel::GenericInterface::Operation::Ticket::ValidateTicketCreate;

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

    my @Errors;
    my @Warnings;

    my $RawOwnerID      = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'OwnerID' );
    my $RawQueue        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Queue' );
    my $RawCustomerUser = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'CustomerUser' );
    my $RawState        = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'State' );
    my $RawLock         = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'Lock' );

    my $OwnerID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt(
        $RawOwnerID,
    );
    my $Queue = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawQueue,
        255,
    );
    my $CustomerUser = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawCustomerUser,
        255,
    );
    my $State = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawState,
        100,
    );
    my $Lock = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->SafeString(
        $RawLock,
        100,
    );

    if (!$OwnerID) {
        push @Errors, 'OwnerID is required.';
    }
    else {
        my $UserObject = $Kernel::OM->Get('Kernel::System::User');
        my %UserData   = $UserObject->GetUserData(
            UserID => $OwnerID,
            Valid  => 1,
        );

        if ( !$UserData{UserID} || !$UserData{UserLogin} || ( $UserData{ValidID} && $UserData{ValidID} != 1 ) ) {
            push @Errors, 'OwnerID agent not found.';
        }
    }

    if (!$Queue) {
        push @Errors, 'Queue is required.';
    }
    else {
        my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
        my %QueueData   = $QueueObject->QueueGet( Name => $Queue );

        if ( !$QueueData{QueueID} || ( $QueueData{ValidID} && $QueueData{ValidID} != 1 ) ) {
            push @Errors, 'Queue not found.';
        }
    }

    if (!$CustomerUser) {
        push @Errors, 'CustomerUser is required.';
    }
    else {
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
        my %UserData           = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUser,
        );

        if ( !$UserData{UserLogin} ) {
            push @Errors, 'CustomerUser not found.';
        }
    }

    if (!$State) {
        push @Errors, 'State is required.';
    }
    else {
        my $StateObject = $Kernel::OM->Get('Kernel::System::State');
        my $StateID     = eval { $StateObject->StateLookup( State => $State ) };

        if (!$StateID) {
            push @Errors, 'State not found.';
        }
    }

    if (!$Lock) {
        push @Errors, 'Lock is required.';
    }
    else {
        my $LockObject = eval { $Kernel::OM->Get('Kernel::System::Lock') };

        if ($LockObject) {
            my $LockID = eval { $LockObject->LockLookup( Lock => $Lock ) };
            if (!$LockID) {
                push @Errors, 'Lock not found.';
            }
        }
        else {
            push @Warnings, 'Lock validation is unavailable.';
        }
    }

    return {
        Success => 1,
        Data    => {
            Valid    => @Errors ? 0 : 1,
            Errors   => \@Errors,
            Warnings => \@Warnings,
        },
    };
}

1;
