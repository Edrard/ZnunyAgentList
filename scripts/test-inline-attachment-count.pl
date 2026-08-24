#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    my $ScriptDir = $0;
    $ScriptDir =~ s{\\}{/}g;
    $ScriptDir =~ s{/[^/]*\z}{};
    unshift @INC, "$ScriptDir/..";

    package Kernel::GenericInterface::Operation::Common;

    sub Auth {
        return ( 2, 'User' );
    }

    $INC{'Kernel/GenericInterface/Operation/Common.pm'} = 1;
}

use Kernel::GenericInterface::Operation::Ticket::Search;
use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

{
    package Test::Ticket;

    sub TicketIDLookup {
        my ( $Self, %Param ) = @_;

        return 100 if $Param{TicketNumber} && $Param{TicketNumber} eq 'T100';
        return;
    }

    sub TicketGet {
        my ( $Self, %Param ) = @_;

        return if !$Param{TicketID};

        return (
            TicketID       => 0 + $Param{TicketID},
            TicketNumber   => 'T' . $Param{TicketID},
            Title          => 'Example ticket',
            QueueID        => 1,
            Queue          => 'Support',
            OwnerID        => 2,
            Owner          => 'owner@example.com',
            LockID         => 1,
            Lock           => 'unlock',
            CustomerID     => 'example-customer',
            CustomerUserID => 'customer@example.com',
            CustomerUser   => 'customer@example.com',
            StateID        => 4,
            State          => 'open',
            StateType      => 'open',
            PriorityID     => 3,
            Priority       => '3 normal',
            Created        => '2026-01-01 10:00:00',
            Changed        => '2026-01-01 10:30:00',
        );
    }
}

{
    package Test::Article;

    sub new {
        my ( $Class, %Param ) = @_;

        return bless { %Param, ArticleAttachmentCalled => 0 }, $Class;
    }

    sub ArticleList {
        my ( $Self, %Param ) = @_;

        return if $Self->{FailList};

        my $Articles = $Self->{Articles}->{ $Param{TicketID} } || [];
        return @{$Articles};
    }

    sub ArticleAttachmentIndex {
        my ( $Self, %Param ) = @_;

        die 'forced index failure' if $Self->{FailIndex};

        my $Index = $Param{OnlyHTMLBody}
            ? ( $Self->{HTMLIndexes}->{ $Param{ArticleID} } || {} )
            : ( $Self->{Indexes}->{ $Param{ArticleID} } || {} );
        return %{$Index};
    }

    sub ArticleAttachment {
        my $Self = shift;

        $Self->{ArticleAttachmentCalled}++;
        die 'ArticleAttachment must not be called';
    }
}

{
    package Test::OM;

    sub new {
        my ( $Class, %Param ) = @_;

        return bless \%Param, $Class;
    }

    sub Get {
        my ( $Self, $Name ) = @_;

        return $Self->{$Name};
    }
}

my $ArticleObject = Test::Article->new(
    Articles => {
        10  => [],
        20  => [ { TicketID => 20, ArticleID => 200 } ],
        30  => [ { TicketID => 30, ArticleID => 300 } ],
        40  => [ { TicketID => 40, ArticleID => 400 }, { TicketID => 40, ArticleID => 401 } ],
        50  => [ { TicketID => 50, ArticleID => 500 }, { TicketID => 50, ArticleID => 501 } ],
        60  => [ { TicketID => 60, ArticleID => 600 }, { TicketID => 60, ArticleID => 601 } ],
        100 => [ { TicketID => 100, ArticleID => 1000 } ],
    },
    Indexes => {
        200 => {},
        300 => {
            1  => { Disposition => 'inline',     ContentType => 'image/png' },
            2  => { Disposition => 'inline',     ContentType => 'image/jpeg' },
            3  => { Disposition => 'inline',     ContentType => 'image/jpeg; name="x.jpg"' },
            4  => { Disposition => 'INLINE',     ContentType => 'image/gif' },
            5  => { Disposition => 'inline',     ContentType => 'image/webp' },
            6  => { Disposition => 'inline',     ContentType => 'image/jpg' },
            7  => { Disposition => 'attachment', ContentType => 'image/jpeg' },
            8  => { Disposition => '',           ContentType => 'image/jpeg' },
            9  => {                              ContentType => 'image/jpeg' },
            10 => { Disposition => 'inline',     ContentType => 'application/pdf' },
            11 => { Disposition => 'inline',     ContentType => 'image/svg+xml' },
            12 => { Disposition => 'inline',     ContentType => 'image/jpeg/extra' },
            13 => { Disposition => 'inline',     ContentType => ['image/png'] },
        },
        400 => {
            1 => { Disposition => 'inline', ContentType => 'image/png' },
            2 => { Disposition => 'inline', ContentType => 'image/webp' },
        },
        401 => {
            1 => { Disposition => 'inline', ContentType => 'image/gif' },
        },
        1000 => {
            1 => { Disposition => 'inline', ContentType => 'image/png' },
        },
    },
    HTMLIndexes => {
        500 => {
            1 => { Disposition => 'inline', ContentType => 'text/html; charset=utf-8' },
        },
        600 => {
            1 => { Disposition => 'inline', ContentType => 'text/html' },
        },
        601 => {
            1 => { Disposition => 'inline', ContentType => 'text/html; charset="utf-8"' },
        },
        1000 => {
            1 => { Disposition => 'inline', ContentType => 'text/html' },
        },
    },
);

