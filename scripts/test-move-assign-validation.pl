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

    my $TicketID       = $Class->Param( $Request, 'TicketID' );
    my $QueueID        = $Class->Param( $Request, 'QueueID' );
    my $QueueName      = $Class->Param( $Request, 'QueueName' );
    my $OwnerID        = $Class->Param( $Request, 'OwnerID' );
    my $OwnerLogin     = $Class->Param( $Request, 'OwnerLogin' );
    my $CustomerUserID = $Class->Param( $Request, 'CustomerUserID' );
    my $CustomerID     = $Class->Param( $Request, 'CustomerID' );
    my $Note           = $Class->Param( $Request, 'Note' );

    return $Class->MoveAssignValidation(
        TicketID       => $TicketID,
        QueueID        => $QueueID,
        QueueName      => $QueueName,
        OwnerID        => $OwnerID,
        OwnerLogin     => $OwnerLogin,
        CustomerUserID => $CustomerUserID,
        CustomerID     => $CustomerID,
        Note           => $Note,
        UserID         => 2,
    );
}

sub HasError {
    my ( $Validation, $Expected ) = @_;

    return scalar grep { $_ eq $Expected } @{ $Validation->{Errors} || [] };
}

{
    no warnings 'redefine';

    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketLookup = sub {
        return {
            TicketID      => 57467,
            TicketNumber  => 'T57467',
            QueueID       => 3,
            Queue         => 'Junk',
            OwnerID       => 2,
            Owner         => 'current.agent',
            CustomerID    => 'old-customer',
            CustomerUserID => 'old.customer',
            CustomerUser  => 'Old Customer',
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketAssignmentSnapshot = sub {
        my $Snapshot = {
            QueueID             => 3,
            QueueName           => 'Junk',
            OwnerID             => 2,
            OwnerLogin          => 'current.agent',
            OwnerFullname       => 'Current Agent',
            CustomerID          => 'old-customer',
            CustomerUserID      => 'old.customer',
            CustomerUserFullname => 'Old Customer',
            CustomerUserEmail   => 'old.customer@example.invalid',
        };
        return $Snapshot;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::QueueData = sub {
        my ( $Class, %Param ) = @_;
        my $QueueID = $Param{QueueID} || 0;
        return if !$QueueID;

        return {
            QueueID   => $QueueID,
            QueueName => ( $QueueID == 3 ? 'Junk' : 'Vamark Projects' ),
            GroupID   => 1,
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::OwnerData = sub {
        my ( $Class, %Param ) = @_;
        return if $Param{OwnerID} && $Param{OwnerID} == 5;

        return {
            OwnerID       => 31,
            OwnerLogin    => 'target.agent',
            OwnerFullname => 'Target Agent',
        };
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketCustomerData = sub {
        my ( $Class, %Param ) = @_;
        return if !$Param{CustomerUserID} || $Param{CustomerUserID} eq 'invalid.customer';

        return {
            CustomerID          => 'target-customer',
            CustomerUserID      => 'target.customer',
            CustomerUserFullname => 'Target Customer',
            CustomerUserEmail   => 'target.customer@example.invalid',
        };
    };

    my $OwnerAllowed = 1;
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::OwnerCanOwnQueue = sub {
        return $OwnerAllowed;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketQueueMoveAllowed = sub { return 1; };

    my $QueueUpdateCalls    = 0;
    my $CustomerUpdateCalls = 0;
    my $OwnerUpdateCalls    = 0;
    my $ArticleCalls        = 0;
    my @MutationOrder;

    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::AuthenticateWriteAgent = sub {
        return ( 1, undef, 2 );
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketQueueUpdate = sub {
        $QueueUpdateCalls++;
        push @MutationOrder, 'queue';
        return 1;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketCustomerUpdate = sub {
        $CustomerUpdateCalls++;
        push @MutationOrder, 'customer';
        return 1;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketOwnerUpdate = sub {
        $OwnerUpdateCalls++;
        push @MutationOrder, 'owner';
        return 1;
    };
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketArticleCreate = sub {
        $ArticleCalls++;
        return 1001;
    };

    my $Operation = bless {}, 'Kernel::GenericInterface::Operation::Ticket::MoveAssign';

    my $CustomerOnly = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID      => 57467,
                CustomerUserID => 'target.customer',
            },
        }
    );
    Assert( $CustomerOnly->{Valid}, 'customer-only request must be valid' );
    Assert( !$CustomerOnly->{RequiredNote}, 'customer-only request must not require note' );
    Assert( $CustomerOnly->{CustomerChanged}, 'customer-only request must change customer' );
    Assert( $CustomerOnly->{Current}->{CustomerUserID} eq 'old.customer', 'current customer must be populated' );
    Assert( $CustomerOnly->{Target}->{CustomerID} eq 'target-customer', 'target CustomerID must be derived' );

    my $CustomerExecution = $Operation->Run(
        UserLogin => 'auth.agent',
        Data      => {
            TicketID      => 57467,
            CustomerUserID => 'target.customer',
            Note           => 'Optional customer context.',
        },
    );
    Assert( $CustomerExecution->{Data}->{Success}, 'customer-only execution must succeed' );
    Assert( $CustomerExecution->{Data}->{CustomerChanged}, 'customer-only execution must report CustomerChanged' );
    Assert( $CustomerUpdateCalls == 1, 'customer-only execution must update customer once' );
    Assert( $QueueUpdateCalls == 0, 'customer-only execution must not update queue' );
    Assert( $OwnerUpdateCalls == 0, 'customer-only execution must not update owner' );
    Assert( $ArticleCalls == 0, 'customer-only execution must not create wrapper article' );

    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $QueueExecution = $Operation->Run(
        Data => {
            TicketID => 57467,
            QueueID  => 49,
        },
    );
    Assert( $QueueExecution->{Data}->{Success}, 'queue-only execution must succeed' );
    Assert( $QueueUpdateCalls == 1, 'queue-only execution must update queue once' );
    Assert( $CustomerUpdateCalls == 0 && $OwnerUpdateCalls == 0, 'queue-only execution must not update customer or owner' );

    $OwnerAllowed = 0;
    my $DeniedQueueOnly = ValidationFromRequest(
        {
            Data => {
                TicketID => 57467,
                QueueID  => 49,
            },
        }
    );
    Assert( !$DeniedQueueOnly->{Valid}, 'queue-only request must reject a current owner not assignable in target queue' );
    Assert( HasError( $DeniedQueueOnly, 'Target owner is not assignable in target queue.' ), 'queue-only rejection must be clear' );

    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $DeniedQueueOnlyExecution = $Operation->Run(
        Data => {
            TicketID => 57467,
            QueueID  => 49,
        },
    );
    Assert( !$DeniedQueueOnlyExecution->{Data}->{Success}, 'denied queue-only execution must fail validation' );
    Assert( $QueueUpdateCalls + $CustomerUpdateCalls + $OwnerUpdateCalls == 0, 'denied queue-only execution must not mutate' );
    $OwnerAllowed = 1;

    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $QueueCustomer = ValidationFromRequest(
        {
            Data => {
                TicketID      => 57467,
                QueueID       => 49,
                CustomerUserID => 'target.customer',
            },
        }
    );
    Assert( $QueueCustomer->{Valid}, 'queue and customer request must be valid' );
    Assert( !$QueueCustomer->{RequiredNote}, 'queue and customer request must not require note' );
    Assert( $QueueCustomer->{QueueChanged} && $QueueCustomer->{CustomerChanged}, 'queue and customer must change' );
    Assert( !$QueueCustomer->{OwnerChanged}, 'queue and customer request must preserve owner' );

    my $QueueCustomerExecution = $Operation->Run(
        Data => {
            TicketID      => 57467,
            QueueID       => 49,
            CustomerUserID => 'target.customer',
        },
    );
    Assert( $QueueCustomerExecution->{Data}->{Success}, 'queue and customer execution must succeed' );
    Assert( $QueueUpdateCalls == 1 && $CustomerUpdateCalls == 1, 'queue and customer must each update once' );
    Assert( $OwnerUpdateCalls == 0 && $ArticleCalls == 0, 'queue and customer must not update owner or create note' );
    Assert( join( q{,}, @MutationOrder ) eq 'queue,customer', 'queue and customer execution order must be stable' );

    $OwnerAllowed = 0;
    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $DeniedQueueCustomer = $Operation->Run(
        Data => {
            TicketID      => 57467,
            QueueID       => 49,
            CustomerUserID => 'target.customer',
        },
    );
    Assert( !$DeniedQueueCustomer->{Data}->{Success}, 'queue and customer must reject an unassignable current owner' );
    Assert( $QueueUpdateCalls + $CustomerUpdateCalls + $OwnerUpdateCalls == 0, 'denied queue and customer must not mutate' );

    my $SameQueueCustomer = ValidationFromRequest(
        {
            Data => {
                TicketID      => 57467,
                QueueID       => 3,
                CustomerUserID => 'target.customer',
            },
        }
    );
    Assert( $SameQueueCustomer->{Valid}, 'same-queue customer change must not add an owner permission failure' );
    Assert( !$SameQueueCustomer->{QueueChanged} && $SameQueueCustomer->{CustomerChanged}, 'same-queue customer change must change only customer' );
    $OwnerAllowed = 1;

    my $OwnerCustomerWithoutNote = ValidationFromRequest(
        {
            Data => {
                TicketID      => 57467,
                OwnerLogin    => 'target.agent',
                CustomerUserID => 'target.customer',
            },
        }
    );
    Assert( !$OwnerCustomerWithoutNote->{Valid}, 'owner and customer without note must be invalid' );
    Assert( $OwnerCustomerWithoutNote->{RequiredNote}, 'owner and customer must require note' );
    Assert( @{ $OwnerCustomerWithoutNote->{Errors} } == 1, 'owner and customer without note must fail only the note rule' );

    my $OwnerCustomerWithNote = ValidationFromRequest(
        {
            Data => {
                TicketID      => 57467,
                OwnerLogin    => 'target.agent',
                CustomerUserID => 'target.customer',
                Note           => 'Assign to target agent.',
            },
        }
    );
    Assert( $OwnerCustomerWithNote->{Valid}, 'owner and customer with note must be valid' );
    Assert( $OwnerCustomerWithNote->{OwnerChanged}, 'OwnerLogin must remain the target owner input' );

    my $LockedOwner = ValidationFromRequest(
        {
            Data => {
                TicketID => 57467,
                OwnerID  => 5,
                Note     => 'Locked owner must remain unavailable.',
            },
        }
    );
    Assert( !$LockedOwner->{Valid}, 'locked owner must remain invalid' );
    Assert( HasError( $LockedOwner, 'Target owner not found or is not active.' ), 'locked owner must return the active-owner error' );

    my $AllowedQueueOwner = ValidationFromRequest(
        {
            Data => {
                TicketID => 57467,
                QueueID  => 49,
                OwnerID  => 31,
                Note     => 'Permission check.',
            },
        }
    );
    Assert( $AllowedQueueOwner->{Valid}, 'queue and owner must validate when target owner is assignable' );

    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $AllExecution = $Operation->Run(
        Data => {
            TicketID      => 57467,
            QueueID       => 49,
            OwnerID       => 31,
            CustomerUserID => 'target.customer',
            Note           => 'Move and assign.',
        },
    );
    Assert( $AllExecution->{Data}->{Success}, 'queue, customer, and owner execution must succeed' );
    Assert( $QueueUpdateCalls == 1 && $CustomerUpdateCalls == 1 && $OwnerUpdateCalls == 1, 'all targets must update once' );
    Assert( $ArticleCalls == 0, 'owner change must not create a duplicate wrapper note' );
    Assert( join( q{,}, @MutationOrder ) eq 'queue,customer,owner', 'combined execution order must be queue, customer, owner' );

    $OwnerAllowed = 0;
    my $DeniedQueueOwner = ValidationFromRequest(
        {
            Data => {
                TicketID => 57467,
                QueueID  => 49,
                OwnerID  => 31,
                Note     => 'Permission check.',
            },
        }
    );
    Assert( !$DeniedQueueOwner->{Valid}, 'queue and owner must reject an unassignable target owner' );
    Assert( HasError( $DeniedQueueOwner, 'Target owner is not assignable in target queue.' ), 'queue and owner denial must be clear' );
    $OwnerAllowed = 1;

    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $InvalidCustomer = $Operation->Run(
        Data => {
            TicketID      => 57467,
            QueueID       => 49,
            OwnerID       => 31,
            CustomerUserID => 'invalid.customer',
            Note           => 'Must not mutate.',
        },
    );
    Assert( !$InvalidCustomer->{Data}->{Success}, 'invalid customer must return a structured failure' );
    Assert( $QueueUpdateCalls + $CustomerUpdateCalls + $OwnerUpdateCalls == 0, 'invalid customer must cause no mutation' );

    my $CustomerMismatch = ValidationFromRequest(
        {
            Data => {
                TicketID      => 57467,
                CustomerUserID => 'target.customer',
                CustomerID     => 'wrong-customer',
            },
        }
    );
    Assert( !$CustomerMismatch->{Valid}, 'CustomerID mismatch must be invalid' );
    Assert( HasError( $CustomerMismatch, 'CustomerID does not match CustomerUserID.' ), 'mismatch must return its error' );

    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $CustomerMismatchExecution = $Operation->Run(
        Data => {
            TicketID      => 57467,
            QueueID       => 49,
            CustomerUserID => 'target.customer',
            CustomerID     => 'wrong-customer',
        },
    );
    Assert( !$CustomerMismatchExecution->{Data}->{Success}, 'CustomerID mismatch execution must fail validation' );
    Assert( $QueueUpdateCalls + $CustomerUpdateCalls + $OwnerUpdateCalls == 0, 'CustomerID mismatch must cause no mutation' );

    my $CustomerIDOnly = ValidationFromRequest(
        {
            Data => {
                TicketID  => 57467,
                CustomerID => 'target-customer',
            },
        }
    );
    Assert( !$CustomerIDOnly->{Valid}, 'CustomerID-only request must be invalid' );
    Assert( HasError( $CustomerIDOnly, 'CustomerUserID is required when changing customer.' ), 'CustomerID-only error must be explicit' );

    $OwnerAllowed = 0;
    $QueueUpdateCalls = $CustomerUpdateCalls = $OwnerUpdateCalls = $ArticleCalls = 0;
    @MutationOrder = ();
    my $DeniedOwner = $Operation->Run(
        Data => {
            TicketID      => 57467,
            QueueID       => 49,
            OwnerID       => 31,
            CustomerUserID => 'target.customer',
            Note           => 'Must not mutate.',
        },
    );
    Assert( !$DeniedOwner->{Data}->{Success}, 'owner without target queue permission must fail' );
    Assert( $QueueUpdateCalls + $CustomerUpdateCalls + $OwnerUpdateCalls == 0, 'owner permission failure must cause no mutation' );
    $OwnerAllowed = 1;

    my $TicketOnly = ValidationFromRequest(
        {
            UserLogin => 'auth.agent',
            Data      => {
                TicketID => 57467,
                UserLogin => 'auth.agent',
            },
        }
    );
    Assert( !$TicketOnly->{Valid}, 'TicketID-only request must be invalid' );
    Assert( !$TicketOnly->{OwnerChanged} && !$TicketOnly->{CustomerChanged}, 'auth UserLogin must not become a target' );
    Assert( HasError( $TicketOnly, 'At least one target change is required.' ), 'TicketID-only request must return no-target error' );
}

print "PASS: move/assign validation regression checks\n";
