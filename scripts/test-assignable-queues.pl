#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/..";

BEGIN {
    package Kernel::GenericInterface::Operation::Common;
    $INC{'Kernel/GenericInterface/Operation/Common.pm'} = 1;
}

use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;
use Kernel::GenericInterface::Operation::User::AssignableQueues;

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

{
    package Test::User;

    sub UserList {
        my ( $Self, %Param ) = @_;

        return ( 6 => 'active.agent', 7 => 'no.queues.agent' ) if $Param{Type} eq 'Short';
        return ( 6 => 'Active Agent', 7 => 'No Queues Agent' );
    }

    sub GetUserData {
        my ( $Self, %Param ) = @_;

        return ( UserID => 6, UserLogin => 'active.agent' ) if $Param{UserID} == 6;
        return ( UserID => 7, UserLogin => 'no.queues.agent' ) if $Param{UserID} == 7;
        return;
    }
}

{
    package Test::Queue;

    sub QueueList {
        my ( $Self, %Param ) = @_;

        $Self->{ValidRequested} = $Param{Valid};
        return ( 3 => 'Junk', 49 => 'Vamark Projects' );
    }

    sub QueueGet {
        my ( $Self, %Param ) = @_;

        return ( QueueID => 3, Name => 'Junk', GroupID => 20, ValidID => 1 ) if $Param{ID} == 3;
        return ( QueueID => 49, Name => 'Vamark Projects', GroupID => 10, ValidID => 1 ) if $Param{ID} == 49;
        return;
    }
}

{
    package Test::Group;

    sub PermissionUserGet {
        my ( $Self, %Param ) = @_;

        $Self->{LastUserID} = $Param{UserID};
        $Self->{LastType}   = $Param{Type};
        return ( 10 => 'project-owner-group' ) if $Param{UserID} == 6;
        return;
    }
}

{
    package Test::Config;

    sub Get {
        return 0;
    }
}

{
    package Test::OM;

    sub Get {
        my ( $Self, $Name ) = @_;

        return $Self->{$Name};
    }
}

my $QueueObject = bless {}, 'Test::Queue';
my $GroupObject = bless {}, 'Test::Group';
my $ConfigObject = bless {}, 'Test::Config';
my $OM = bless {
    'Kernel::System::User'  => bless( {}, 'Test::User' ),
    'Kernel::System::Queue' => $QueueObject,
    'Kernel::System::Group' => $GroupObject,
    'Kernel::Config'        => $ConfigObject,
}, 'Test::OM';

{
    no warnings 'redefine';

    local $Kernel::OM = $OM;
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::AuthenticateReadAgent = sub {
        return ( 1, undef, 2 );
    };

    my $Operation = bless {}, 'Kernel::GenericInterface::Operation::User::AssignableQueues';

    my $Active = $Operation->Run(
        UserLogin => 'authentication.agent',
        Data      => { UserID => 6 },
    );
    Assert( $Active->{Data}->{Success}, 'active agent lookup must succeed' );
    Assert( $Active->{Data}->{UserID} == 6, 'path UserID must be the target agent' );
    Assert( $Active->{Data}->{UserLogin} eq 'active.agent', 'safe user login must be returned' );
    Assert( $Active->{Data}->{UserFullname} eq 'Active Agent', 'safe fullname must be returned' );
    Assert(
        join( q{,}, sort keys %{ $Active->{Data} } ) eq 'Errors,Queues,Success,UserFullname,UserID,UserLogin',
        'response must expose only safe user fields, queues, success, and errors',
    );
    Assert( @{ $Active->{Data}->{Queues} } == 1, 'only owner-permitted valid queues must be returned' );
    Assert( $Active->{Data}->{Queues}->[0]->{QueueID} == 49, 'owner group queue must be returned' );
    Assert(
        join( q{,}, sort keys %{ $Active->{Data}->{Queues}->[0] } ) eq 'FullName,Name,QueueID',
        'queue response must contain only QueueID, Name, and FullName',
    );
    Assert( $QueueObject->{ValidRequested} == 1, 'queue lookup must request valid queues only' );
    Assert( $GroupObject->{LastType} eq 'owner', 'group lookup must use owner permission' );

    my $NoQueues = $Operation->Run(
        UserLogin => 'authentication.agent',
        Data      => { UserID => 7 },
    );
    Assert( $NoQueues->{Data}->{Success}, 'active agent without queues must succeed' );
    Assert( !@{ $NoQueues->{Data}->{Queues} }, 'active agent without owner groups must return an empty queue list' );
    Assert( !@{ $NoQueues->{Data}->{Errors} }, 'active agent without queues must not return errors' );

    for my $UserID ( 5, 999 ) {
        my $Missing = $Operation->Run(
            UserLogin => 'authentication.agent',
            Data      => { UserID => $UserID },
        );
        Assert( !$Missing->{Data}->{Success}, 'inactive or missing agent must fail' );
        Assert( $Missing->{Data}->{UserID} == $UserID, 'failed response must retain requested UserID' );
        Assert( $Missing->{Data}->{UserLogin} eq q{}, 'failed response must not expose user login' );
        Assert( $Missing->{Data}->{UserFullname} eq q{}, 'failed response must not expose fullname' );
        Assert( !@{ $Missing->{Data}->{Queues} }, 'failed response must contain no queues' );
        Assert(
            $Missing->{Data}->{Errors}->[0] eq 'Agent not found or is not active.',
            'inactive or missing agent must return a clear error',
        );
    }
}

my $OperationFile = "$Bin/../Kernel/GenericInterface/Operation/User/AssignableQueues.pm";
open my $OperationHandle, '<', $OperationFile or die "FAIL: cannot read $OperationFile: $!\n";
my $OperationSource = do { local $/; <$OperationHandle> };
close $OperationHandle;

Assert( $OperationSource =~ /AuthenticateReadAgent/, 'operation must use read authorization' );
Assert( $OperationSource !~ /AuthenticateWriteAgent|EnableTicketWriteOperations/, 'operation must not require write authorization' );
Assert( $OperationSource !~ /DB->Do|\b(?:SELECT|INSERT|UPDATE|DELETE)\b/, 'operation must not contain raw SQL' );
Assert( $OperationSource !~ /Param\(\s*\\%Param,\s*'UserLogin'/, 'authentication UserLogin must not be read as target input' );

print "PASS: assignable queues regression checks\n";