my $OM = Test::OM->new(
    'Kernel::System::Ticket'          => bless( {}, 'Test::Ticket' ),
    'Kernel::System::Ticket::Article' => $ArticleObject,
);

{
    no warnings 'redefine';

    local $Kernel::OM = $OM;
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::AuthenticateReadAgent = sub {
        return ( 1, undef, 2, 'User' );
    };

    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketInlineAttachmentCount( TicketID => 10 ) == 0,
        'ticket with no articles returns 0',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketInlineAttachmentCount( TicketID => 20 ) == 0,
        'articles with no attachments return 0',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketInlineAttachmentCount( TicketID => 30 ) == 6,
        'only inline raster image attachments are counted',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketInlineAttachmentCount( TicketID => 40 ) == 3,
        'matching attachments across multiple articles are summed',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketAttachmentMetadataCounts( TicketID => 10 )->{HTMLBodyArticleCount} == 0,
        'ticket with no articles has no HTML body articles',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketAttachmentMetadataCounts( TicketID => 20 )->{HTMLBodyArticleCount} == 0,
        'articles without HTML alternatives return 0',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketAttachmentMetadataCounts( TicketID => 50 )->{HTMLBodyArticleCount} == 1,
        'one HTML article plus a plain-only article returns 1',
    );
    Assert(
        Kernel::GenericInterface::Operation::ZnunyAgentList::Common->TicketAttachmentMetadataCounts( TicketID => 60 )->{HTMLBodyArticleCount} == 2,
        'several HTML articles are counted by article',
    );
    Assert(
        !$ArticleObject->{ArticleAttachmentCalled},
        'ArticleAttachment is never called for metadata counting',
    );

    my $Operation = bless {}, 'Kernel::GenericInterface::Operation::Ticket::Search';
    my $Response  = $Operation->Run( TicketNumber => 'T100' );
    my $Ticket    = $Response->{Data}->{Tickets}->[0];

    Assert( $Response->{Success}, 'Ticket::Search returns transport success' );
    Assert( ref $Ticket eq 'HASH', 'Ticket::Search returns a ticket object' );
    Assert( exists $Ticket->{InlineAttachmentCount}, 'Ticket::Search includes InlineAttachmentCount' );
    Assert( $Ticket->{InlineAttachmentCount} == 1, 'InlineAttachmentCount is an integer count' );
    Assert( exists $Ticket->{HTMLBodyArticleCount}, 'Ticket::Search includes HTMLBodyArticleCount' );
    Assert( $Ticket->{HTMLBodyArticleCount} == 1, 'HTMLBodyArticleCount is an integer count' );
    Assert( !exists $Ticket->{Attachments}, 'Ticket::Search must not expose attachment lists' );
    Assert( !exists $Ticket->{Content}, 'Ticket::Search must not expose attachment content' );
    Assert( !exists $Ticket->{HTMLBodyContent}, 'Ticket::Search must not expose HTML content' );

    my $FailingArticleObject = Test::Article->new(
        Articles  => { 100 => [ { TicketID => 100, ArticleID => 1000 } ] },
        Indexes   => {},
        FailIndex => 1,
    );
    my $FailingOM = Test::OM->new(
        'Kernel::System::Ticket'          => bless( {}, 'Test::Ticket' ),
        'Kernel::System::Ticket::Article' => $FailingArticleObject,
    );
    local $Kernel::OM = $FailingOM;

    my $FailedResponse = $Operation->Run( TicketNumber => 'T100' );
    Assert( $FailedResponse->{Success}, 'metadata lookup failure still uses safe transport success' );
    Assert( @{ $FailedResponse->{Data}->{Tickets} } == 0, 'failed count does not return a ticket with a false zero' );
    Assert(
        grep { $_ eq 'Article attachment metadata count failed.' } @{ $FailedResponse->{Data}->{Warnings} },
        'failed count returns a clear warning',
    );
}

print "PASS: inline attachment count regression checks\n";
