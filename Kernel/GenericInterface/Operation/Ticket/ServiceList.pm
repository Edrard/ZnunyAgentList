package Kernel::GenericInterface::Operation::Ticket::ServiceList;

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
    my @Services;

    my $ServiceObject = eval { $Kernel::OM->Get('Kernel::System::Service') };
    if (!$ServiceObject) {
        push @Warnings, 'Service support is unavailable.';
    }
    else {
        my %ServiceList = eval {
            $ServiceObject->ServiceList(
                UserID => $UserID,
                Valid  => 1,
            );
        };

        if ($@) {
            push @Warnings, 'Service support is unavailable.';
            %ServiceList = ();
        }

        for my $ServiceID ( sort { $a <=> $b } keys %ServiceList ) {
            push @Services, {
                ServiceID => 0 + $ServiceID,
                Name      => $ServiceList{$ServiceID} || q{},
                ValidID   => 1,
            };
        }

        @Services = sort {
            lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
                || ( $a->{ServiceID} || 0 ) <=> ( $b->{ServiceID} || 0 )
        } @Services;
    }

    return {
        Success => 1,
        Data    => {
            Services => \@Services,
            Warnings => \@Warnings,
        },
    };
}

1;
