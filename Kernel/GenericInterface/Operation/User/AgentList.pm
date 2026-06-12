package Kernel::GenericInterface::Operation::User::AgentList;

use strict;
use warnings;

use parent qw(Kernel::GenericInterface::Operation::Common);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my ( $UserID, $UserType ) = $Self->Auth(%Param);

    if ( !$UserID || !defined $UserType || $UserType ne 'User' ) {
        return $Self->ReturnError(
            ErrorCode    => 'AgentList.AuthFail',
            ErrorMessage => 'AgentList: Authentication failed.',
        );
    }

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my %UserList = $UserObject->UserList(
        Type          => 'Long',
        Valid         => 1,
        NoOutOfOffice => 1,
    );

    my @Agents;

    # UserList provides UserID => formatted fullname; NoOutOfOffice keeps the
    # fullname free from status suffixes, while GetUserData determines current
    # out-of-office state.
    USERID:
    for my $ListUserID ( sort { $a <=> $b } keys %UserList ) {
        my %UserData = $UserObject->GetUserData(
            UserID => $ListUserID,
        );

        if ( $UserData{OutOfOfficeMessage} ) {
            next USERID;
        }

        if ( !$UserData{UserID} || !defined $UserData{UserLogin} || $UserData{UserLogin} eq '' ) {
            next USERID;
        }

        push @Agents, {
            UserID       => 0 + $UserData{UserID},
            UserLogin    => $UserData{UserLogin},
            UserFullname => $UserList{$ListUserID} // q{},
        };
    }

    @Agents = sort {
        lc( $a->{UserFullname} // q{} ) cmp lc( $b->{UserFullname} // q{} )
            || lc( $a->{UserLogin} // q{} ) cmp lc( $b->{UserLogin} // q{} )
            || ( $a->{UserID} || 0 ) <=> ( $b->{UserID} || 0 )
    } @Agents;

    return {
        Success => 1,
        Data    => {
            Agents => \@Agents,
        },
    };
}

1;
