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
use Kernel::GenericInterface::Operation::Ticket::MoveAssign;

my $Class = 'Kernel::GenericInterface::Operation::ZnunyAgentList::Common';

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

sub ValidationFromRequest {
    my ($Request) = @_;

    my $TicketID  = $Class->Param( $Request, 'TicketID' );
    my $QueueID   = $Class->Param( $Request, 'QueueID' );
    my $QueueName = $Class->Param( $Request, 'QueueName' );
    my $OwnerID   = $Class->Param( $Request, 'OwnerID' );
    my $UserLogin = $Class->DataParam( $Request, 'UserLogin' );
    my $Note      = $Class->Param( $Request, 'Note' );

    return $Class->MoveAssignValidation(
        TicketID  => $TicketID,
        QueueID   => $QueueID,
        QueueName => $QueueName,
        OwnerID   => $OwnerID,
        UserLogin => $UserLogin,
        Note      => $Note,
        UserID    => 2,
    );
}

{
    no warnings 'redefine';

    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketLookup = sub {
        return {
            TicketID     => 57467,
            TicketNumber => 'T57467',
            QueueID      => 3,
            Queue        => 'Junk',
            OwnerID      => 2,
            Owner        => 'current.agent',
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketAssignmentSnapshot = sub {
        return {
            QueueID       => 3,
            QueueName     => 'Junk',
            OwnerID       => 2,
            OwnerLogin    => 'current.agent',
            OwnerFullname => 'Current Agent',
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::QueueData = sub {
        my ( $Class, %Param ) = @_;
        my $QueueID = $Param{QueueID} || 0;
        return if !$QueueID;

        return {
            QueueID   => $QueueID,
            QueueName => $QueueID == 3 ? 'Junk' : 'Vamark Projects',
            GroupID   => 1,
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::OwnerData = sub {
        return {
            OwnerID       => 31,
            OwnerLogin    => 'target.agent',
            OwnerFullname => 'Target Agent',
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::OwnerCanOwnQueue = sub { return 1; };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketQueueMoveAllowed = sub { return 1; };

    my $QueueUpdateCalls = 0;
    my $OwnerUpdateCalls = 0;
    my $ArticleCalls     = 0;

    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::AuthenticateWriteAgent = sub {
        return ( 1, undef, 2 );
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketQueueUpdate = sub {
        $QueueUpdateCalls++;
        return 1;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketOwnerUpdate = sub {
        $OwnerUpdateCalls++;
        return 1;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketArticleCreate = sub {
        $ArticleCalls++;
        return 1001;
    };

    my $OwnerWithoutNote = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID => 57467,
                OwnerID  => 31,
            },
        }
    );
    Assert( !$OwnerWithoutNote->{Valid}, 'owner-only request without note must be invalid' );
    Assert( $OwnerWithoutNote->{RequiredNote}, 'owner-only request must require note' );
    Assert(
        scalar grep { $_ eq 'Note is required when owner changes.' } @{ $OwnerWithoutNote->{Errors} },
        'owner-only request without note must return the note error',
    );

    my $OwnerWithNote = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID => 57467,
                OwnerID  => 31,
                Note     => 'Assign to target agent.',
            },
        }
    );
    Assert( $OwnerWithNote->{Valid}, 'owner-only request with note must be valid' );
    Assert( $OwnerWithNote->{Target}->{QueueID} == 3, 'owner-only target must use current queue' );
    Assert( $OwnerWithNote->{Target}->{OwnerID} == 31, 'owner-only target must use requested owner' );

    my $QueueOnly = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID => 57467,
                QueueID  => 49,
            },
        }
    );
    Assert( $QueueOnly->{Valid}, 'queue-only request must be valid' );
    Assert( !$QueueOnly->{RequiredNote}, 'queue-only request must not require note' );
    Assert( !$QueueOnly->{OwnerChanged}, 'queue-only request must not change owner' );
    Assert( $QueueOnly->{Target}->{QueueID} == 49, 'queue-only target must use requested queue' );
    Assert( $QueueOnly->{Target}->{OwnerID} == 2, 'queue-only target must preserve current owner' );

    my $QueueOnlyWithNote = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID => 57467,
                QueueID  => 49,
                Note     => 'Move to the project queue.',
            },
        }
    );
    Assert( $QueueOnlyWithNote->{Valid}, 'queue-only request with note must be valid' );
    Assert( !$QueueOnlyWithNote->{OwnerChanged}, 'queue-only request with note must not change owner' );

    my $Operation = bless {}, 'Kernel::GenericInterface::Operation::Ticket::MoveAssign';
    my $QueueExecution = $Operation->Run(
        UserLogin => 'auth.agent',
        Data      => {
            TicketID => 57467,
            QueueID  => 49,
        },
    );
    Assert( $QueueExecution->{Data}->{Success}, 'queue-only execution must succeed' );
    Assert( $QueueUpdateCalls == 1, 'queue-only execution must update queue once' );
    Assert( $OwnerUpdateCalls == 0, 'queue-only execution must not update owner' );
    Assert( $ArticleCalls == 0, 'queue-only execution without note must not create article' );

    my $QueueExecutionWithNote = $Operation->Run(
        UserLogin => 'auth.agent',
        Data      => {
            TicketID => 57467,
            QueueID  => 49,
            Note     => 'Move to the project queue.',
        },
    );
    Assert( $QueueExecutionWithNote->{Data}->{Success}, 'queue-only execution with note must succeed' );
    Assert( $QueueUpdateCalls == 2, 'queue-only execution with note must update queue once' );
    Assert( $OwnerUpdateCalls == 0, 'queue-only execution with note must not update owner' );
    Assert( $ArticleCalls == 1, 'queue-only execution with note must create one article' );

    my $TicketOnly = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID => 57467,
            },
        }
    );
    Assert( !$TicketOnly->{Valid}, 'TicketID-only request must be invalid' );
}

print "PASS: move/assign validation regression checks\n";
