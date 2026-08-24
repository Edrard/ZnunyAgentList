#!/usr/bin/env perl

use strict;
use warnings;

use JSON::PP qw(encode_json);
use MIME::Base64 qw(decode_base64);

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

use Kernel::GenericInterface::Operation::Ticket::Get;
use Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

sub Assert {
    my ( $Condition, $Message ) = @_;

    die "FAIL: $Message\n" if !$Condition;
}

{
    package Test::Ticket;

    sub TicketIDLookup {
        my ( $Self, %Param ) = @_;

        return 700 if $Param{TicketNumber} && $Param{TicketNumber} eq 'T700';
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
    package Test::ArticleBackend;

    sub new {
        my ( $Class, %Param ) = @_;

        return bless \%Param, $Class;
    }

    sub ArticleGet {
        my ( $Self, %Param ) = @_;

        my $Article = $Self->{Articles}->{ $Param{ArticleID} } || {};
        return %{$Article};
    }
}

{
    package Test::Article;

    sub new {
        my ( $Class, %Param ) = @_;

        return bless {
            %Param,
            ListCalls        => 0,
            SyncListCalls    => 0,
            DisplayListCalls => 0,
            BackendCalls     => 0,
            IndexCalls       => 0,
            AttachmentCalls  => 0,
            IndexRequests    => [],
            AttachmentRequests => [],
        }, $Class;
    }

    sub ArticleList {
        my ( $Self, %Param ) = @_;

        $Self->{ListCalls}++;

        my $DisplayFlow = 0;
        LEVEL:
        for my $Level ( 1 .. 20 ) {
            my @Caller = caller($Level);
            last LEVEL if !@Caller;
            if ( ( $Caller[3] || q{} ) =~ m{::TicketArticlesData\z} ) {
                $DisplayFlow = 1;
                last LEVEL;
            }
        }

        if ($DisplayFlow) {
            $Self->{DisplayListCalls}++;
        }
        else {
            $Self->{SyncListCalls}++;
        }
        return if $Self->{FailList};

        my $Articles = $Self->{MetaArticles}->{ $Param{TicketID} } || [];
        return @{$Articles};
    }

    sub BackendForArticle {
        my ( $Self, %Param ) = @_;

        $Self->{BackendCalls}++;
        return if $Self->{FailBackend};

        return Test::ArticleBackend->new(
            Articles => $Self->{ArticleData},
        );
    }

    sub ArticleAttachmentIndex {
        my ( $Self, %Param ) = @_;

        $Self->{IndexCalls}++;
        push @{ $Self->{IndexRequests} }, { %Param };
        die 'forced index failure' if $Self->{FailIndex};

        my $Index = $Param{OnlyHTMLBody}
            ? ( $Self->{HTMLIndexes}->{ $Param{ArticleID} } || {} )
            : ( $Self->{Indexes}->{ $Param{ArticleID} } || {} );
        return %{$Index};
    }

    sub ArticleAttachment {
        my ( $Self, %Param ) = @_;

        $Self->{AttachmentCalls}++;
        push @{ $Self->{AttachmentRequests} }, { %Param };
        die 'forced attachment failure' if $Self->{FailAttachment};

        my $Attachment = $Self->{Attachments}->{ $Param{ArticleID} }->{ $Param{FileID} } || {};
        return %{$Attachment};
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

my $HTML = join q{},
    "<html>\r\n",
    "<body>\n",
    "<p>Example raw bytes: \xD0\x9F \xE2\x82\xAC \xC3\xB1</p>\r\n",
    "<img src=\"cid:inline-alpha\">\n",
    "<p>Text between inline references keeps source ordering and line endings intact.</p>\r\n",
    "<img src=\"cid:inline-beta\">\n",
    "<p>Long enough to force wrapped output if MIME::Base64 default wrapping were used.</p>\r\n",
    "</body></html>\n";

my $ArticleObject = Test::Article->new(
    MetaArticles => {
        700 => [
            { TicketID => 700, ArticleID => 30 },
            { TicketID => 700, ArticleID => 10 },
            { TicketID => 700, ArticleID => 20 },
        ],
    },
    ArticleData => {
        30 => {
            TicketID               => 700,
            ArticleID              => 30,
            ArticleNumber          => 1,
            From                   => 'sender@example.com',
            To                     => 'recipient@example.com',
            Subject                => 'HTML article',
            Body                   => 'Plain text fallback body.',
            ContentType            => 'text/plain; charset=utf-8',
            Charset                => 'utf-8',
            MimeType               => 'text/plain',
            SenderTypeID           => 1,
            SenderType             => 'agent',
            CommunicationChannelID => 1,
            CommunicationChannel   => 'Email',
            IsVisibleForCustomer   => 1,
            IncomingTime           => 1800000000,
            CreateTime             => '2026-01-01 10:00:00',
        },
        10 => {
            TicketID               => 700,
            ArticleID              => 10,
            ArticleNumber          => 2,
            Subject                => 'Plain article',
            Body                   => 'Plain text body.',
            ContentType            => 'text/plain; charset=utf-8',
            Charset                => 'utf-8',
            MimeType               => 'text/plain',
            SenderTypeID           => 1,
            SenderType             => 'agent',
            CommunicationChannelID => 1,
            CommunicationChannel   => 'Email',
            IsVisibleForCustomer   => 0,
            IncomingTime           => 1800000001,
            CreateTime             => '2026-01-01 10:01:00',
        },
        20 => {
            TicketID               => 700,
            ArticleID              => 20,
            ArticleNumber          => 3,
            Subject                => 'Non HTML attachment',
            Body                   => 'Attachment body.',
            ContentType            => 'text/plain; charset=utf-8',
            Charset                => 'utf-8',
            MimeType               => 'text/plain',
            SenderTypeID           => 1,
            SenderType             => 'agent',
            CommunicationChannelID => 1,
            CommunicationChannel   => 'Email',
            IsVisibleForCustomer   => 0,
            IncomingTime           => 1800000002,
            CreateTime             => '2026-01-01 10:02:00',
        },
    },
    Indexes => {
        30 => {
            1 => {
                Disposition => 'inline',
                ContentType => 'text/plain; charset=utf-8',
                Filename    => 'plain-body.txt',
            },
            2 => {
                Disposition => 'inline',
                ContentType => 'text/html; charset=utf-8',
                Filename    => 'html-body.html',
            },
            3 => {
                Disposition => 'inline',
                ContentType => 'image/png',
                Filename    => 'inline-alpha.png',
            },
            4 => {
                Disposition => 'attachment',
                ContentType => 'application/pdf',
                Filename    => 'contract.pdf',
            },
        },
    },
    HTMLIndexes => {
        30 => {
            2 => {
                Disposition => 'inline',
                ContentType => 'text/html; charset=utf-8',
                Filename    => 'html-body.html',
            },
        },
        10 => {},
        20 => {
            4 => {
                Disposition => 'inline',
                ContentType => 'application/pdf',
                Filename    => 'file-4',
            },
            5 => {
                Disposition => 'inline',
                ContentType => 'image/png',
                Filename    => 'inline-alpha.png',
            },
            6 => {
                Disposition => 'inline',
                ContentType => 'text/plain',
                Filename    => 'file-6',
            },
            7 => {
                Disposition => 'inline',
                ContentType => 'text/html/extra',
                Filename    => 'file-7',
            },
        },
    },
    Attachments => {
        30 => {
            2 => {
                ContentType => 'text/html; charset=utf-8',
                Content     => $HTML,
            },
        },
        20 => {
            5 => {
                ContentType => 'image/png',
                Content     => 'INLINE_IMAGE_BYTES',
            },
            6 => {
                ContentType => 'application/pdf',
                Content     => 'PDF_BYTES',
            },
        },
    },
);

my $OM = Test::OM->new(
    'Kernel::System::Ticket'          => bless( {}, 'Test::Ticket' ),
    'Kernel::System::Ticket::Article' => $ArticleObject,
);

sub AssertLightweightResponse {
    my ( $Operation, $ArticleObject, $Label, %Param ) = @_;

    my $DisplayListCalls = $ArticleObject->{DisplayListCalls};
    my $BackendCalls     = $ArticleObject->{BackendCalls};
    my $IndexCalls       = $ArticleObject->{IndexCalls};
    my $AttachmentCalls  = $ArticleObject->{AttachmentCalls};

    my $Response = $Operation->Run(%Param);

    Assert( $Response->{Success}, "$Label returns transport success" );
    Assert( $Response->{Data}->{Found}, "$Label finds the ticket" );
    Assert( !exists $Response->{Data}->{Articles}, "$Label has no top-level Articles" );
    Assert( !exists $Response->{Data}->{Ticket}->{Articles}, "$Label does not nest Articles in Ticket" );
    Assert( $ArticleObject->{DisplayListCalls} == $DisplayListCalls, "$Label does not call ArticleList for article display" );
    Assert( $ArticleObject->{BackendCalls} == $BackendCalls, "$Label does not load article bodies" );
    Assert( $ArticleObject->{IndexCalls} == $IndexCalls, "$Label does not call ArticleAttachmentIndex" );
    Assert( $ArticleObject->{AttachmentCalls} == $AttachmentCalls, "$Label does not call ArticleAttachment" );

    return $Response;
}

sub ArticleHasForbiddenAttachmentLeak {
    my ($Article) = @_;

    return 1 if exists $Article->{Attachment};
    return 1 if exists $Article->{Attachments};

    KEY:
    for my $Key ( keys %{$Article} ) {
        next KEY if $Key eq 'HTMLBodyContent';
        next KEY if $Key eq 'HTMLBodyContentType';

        my $Value = defined $Article->{$Key} ? "$Article->{$Key}" : q{};
        return 1 if $Key =~ m{\A(?:Filename|Filesize|ContentID|Disposition|FileID|Content|ContentAlternative)\z};
        return 1 if $Value =~ m{(?:plain-body\.txt|html-body\.html|inline-alpha\.png|inline-beta\.png|contract\.pdf|file-4|file-6|file-7|INLINE_IMAGE_BYTES|PDF_BYTES)};
    }

    return 1 if ( $Article->{HTMLBodyContent} // q{} ) =~ m{(?:INLINE_IMAGE_BYTES|PDF_BYTES|contract\.pdf|inline-alpha\.png|inline-beta\.png)};
    return 1 if ( $Article->{HTMLBodyContentType} // q{} ) =~ m{(?:INLINE_IMAGE_BYTES|PDF_BYTES|contract\.pdf|inline-alpha\.png|inline-beta\.png)};

    return 0;
}

sub AssertHTMLBodyJSONContract {
    my ( $Article, $Label, $HTML ) = @_;

    Assert( exists $Article->{HTMLBodyAvailable}, "$Label has HTMLBodyAvailable" );

    my $EncodedFlag = encode_json( { HTMLBodyAvailable => $Article->{HTMLBodyAvailable} } );
    Assert(
        $EncodedFlag =~ m{"HTMLBodyAvailable":(?:0|1)} && $EncodedFlag !~ m{"HTMLBodyAvailable":"[01]"|"HTMLBodyAvailable":(?:true|false|null)},
        "$Label serializes HTMLBodyAvailable as JSON integer 0 or 1",
    );

    if ( $Article->{HTMLBodyAvailable} == 1 ) {
        Assert( exists $Article->{HTMLBodyContent}, "$Label with HTMLBodyAvailable=1 has HTMLBodyContent" );
        Assert( exists $Article->{HTMLBodyContentType}, "$Label with HTMLBodyAvailable=1 has HTMLBodyContentType" );
        Assert( $Article->{HTMLBodyContent} !~ /[\r\n]/, "$Label HTMLBodyContent has no CR or LF line wrapping" );
        Assert( decode_base64( $Article->{HTMLBodyContent} ) eq $HTML, "$Label HTMLBodyContent decodes to original bytes" );
    }
    else {
        Assert( $Article->{HTMLBodyAvailable} == 0, "$Label HTMLBodyAvailable value is 0 or 1" );
        Assert( !exists $Article->{HTMLBodyContent}, "$Label with HTMLBodyAvailable=0 has no HTMLBodyContent" );
        Assert( !exists $Article->{HTMLBodyContentType}, "$Label with HTMLBodyAvailable=0 has no HTMLBodyContentType" );
    }
}

sub AssertEnrichedArticlePayload {
    my ( $Articles, $Label, $HTML ) = @_;

    Assert( ref $Articles eq 'ARRAY' && @{$Articles} == 3, "$Label returns three top-level article objects" );
    Assert(
        join( q{,}, map { $_->{ArticleID} } @{$Articles} ) eq '30,10,20',
        "$Label preserves native ArticleList order after HTML enrichment",
    );

    my $HTMLArticle  = $Articles->[0];
    my $PlainArticle = $Articles->[1];
    my $OtherArticle = $Articles->[2];

    AssertHTMLBodyJSONContract( $HTMLArticle, "$Label HTML article", $HTML );
    AssertHTMLBodyJSONContract( $PlainArticle, "$Label plain article", $HTML );
    AssertHTMLBodyJSONContract( $OtherArticle, "$Label non-HTML article", $HTML );

    Assert( $HTMLArticle->{Body} eq 'Plain text fallback body.', "$Label Body is preserved for HTML article" );
    Assert( $HTMLArticle->{MimeType} eq 'text/plain', "$Label MimeType is preserved for HTML article" );
    Assert( $HTMLArticle->{ContentType} eq 'text/plain; charset=utf-8', "$Label ContentType is preserved for HTML article" );
    Assert( $HTMLArticle->{HTMLBodyAvailable} == 1, "$Label HTML body is marked available with Attachments=0" );
    Assert( $HTMLArticle->{HTMLBodyContentType} eq 'text/html; charset=utf-8', "$Label HTML content type including charset is preserved" );
    Assert( length $HTMLArticle->{HTMLBodyContent} > 76, "$Label HTML body base64 fixture exceeds 76 characters" );
    Assert( $HTMLArticle->{HTMLBodyContent} !~ /[\r\n]/, "$Label HTML body base64 has no CR or LF line wrapping" );
    Assert( decode_base64( $HTMLArticle->{HTMLBodyContent} ) eq $HTML, "$Label HTML bytes are preserved exactly" );
    Assert(
        decode_base64( $HTMLArticle->{HTMLBodyContent} ) =~ m{cid:inline-alpha.*cid:inline-beta}s,
        "$Label decoded HTML preserves ordered cid references",
    );

    Assert( $PlainArticle->{HTMLBodyAvailable} == 0, "$Label plain article has no HTML body" );
    Assert( $OtherArticle->{HTMLBodyAvailable} == 0, "$Label non-HTML MIME types are not mistaken for HTML body" );
    Assert( !ArticleHasForbiddenAttachmentLeak($HTMLArticle), "$Label HTML article does not leak normal attachment metadata or content" );
    Assert( !ArticleHasForbiddenAttachmentLeak($PlainArticle), "$Label plain article does not leak normal attachment metadata or content" );
    Assert( !ArticleHasForbiddenAttachmentLeak($OtherArticle), "$Label other article does not leak normal attachment metadata or content" );
    Assert( !grep { /\ADynamicField_/ } keys %{$HTMLArticle}, "$Label DynamicFields=0 does not return dynamic fields" );

    return {
        Order               => join( q{,}, map { $_->{ArticleID} } @{$Articles} ),
        HTMLBodyAvailable   => join( q{,}, map { $_->{HTMLBodyAvailable} } @{$Articles} ),
        HTMLBodyContentType => $HTMLArticle->{HTMLBodyContentType} // q{},
        HTMLBodyContent     => $HTMLArticle->{HTMLBodyContent} // q{},
    };
}

{
    no warnings 'redefine';

    local $Kernel::OM = $OM;
    local *Kernel::GenericInterface::Operation::ZnunyAgentList::Common::AuthenticateReadAgent = sub {
        return ( 1, undef, 2, 'User' );
    };

    my $Operation = bless {}, 'Kernel::GenericInterface::Operation::Ticket::Get';

    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route missing AllArticles', TicketID => 700 );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route AllArticles=0', TicketID => 700, AllArticles => 0, DynamicFields => 0, Attachments => 0 );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route AllArticles string zero', TicketID => 700, AllArticles => '0' );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route AllArticles empty string', TicketID => 700, AllArticles => q{} );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route AllArticles=false', TicketID => 700, AllArticles => 'false' );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route AllArticles=no', TicketID => 700, AllArticles => 'no' );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketID route AllArticles=off', TicketID => 700, AllArticles => 'off' );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketNumber route missing AllArticles', TicketNumber => 'T700' );
    AssertLightweightResponse( $Operation, $ArticleObject, 'Ticket::Get TicketNumber route AllArticles=0', TicketNumber => 'T700', AllArticles => 0, DynamicFields => 0, Attachments => 0 );

    my $Response  = $Operation->Run( TicketID => 700, AllArticles => 1, DynamicFields => 0, Attachments => 0 );
    my $Ticket    = $Response->{Data}->{Ticket};
    my $Articles  = $Response->{Data}->{Articles};

    Assert( $Response->{Success}, 'Ticket::Get AllArticles=1 returns transport success' );
    Assert( $Response->{Data}->{Found}, 'Ticket::Get AllArticles=1 finds the ticket' );
    Assert( !exists $Ticket->{Articles}, 'Ticket::Get AllArticles=1 does not nest Articles in Ticket' );
    Assert( $Ticket->{TicketID} == 700, 'Ticket::Get TicketID route resolves expected ticket ID' );
    Assert( $Ticket->{TicketNumber} eq 'T700', 'Ticket::Get TicketID route returns expected ticket number' );

    my $TicketIDContract = AssertEnrichedArticlePayload(
        $Articles,
        'Ticket::Get TicketID route AllArticles=1',
        $HTML,
    );

    Assert( $ArticleObject->{AttachmentCalls} == 1, 'ArticleAttachment is called only for selected HTML body content' );
    Assert( @{ $ArticleObject->{AttachmentRequests} } == 1, 'only one attachment content request is made' );
    Assert( $ArticleObject->{AttachmentRequests}->[0]->{ArticleID} == 30, 'HTML content request uses the HTML article' );
    Assert( $ArticleObject->{AttachmentRequests}->[0]->{FileID} == 2, 'HTML content request uses only the selected HTML FileID' );
    Assert(
        scalar( grep { !$_->{OnlyHTMLBody} } @{ $ArticleObject->{IndexRequests} } ) == 0,
        'Ticket::Get AllArticles=1 calls ArticleAttachmentIndex only with OnlyHTMLBody',
    );
    my $NumberResponse = $Operation->Run( TicketNumber => 'T700', AllArticles => 1, DynamicFields => 0, Attachments => 0 );
    my $NumberTicket   = $NumberResponse->{Data}->{Ticket};
    my $NumberArticles = $NumberResponse->{Data}->{Articles};

    Assert( $NumberResponse->{Success}, 'Ticket::Get TicketNumber route AllArticles=1 returns transport success' );
    Assert( $NumberResponse->{Data}->{Found}, 'Ticket::Get TicketNumber route AllArticles=1 finds the ticket' );
    Assert( $NumberTicket->{TicketID} == 700, 'Ticket::Get TicketNumber route resolves the same ticket ID' );
    Assert( $NumberTicket->{TicketNumber} eq 'T700', 'Ticket::Get TicketNumber route returns the same ticket number' );

    my $TicketNumberContract = AssertEnrichedArticlePayload(
        $NumberArticles,
        'Ticket::Get TicketNumber route AllArticles=1',
        $HTML,
    );
    Assert( $TicketNumberContract->{Order} eq $TicketIDContract->{Order}, 'TicketID and TicketNumber routes return equivalent article order' );
    Assert( $TicketNumberContract->{HTMLBodyAvailable} eq $TicketIDContract->{HTMLBodyAvailable}, 'TicketID and TicketNumber routes return equivalent HTMLBodyAvailable contract' );
    Assert( $TicketNumberContract->{HTMLBodyContentType} eq $TicketIDContract->{HTMLBodyContentType}, 'TicketID and TicketNumber routes return equivalent HTMLBodyContentType' );
    Assert( $TicketNumberContract->{HTMLBodyContent} eq $TicketIDContract->{HTMLBodyContent}, 'TicketID and TicketNumber routes return equivalent HTMLBodyContent' );

    my $FailingArticleObject = Test::Article->new(
        MetaArticles => {
            700 => [ { TicketID => 700, ArticleID => 30 } ],
        },
        ArticleData => {
            30 => $ArticleObject->{ArticleData}->{30},
        },
        HTMLIndexes    => $ArticleObject->{HTMLIndexes},
        Attachments    => $ArticleObject->{Attachments},
        FailAttachment => 1,
    );
    my $FailingOM = Test::OM->new(
        'Kernel::System::Ticket'          => bless( {}, 'Test::Ticket' ),
        'Kernel::System::Ticket::Article' => $FailingArticleObject,
    );
    local $Kernel::OM = $FailingOM;

    my $FailedResponse = $Operation->Run( TicketID => 700, AllArticles => 1 );
    Assert( $FailedResponse->{Success}, 'HTML content failure still uses safe transport success' );
    Assert( ref $FailedResponse->{Data}->{Articles} eq 'ARRAY', 'HTML content failure returns safe article list shape' );
    Assert(
        grep { $_ eq 'HTML body attachment content lookup failed.' } @{ $FailedResponse->{Data}->{Warnings} },
        'HTML content failure returns a clear warning',
    );
}

print "PASS: HTML body article regression checks\n";
