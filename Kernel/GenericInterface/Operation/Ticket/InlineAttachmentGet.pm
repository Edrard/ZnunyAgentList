package Kernel::GenericInterface::Operation::Ticket::InlineAttachmentGet;

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

    my ( $AuthOK, $AuthError, $UserID ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->AuthenticateReadAgent( $Self, %Param );
    if ( !$AuthOK ) {
        return $AuthError;
    }

    my $RawTicketID  = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'TicketID' );
    my $RawArticleID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'ArticleID' );
    my $RawContentID = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->Param( \%Param, 'ContentID' );

    my ( $Attachment, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineAttachmentData(
        TicketID  => $RawTicketID,
        ArticleID => $RawArticleID,
        ContentID => $RawContentID,
        UserID    => $UserID,
    );

    if ( !$Attachment ) {
        return {
            Success => 1,
            Data    => {
                Found    => 0,
                TicketID  => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt($RawTicketID) || 0,
                ArticleID => Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt($RawArticleID) || 0,
                Errors    => $Errors || ['Inline attachment could not be resolved.'],
            },
        };
    }

    if ( !$Attachment->{Found} ) {
        $Attachment->{TicketID}  ||= Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt($RawTicketID) || 0;
        $Attachment->{ArticleID} ||= Kernel::GenericInterface::Operation::ZnunyAgentList::Common->PositiveInt($RawArticleID) || 0;
        $Attachment->{Errors} = $Errors || [];

        return {
            Success => 1,
            Data    => $Attachment,
        };
    }

    $Attachment->{Errors} = [];

    return {
        Success => 1,
        Data    => $Attachment,
    };
}

1;
