package Kernel::GenericInterface::Operation::Ticket::SLAList;

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

    my ( $AuthOK, $AuthError, $UserID ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my @Warnings;
    my @SLAs;

    my $SLAObject = eval { $Kernel::OM->Get('Kernel::System::SLA') };
    if (!$SLAObject) {
        push @Warnings, 'SLA support is unavailable.';
    }
    else {
        my %SLAList = eval {
            $SLAObject->SLAList(
                UserID => $UserID,
                Valid  => 1,
            );
        };

        if ($@) {
            push @Warnings, 'SLA support is unavailable.';
            %SLAList = ();
        }

        for my $SLAID ( sort { $a <=> $b } keys %SLAList ) {
            push @SLAs, {
                SLAID   => 0 + $SLAID,
                Name    => $SLAList{$SLAID} || q{},
                ValidID => 1,
            };
        }

        @SLAs = sort {
            lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
                || ( $a->{SLAID} || 0 ) <=> ( $b->{SLAID} || 0 )
        } @SLAs;
    }

    return {
        Success => 1,
        Data    => {
            SLAs     => \@SLAs,
            Warnings => \@Warnings,
        },
    };
}

1;
