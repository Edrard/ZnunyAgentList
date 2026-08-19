#!/usr/bin/env perl

use strict;
use warnings;

use MIME::Base64 qw(decode_base64);

BEGIN {
    my $ScriptDir = $0;
    $ScriptDir =~ s{\\}{/}g;
    $ScriptDir =~ s{/[^/]*\z}{};
    unshift @INC, "$ScriptDir/..";
}

use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

{
    package Test::Article;

    sub ArticleList {
        my ( $Self, %Param ) = @_;

        return if $Param{TicketID} != 59078;
        return if $Param{ArticleID} != 354070;

        return ( { TicketID => 59078, ArticleID => 354070 } );
    }

    sub ArticleAttachmentIndex {
        my ( $Self, %Param ) = @_;

        return (
            1 => {
                Filename    => 'image003.jpg',
                ContentType => 'image/jpeg',
                ContentID   => '<image003.jpg@01DD2EF7.2CE4B9D0>',
                Disposition => '',
                FilesizeRaw => 7,
            },
            2 => {
                Filename    => 'doc.txt',
                ContentType => 'text/plain',
                ContentID   => '<doc@example>',
                Disposition => 'attachment',
                FilesizeRaw => 4,
            },
        );
    }

    sub ArticleAttachment {
        my ( $Self, %Param ) = @_;

        return (
            Filename    => 'image003.jpg',
            ContentType => 'image/jpeg; name="image003.jpg"',
            ContentID   => '<image003.jpg@01DD2EF7.2CE4B9D0>',
            Disposition => 'inline',
            FilesizeRaw => 7,
            Content     => "imgdata",
        ) if $Param{FileID} == 1;

        return (
            Filename    => 'doc.txt',
            ContentType => 'text/plain',
            ContentID   => '<doc@example>',
            Disposition => 'attachment',
            FilesizeRaw => 4,
            Content     => "text",
        );
    }
}

{
    package Test::OM;

    sub Get {
        my ( $Self, $Name ) = @_;

        return $Self->{$Name};
    }
}

my $OM = bless {
    'Kernel::System::Ticket::Article' => bless( {}, 'Test::Article' ),
}, 'Test::OM';

{
    no warnings 'redefine';

    local $Kernel::OM = $OM;
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::TicketLookup = sub {
        my ( $Class, %Param ) = @_;
        return if $Param{TicketID} != 59078;
        return { TicketID => 59078, TicketNumber => 'T59078' };
    };

    for my $Case (
        [ 'image/jpeg; name="image003.jpg"', 'image/jpeg' ],
        [ 'IMAGE/JPEG; NAME="image003.jpg"', 'image/jpeg' ],
        [ ' image/jpg ; name="image003.jpg" ', 'image/jpeg' ],
        [ 'image/png; name="image003.png"',   'image/png' ],
        [ 'image/gif; name="image003.gif"',   'image/gif' ],
        [ 'image/webp; name="image003.webp"', 'image/webp' ],
        )
    {
        Assert(
            Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineImageContentType( $Case->[0] ) eq $Case->[1],
            'inline MIME parser must normalize allowed media types and ignore parameters',
        );
    }

    for my $RejectedContentType ( 'image/svg+xml', 'text/plain', 'application/octet-stream', 'image/jpeg/extra', 'image', ['image/png'] ) {
        Assert(
            Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineImageContentType($RejectedContentType) eq q{},
            'inline MIME parser must reject unsafe or malformed content types',
        );
    }

    for my $ContentID (
        'image003.jpg@01DD2EF7.2CE4B9D0',
        '<image003.jpg@01DD2EF7.2CE4B9D0>',
        'cid:image003.jpg@01DD2EF7.2CE4B9D0',
        'cid:<image003.jpg@01DD2EF7.2CE4B9D0>',
        )
    {
        my ( $Attachment, $Errors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineAttachmentData(
            TicketID  => 59078,
            ArticleID => 354070,
            ContentID => $ContentID,
            UserID    => 2,
        );

        Assert( $Attachment->{Found}, 'inline image must be found for accepted ContentID form' );
        Assert( $Attachment->{ContentID} eq 'image003.jpg@01DD2EF7.2CE4B9D0', 'ContentID must be normalized' );
        Assert( $Attachment->{ContentType} eq 'image/jpeg', 'MIME parameters must be accepted but response must return normalized image/jpeg' );
        Assert( decode_base64( $Attachment->{Content} ) eq 'imgdata', 'content must be base64 encoded' );
        Assert( !@{$Errors}, 'successful lookup must not return errors' );
        Assert(
            join( q{,}, sort keys %{$Attachment} ) eq 'ArticleID,Content,ContentID,ContentType,Disposition,FileID,Filename,FilesizeRaw,Found,TicketID',
            'inline attachment response must expose only safe fields',
        );
    }

    my ( $Missing, $MissingErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineAttachmentData(
        TicketID  => 59078,
        ArticleID => 354070,
        ContentID => 'missing@example',
        UserID    => 2,
    );
    Assert( !$Missing->{Found}, 'missing ContentID must return Found=0' );
    Assert( $MissingErrors->[0] eq 'Inline attachment not found.', 'missing ContentID must return structured not-found error' );

    for my $MalformedContentID ( '<<image003.jpg@01DD2EF7.2CE4B9D0>>', 'cid:<<image003.jpg@01DD2EF7.2CE4B9D0>>' ) {
        my ( $Malformed, $MalformedErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineAttachmentData(
            TicketID  => 59078,
            ArticleID => 354070,
            ContentID => $MalformedContentID,
            UserID    => 2,
        );
        Assert( !$Malformed, 'malformed nested ContentID wrappers must not normalize to a valid attachment' );
        Assert( $MalformedErrors->[0] eq 'TicketID, ArticleID, and ContentID are required.', 'malformed ContentID must fail validation safely' );
    }

    my ( $TextAttachment, $TextErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineAttachmentData(
        TicketID  => 59078,
        ArticleID => 354070,
        ContentID => 'doc@example',
        UserID    => 2,
    );
    Assert( !$TextAttachment, 'non-image attachment must be rejected' );
    Assert( $TextErrors->[0] eq 'Attachment is not an allowed inline image type.', 'non-image rejection must be clear' );

    local *Test::Article::ArticleAttachmentIndex = sub {
        return (
            1 => { ContentID => '<dup@example>', ContentType => 'image/png', Filename => 'a.png' },
            2 => { ContentID => 'dup@example',   ContentType => 'image/png', Filename => 'b.png' },
        );
    };

    my ( $Duplicate, $DuplicateErrors ) = Kernel::GenericInterface::Operation::ZnunyAgentList::Common->InlineAttachmentData(
        TicketID  => 59078,
        ArticleID => 354070,
        ContentID => 'cid:dup@example',
        UserID    => 2,
    );
    Assert( !$Duplicate, 'duplicate ContentID must not choose arbitrarily' );
    Assert( $DuplicateErrors->[0] eq 'ContentID is not unique for this article.', 'duplicate ContentID must return unresolved error' );
}

print "PASS: inline attachment regression checks\n";
