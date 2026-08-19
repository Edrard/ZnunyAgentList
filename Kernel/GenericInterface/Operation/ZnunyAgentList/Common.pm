package Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64);

our $ObjectManagerDisabled = 1;

use constant PACKAGE_NAME    => 'ZnunyAgentList';
use constant PACKAGE_VERSION => '1.6.0';
use constant AUTH_ERROR_CODE => 'ZnunyAgentList.AuthFail';
use constant WRITE_ERROR_CODE => 'ZnunyAgentList.WriteForbidden';

sub New {
    my ( $Class, $Type, %Param ) = @_;

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

sub AuthenticateAgent {
    my ( $Class, $Self, %Param ) = @_;

    my ( $UserID, $UserType ) = $Self->Auth(%Param);

    if ( !$UserID || !defined $UserType || $UserType ne 'User' ) {
        return $Class->AuthError($Self);
    }

    my @AllowedGroups = $Class->AllowedGroups;
    if ( !@AllowedGroups ) {
        return $Class->AuthError($Self);
    }

    my $GroupObject = eval { $Kernel::OM->Get('Kernel::System::Group') };
    if ( !$GroupObject ) {
        return $Class->AuthError($Self);
    }

    my %UserGroups = eval {
        reverse $GroupObject->PermissionUserGet(
            UserID => $UserID,
            Type   => 'ro',
        );
    };
    if ($@) {
        return $Class->AuthError($Self);
    }

    for my $GroupName (@AllowedGroups) {
        next if !$GroupName;

        if ( $UserGroups{$GroupName} ) {
            return ( 1, undef, $UserID, $UserType );
        }
    }

    return $Class->AuthError($Self);
}

sub AuthenticateReadAgent {
    my ( $Class, @Param ) = @_;

    return $Class->AuthenticateAgent(@Param);
}

sub AuthenticateWriteAgent {
    my ( $Class, $Self, %Param ) = @_;

    my ( $UserID, $UserType ) = $Self->Auth(%Param);

    if ( !$UserID || !defined $UserType || $UserType ne 'User' ) {
        return $Class->AuthError($Self);
    }

    if ( !$Class->WriteOperationsEnabled ) {
        return $Class->WriteForbidden($Self);
    }

    my @AllowedGroups = $Class->AllowedWriteGroups;
    if ( !@AllowedGroups ) {
        return $Class->WriteForbidden($Self);
    }

    my $GroupObject = eval { $Kernel::OM->Get('Kernel::System::Group') };
    if ( !$GroupObject ) {
        return $Class->WriteForbidden($Self);
    }

    my %UserGroups = eval {
        reverse $GroupObject->PermissionUserGet(
            UserID => $UserID,
            Type   => 'ro',
        );
    };
    if ($@) {
        return $Class->WriteForbidden($Self);
    }

    for my $GroupName (@AllowedGroups) {
        next if !$GroupName;

        if ( $UserGroups{$GroupName} ) {
            return ( 1, undef, $UserID, $UserType );
        }
    }

    return $Class->WriteForbidden($Self);
}

sub AuthError {
    my ( $Class, $Self ) = @_;

    return (
        0,
        $Self->ReturnError(
            ErrorCode    => AUTH_ERROR_CODE,
            ErrorMessage => 'ZnunyAgentList: Authentication failed.',
        ),
    );
}

sub AllowedGroups {
    my ($Class) = @_;

    return $Class->_ConfiguredGroups('ZnunyAgentList::AllowedGroups');
}

sub WriteForbidden {
    my ( $Class, $Self ) = @_;

    return (
        0,
        $Self->ReturnError(
            ErrorCode    => WRITE_ERROR_CODE,
            ErrorMessage => 'ZnunyAgentList: Write operation is not allowed.',
        ),
    );
}

sub WriteOperationsEnabled {
    my ($Class) = @_;

    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return 0 if !$ConfigObject;

    return $ConfigObject->Get('ZnunyAgentList::EnableTicketWriteOperations') ? 1 : 0;
}

sub AllowedWriteGroups {
    my ($Class) = @_;

    return $Class->_ConfiguredGroups('ZnunyAgentList::AllowedWriteGroups');
}

sub _ConfiguredGroups {
    my ( $Class, $SettingName ) = @_;

    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return if !$ConfigObject;

    my $ConfiguredGroups = $ConfigObject->Get($SettingName);
    my @Groups;

    if ( ref $ConfiguredGroups eq 'ARRAY' ) {
        @Groups = @{$ConfiguredGroups};
    }
    elsif ( !ref $ConfiguredGroups && defined $ConfiguredGroups ) {
        @Groups = split /[,;]/, $ConfiguredGroups;
    }
    else {
        return;
    }

    my %Seen;
    return grep { $_ ne q{} && !$Seen{$_}++ } map { $Class->SafeString( $_, 100 ) } @Groups;
}

sub Param {
    my ( $Class, $ParamRef, $Name ) = @_;

    return if !$ParamRef || !$Name;

    if ( exists $ParamRef->{$Name} ) {
        return $ParamRef->{$Name};
    }

    if ( ref $ParamRef->{Data} eq 'HASH' && exists $ParamRef->{Data}->{$Name} ) {
        return $ParamRef->{Data}->{$Name};
    }

    return;
}

sub CleanString {
    my ( $Class, $Value, $MaxLength ) = @_;

    return $Class->SafeString( $Value, $MaxLength || 255 );
}

sub SafeString {
    my ( $Class, $Value, $MaxLength ) = @_;

    return q{} if !defined $Value || ref $Value;

    $MaxLength ||= 255;
    $MaxLength = 255 if $MaxLength !~ m{\A[1-9][0-9]*\z};

    $Value =~ s/[\x00-\x1f\x7f]//g;

    $Value =~ s/^\s+//;
    $Value =~ s/\s+$//;

    if ( length $Value > $MaxLength ) {
        $Value = substr $Value, 0, $MaxLength;
    }

    return $Value;
}

sub SafeIdentifier {
    my ( $Class, $Value, $MaxLength ) = @_;

    my $String = $Class->SafeString( $Value, $MaxLength || 255 );
    return q{} if $String eq q{};

    return $String;
}

sub MeaningfulSearchLength {
    my ( $Class, $Value ) = @_;

    my $Search = $Class->SafeString( $Value, 100 );
    $Search =~ s/[*%?]//g;
    $Search =~ s/^\s+//;
    $Search =~ s/\s+$//;

    return length $Search;
}

sub FirstToken {
    my ( $Class, $Value, $MaxLength ) = @_;

    my $String = $Class->SafeString( $Value, 255 );
    return q{} if $String eq q{};

    my ($Token) = split /\s+/, $String;

    return $Class->SafeString( $Token, $MaxLength || 64 );
}

sub PositiveInt {
    my ( $Class, $Value ) = @_;

    $Value = $Class->SafeString( $Value, 32 );

    return if !defined $Value || $Value !~ m{\A[1-9][0-9]*\z};

    return 0 + $Value;
}

sub Boolean {
    my ( $Class, $Value ) = @_;

    my $Boolean = lc $Class->SafeString( $Value, 16 );

    return 1 if $Boolean =~ m{\A(?:1|true|yes|on)\z};
    return 0 if $Boolean =~ m{\A(?:0|false|no|off)\z};

    return 0;
}

sub Limit {
    my ( $Class, $Value, $Default, $Max ) = @_;

    my $Limit = $Class->PositiveInt($Value) || $Default || 20;
    $Max ||= 50;

    return $Limit > $Max ? $Max : $Limit;
}

sub SearchLimit {
    my ( $Class, $Value ) = @_;

    return $Class->Limit( $Value, 50, 100 );
}

sub SearchOffset {
    my ( $Class, $OffsetValue, $PageValue, $Limit ) = @_;

    my $Offset = $Class->PositiveInt($OffsetValue);
    return $Offset if defined $Offset;

    my $Page = $Class->PositiveInt($PageValue) || 1;
    $Limit ||= 50;

    return ( $Page - 1 ) * $Limit;
}

sub SafeDate {
    my ( $Class, $Value ) = @_;

    my $Date = $Class->SafeString( $Value, 32 );
    return q{} if $Date eq q{};

    return $Date if $Date =~ m{\A[0-9]{4}-[0-9]{2}-[0-9]{2}(?: [0-9]{2}:[0-9]{2}:[0-9]{2})?\z};

    return q{};
}

sub SortBy {
    my ( $Class, $Value ) = @_;

    my $SortBy = $Class->SafeString( $Value, 32 ) || 'Created';
    my %Allowed = map { $_ => 1 } qw(TicketID TicketNumber Created Changed State Priority Queue Owner Title);

    return $Allowed{$SortBy} ? $SortBy : 'Created';
}

sub SortDirection {
    my ( $Class, $Value ) = @_;

    my $Direction = uc $Class->SafeString( $Value, 8 );

    return $Direction eq 'ASC' ? 'ASC' : 'DESC';
}

sub TicketLookup {
    my ( $Class, %Param ) = @_;

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return if !$TicketObject;

    my $TicketID = $Class->PositiveInt( $Param{TicketID} );

    if ( !$TicketID && defined $Param{TicketNumber} ) {
        my $TicketNumber = $Class->SafeString( $Param{TicketNumber}, 64 );
        if ($TicketNumber) {
            $TicketID = eval {
                $TicketObject->TicketIDLookup(
                    TicketNumber => $TicketNumber,
                    UserID       => $Param{UserID} || 1,
                );
            };
        }
    }

    return if !$TicketID;

    my %Ticket = eval {
        $TicketObject->TicketGet(
            TicketID      => $TicketID,
            UserID        => $Param{UserID} || 1,
            DynamicFields => 0,
        );
    };

    return if $@ || !$Ticket{TicketID};

    return $Class->SafeTicketData(%Ticket);
}

sub SafeTicketData {
    my ( $Class, %Ticket ) = @_;

    my $SafeTicket = {
        TicketID       => 0 + ( $Ticket{TicketID}       || 0 ),
        TicketNumber   => $Ticket{TicketNumber}         // q{},
        Title          => $Ticket{Title}                // q{},
        QueueID        => 0 + ( $Ticket{QueueID}        || 0 ),
        Queue          => $Ticket{Queue}                // q{},
        OwnerID        => 0 + ( $Ticket{OwnerID}        || 0 ),
        Owner          => $Ticket{Owner}                // q{},
        ResponsibleID  => 0 + ( $Ticket{ResponsibleID}  || 0 ),
        Responsible    => $Ticket{Responsible}          // q{},
        LockID         => 0 + ( $Ticket{LockID}         || 0 ),
        Lock           => $Ticket{Lock}                 // q{},
        CustomerID     => $Ticket{CustomerID}           // q{},
        CustomerUserID => $Ticket{CustomerUserID}       // q{},
        CustomerUser   => $Ticket{CustomerUser}         // q{},
        StateID        => 0 + ( $Ticket{StateID}        || 0 ),
        State          => $Ticket{State}                // q{},
        StateType      => $Ticket{StateType} || $Ticket{StateTypeName} || q{},
        PriorityID     => 0 + ( $Ticket{PriorityID}     || 0 ),
        Priority       => $Ticket{Priority}             // q{},
        TypeID         => 0 + ( $Ticket{TypeID}         || 0 ),
        Type           => $Ticket{Type}                 // q{},
        ServiceID      => 0 + ( $Ticket{ServiceID}      || 0 ),
        Service        => $Ticket{Service}              // q{},
        SLAID          => 0 + ( $Ticket{SLAID}          || 0 ),
        SLA            => $Ticket{SLA}                  // q{},
        Created        => $Ticket{Created} || $Ticket{CreateTime} || q{},
        Changed        => $Ticket{Changed} || $Ticket{ChangeTime} || q{},
    };

    if ( defined $Ticket{CloseTime} && $Ticket{CloseTime} ne q{} ) {
        $SafeTicket->{CloseTime} = $Ticket{CloseTime};
    }
    elsif ( defined $Ticket{Closed} && $Ticket{Closed} ne q{} ) {
        $SafeTicket->{Closed} = $Ticket{Closed};
    }

    if ( !$SafeTicket->{StateType} && $SafeTicket->{StateID} ) {
        my $StateTypeData = $Class->StateTypeData( StateID => $SafeTicket->{StateID} ) || {};
        $SafeTicket->{StateType} = $StateTypeData->{StateType} || q{};
    }

    my $ArticleSyncData = $Class->TicketArticleSyncData(
        TicketID => $SafeTicket->{TicketID},
    );

    $SafeTicket->{ArticleCount}       = $ArticleSyncData->{ArticleCount};
    $SafeTicket->{LastArticleID}      = $ArticleSyncData->{LastArticleID};
    $SafeTicket->{LastArticleCreated} = $ArticleSyncData->{LastArticleCreated};
    $SafeTicket->{SyncFingerprint}    = sha256_hex(
        join "\x1e",
        $SafeTicket->{TicketID},
        $SafeTicket->{TicketNumber},
        $SafeTicket->{Changed},
        $SafeTicket->{ArticleCount},
        $SafeTicket->{LastArticleID},
        $SafeTicket->{LastArticleCreated},
    );

    return $SafeTicket;
}

sub TicketArticleSyncData {
    my ( $Class, %Param ) = @_;

    my $SyncData = {
        ArticleCount       => 0,
        LastArticleID      => 0,
        LastArticleCreated => q{},
    };

    my $TicketID = $Class->PositiveInt( $Param{TicketID} );
    return $SyncData if !$TicketID;

    my $ArticleObject = eval { $Kernel::OM->Get('Kernel::System::Ticket::Article') };
    return $SyncData if !$ArticleObject;

    my @Articles = eval {
        $ArticleObject->ArticleList(
            TicketID => $TicketID,
        );
    };
    return $SyncData if $@ || !@Articles;

    my @SafeArticles;
    for my $Article (@Articles) {
        next if ref $Article ne 'HASH';

        my $ArticleID = $Class->PositiveInt( $Article->{ArticleID} );
        next if !$ArticleID;

        push @SafeArticles, {
            ArticleID => $ArticleID,
            Created   => $Class->SafeString( $Article->{CreateTime} || $Article->{Created}, 32 ),
        };
    }

    return $SyncData if !@SafeArticles;

    @SafeArticles = sort {
        $a->{ArticleID} <=> $b->{ArticleID}
            || $a->{Created} cmp $b->{Created}
    } @SafeArticles;

    my $LastArticle = $SafeArticles[-1];

    $SyncData->{ArticleCount}       = 0 + scalar @SafeArticles;
    $SyncData->{LastArticleID}      = 0 + $LastArticle->{ArticleID};
    $SyncData->{LastArticleCreated} = $LastArticle->{Created};

    return $SyncData;
}

sub StateTypeData {
    my ( $Class, %Param ) = @_;

    my $StateObject = eval { $Kernel::OM->Get('Kernel::System::State') };
    return if !$StateObject;

    my %StateData;

    if ( $Param{StateID} ) {
        %StateData = eval { $StateObject->StateGet( ID => $Param{StateID} ) };
    }
    elsif ( $Param{State} ) {
        %StateData = eval { $StateObject->StateGet( Name => $Param{State} ) };
    }

    return if $@ || !%StateData;

    return {
        StateTypeID => 0 + ( $StateData{TypeID} || $StateData{StateTypeID} || 0 ),
        StateType   => $StateData{TypeName} || $StateData{StateType} || q{},
    };
}

sub ArticleKindData {
    my ( $Class, $Kind ) = @_;

    $Kind = $Class->SafeString( $Kind, 32 );

    my %Mapping = (
        reply => {
            Kind                 => 'reply',
            ChannelName          => 'Email',
            SenderType           => 'agent',
            IsVisibleForCustomer => 1,
            HistoryType          => 'EmailCustomer',
            HistoryComment       => 'Controlled public reply',
        },
        internal_note => {
            Kind                 => 'internal_note',
            ChannelName          => 'Internal',
            SenderType           => 'agent',
            IsVisibleForCustomer => 0,
            HistoryType          => 'AddNote',
            HistoryComment       => 'Controlled internal note',
        },
    );

    return $Mapping{$Kind};
}

sub SafeContentType {
    my ( $Class, $Value ) = @_;

    my $ContentType = $Class->SafeString( $Value, 120 );
    return 'text/plain; charset=utf8' if $ContentType eq q{};

    return $ContentType if $ContentType =~ m{\A[-+./;=a-zA-Z0-9_ ]+\z};

    return 'text/plain; charset=utf8';
}

sub NormalizeContentID {
    my ( $Class, $Value ) = @_;

    my $ContentID = $Class->SafeString( $Value, 255 );
    $ContentID =~ s{\Acid:}{}i;
    $ContentID =~ s{^\s+}{};
    $ContentID =~ s{\s+$}{};

    if ( $ContentID =~ m{\A<[^<>]+>\z} ) {
        $ContentID =~ s{\A<}{};
        $ContentID =~ s{>\z}{};
    }

    return q{} if $ContentID =~ m{[<>]};

    return $ContentID;
}

sub InlineImageContentType {
    my ( $Class, $Value ) = @_;

    my $ContentType = lc $Class->SafeContentType($Value);
    $ContentType =~ s{\s*;.*\z}{};

    return 'image/jpeg' if $ContentType eq 'image/jpg';

    my %Allowed = map { $_ => 1 } qw(image/png image/jpeg image/gif image/webp);

    return $Allowed{$ContentType} ? $ContentType : q{};
}

sub InlineAttachmentData {
    my ( $Class, %Param ) = @_;

    my $TicketID  = $Class->PositiveInt( $Param{TicketID} );
    my $ArticleID = $Class->PositiveInt( $Param{ArticleID} );
    my $ContentID = $Class->NormalizeContentID( $Param{ContentID} );

    return ( undef, ['TicketID, ArticleID, and ContentID are required.'] )
        if !$TicketID || !$ArticleID || $ContentID eq q{};

    my $Ticket = $Class->TicketLookup(
        TicketID => $TicketID,
        UserID   => $Param{UserID},
    );
    return ( { Found => 0 }, ['Ticket not found.'] ) if !$Ticket;

    my $ArticleObject = eval { $Kernel::OM->Get('Kernel::System::Ticket::Article') };
    return ( undef, ['Article API is unavailable.'] ) if !$ArticleObject;

    my @Articles = eval {
        $ArticleObject->ArticleList(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
        );
    };
    return ( undef, ['Article lookup failed.'] ) if $@;
    return ( { Found => 0 }, ['Article not found for ticket.'] ) if !@Articles;

    my %Index = eval {
        $ArticleObject->ArticleAttachmentIndex(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
        );
    };
    return ( undef, ['Attachment index lookup failed.'] ) if $@;

    my @Matches;
    for my $FileID ( sort { $a <=> $b } keys %Index ) {
        next if !$FileID || ref $Index{$FileID} ne 'HASH';
        next if $Class->NormalizeContentID( $Index{$FileID}->{ContentID} ) ne $ContentID;

        push @Matches, $FileID;
    }

    return ( { Found => 0 }, ['Inline attachment not found.'] ) if !@Matches;
    return ( undef, ['ContentID is not unique for this article.'] ) if @Matches > 1;

    my $FileID = $Matches[0];
    my %Attachment = eval {
        $ArticleObject->ArticleAttachment(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            FileID    => $FileID,
        );
    };
    return ( undef, ['Attachment content lookup failed.'] ) if $@ || !%Attachment;

    if ( $Class->NormalizeContentID( $Attachment{ContentID} ) ne $ContentID ) {
        return ( undef, ['Attachment ContentID changed during lookup.'] );
    }

    my $SafeContentType = $Class->InlineImageContentType( $Attachment{ContentType} );
    return ( undef, ['Attachment is not an allowed inline image type.'] )
        if !$SafeContentType;

    return (
        {
            Found       => 1,
            TicketID    => $Ticket->{TicketID},
            ArticleID   => 0 + $ArticleID,
            FileID      => 0 + $FileID,
            Filename    => $Class->SafeString( $Attachment{Filename}, 255 ),
            ContentType => $SafeContentType,
            ContentID   => $ContentID,
            Disposition => $Class->SafeString( $Attachment{Disposition}, 32 ),
            FilesizeRaw => 0 + ( $Attachment{FilesizeRaw} || 0 ),
            Content     => encode_base64( $Attachment{Content} // q{}, q{} ),
        },
        [],
    );
}

sub SafeEmail {
    my ( $Class, $Value ) = @_;

    my $Email = $Class->SafeString( $Value, 255 );
    return q{} if $Email eq q{};
    return q{} if $Email =~ m{[*%?]};

    return $Email if $Email =~ m{\A[^@\s]+@[^@\s]+\.[^@\s]+\z};

    return q{};
}

sub CustomerCompanyData {
    my ( $Class, %Company ) = @_;

    return {
        CustomerID          => $Company{CustomerID} // q{},
        CustomerCompanyName => $Company{CustomerCompanyName} // q{},
    };
}

sub CustomerCompanyLookup {
    my ( $Class, $CustomerID ) = @_;

    $CustomerID = $Class->SafeString( $CustomerID, 255 );
    return if $CustomerID eq q{};

    my $CustomerCompanyObject = eval { $Kernel::OM->Get('Kernel::System::CustomerCompany') };
    return if !$CustomerCompanyObject;

    my %Company = eval {
        $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );
    };
    return if $@ || !$Company{CustomerID};
    return if $Company{ValidID} && $Company{ValidID} != 1;

    return $Class->CustomerCompanyData(%Company);
}

sub CustomerCompanyListData {
    my ( $Class, %Param ) = @_;

    return ( [], ['Search must be a scalar string.'] ) if ref $Param{Search};

    my $Search = $Class->SafeString( $Param{Search}, 100 );
    my $Limit  = $Class->Limit( $Param{Limit}, 50, 100 );

    my $CustomerCompanyObject = eval { $Kernel::OM->Get('Kernel::System::CustomerCompany') };
    return ( [], ['Customer company API is unavailable.'] ) if !$CustomerCompanyObject;

    my %CompanyList = eval {
        $Search eq q{}
            ? $CustomerCompanyObject->CustomerCompanyList(
                Valid => 1,
                Limit => $Limit,
            )
            : $CustomerCompanyObject->CustomerCompanyList(
                Search => $Search,
                Valid  => 1,
                Limit  => $Limit,
            );
    };
    return ( [], ['Customer company lookup failed.'] ) if $@;

    my @Companies;
    for my $CustomerID ( sort { lc($a) cmp lc($b) } grep { defined && $_ ne q{} } keys %CompanyList ) {
        my $Company = $Class->CustomerCompanyLookup($CustomerID) || {
            CustomerID          => $CustomerID,
            CustomerCompanyName => $CompanyList{$CustomerID} // q{},
        };
        push @Companies, $Company;
    }

    @Companies = sort {
        lc( $a->{CustomerCompanyName} // q{} ) cmp lc( $b->{CustomerCompanyName} // q{} )
            || lc( $a->{CustomerID} // q{} ) cmp lc( $b->{CustomerID} // q{} )
    } @Companies;

    return ( \@Companies, [] );
}

sub CustomerUserLookupData {
    my ( $Class, %Param ) = @_;

    my $RawLogin = defined $Param{Login} ? $Param{Login} : $Param{CustomerUserLogin};
    my $Login    = $Class->SafeString( $RawLogin, 255 );
    my $Email = $Class->SafeEmail( $Param{Email} );
    my $RawEmail = $Class->SafeString( $Param{Email}, 255 );

    if ( $Login eq q{} && $RawEmail ne q{} && $Email eq q{} ) {
        return ( undef, ['Email must be valid.'] );
    }

    if ( $Login eq q{} && $Email eq q{} ) {
        return ( undef, ['Login or Email is required.'] );
    }

    my $CustomerUserObject = eval { $Kernel::OM->Get('Kernel::System::CustomerUser') };
    return ( undef, ['Customer user API is unavailable.'] ) if !$CustomerUserObject;

    if ($Login) {
        my %UserData = eval { $CustomerUserObject->CustomerUserDataGet( User => $Login ) };
        return ( undef, ['Customer user lookup failed.'] ) if $@;
        return ( $Class->CustomerUserData(%UserData), [] )
            if $UserData{UserLogin};
    }

    if ($Email) {
        my %SearchResult = eval {
            $CustomerUserObject->CustomerSearch(
                PostMasterSearch => $Email,
                Valid            => 1,
                Limit            => 50,
            );
        };
        return ( undef, ['Customer user email lookup failed.'] ) if $@;

        my @Matches;
        for my $UserLogin ( sort keys %SearchResult ) {
            my %UserData = eval { $CustomerUserObject->CustomerUserDataGet( User => $UserLogin ) };
            return ( undef, ['Customer user data lookup failed.'] ) if $@;
            next if !$UserData{UserLogin};
            next if lc( $UserData{UserEmail} // q{} ) ne lc $Email;

            push @Matches, $Class->CustomerUserData(%UserData);
        }

        return ( $Matches[0], [] ) if @Matches == 1;
        return ( undef, ['Email matches multiple customer users.'] ) if @Matches > 1;
    }

    return ( undef, [] );
}

sub CustomerUserWriteData {
    my ( $Class, %Param ) = @_;

    my $Data = {
        UserFirstname  => $Class->SafeString( $Param{FirstName}, 100 ),
        UserLastname   => $Class->SafeString( $Param{LastName}, 100 ),
        UserLogin      => $Class->SafeString( $Param{Login}, 255 ),
        UserEmail      => $Class->SafeEmail( $Param{Email} ),
        UserCustomerID => $Class->SafeString( $Param{CustomerID}, 255 ),
    };

    return $Data;
}

sub CustomerUserCreateData {
    my ( $Class, %Param ) = @_;

    my $Data = $Class->CustomerUserWriteData(%Param);
    my @Errors;

    push @Errors, 'Password input is not supported. Use the normal password reset workflow.'
        if $Param{PasswordProvided} || exists $Param{Password} || exists $Param{UserPassword};
    push @Errors, 'FirstName is required.'  if $Data->{UserFirstname} eq q{};
    push @Errors, 'LastName is required.'   if $Data->{UserLastname} eq q{};
    push @Errors, 'Login is required.'      if $Data->{UserLogin} eq q{};
    push @Errors, 'Email is required and must be valid.' if $Data->{UserEmail} eq q{};
    push @Errors, 'CustomerID is required.' if $Data->{UserCustomerID} eq q{};

    return ( undef, \@Errors ) if @Errors;

    my $CustomerCompany = $Class->CustomerCompanyLookup( $Data->{UserCustomerID} );
    push @Errors, 'CustomerID was not found or is not valid.' if !$CustomerCompany;

    my ( $Existing, $LookupErrors ) = $Class->CustomerUserLookupData( Login => $Data->{UserLogin} );
    push @Errors, @{$LookupErrors || []};
    push @Errors, 'Customer user login already exists.' if $Existing;

    return ( undef, \@Errors ) if @Errors;

    my $CustomerUserObject = eval { $Kernel::OM->Get('Kernel::System::CustomerUser') };
    return ( undef, ['Customer user API is unavailable.'] ) if !$CustomerUserObject;

    my $Success;
    {
        # Keep the generated customer password private and scoped only to the native create call.
        my $GeneratedPassword = eval { $CustomerUserObject->GenerateRandomPassword( Size => 24 ) };
        return ( undef, ['Customer user password could not be generated.'] )
            if $@ || !defined $GeneratedPassword || ref $GeneratedPassword || length $GeneratedPassword < 24;

        $Success = eval {
            $CustomerUserObject->CustomerUserAdd(
                %{$Data},
                UserPassword => $GeneratedPassword,
                ValidID      => 1,
                UserID       => $Param{UserID},
            );
        };
    }
    return ( undef, ['Customer user could not be created.'] ) if $@ || !$Success;

    my ( $Created, $CreatedErrors ) = $Class->CustomerUserLookupData( Login => $Data->{UserLogin} );
    return ( undef, $CreatedErrors ) if @{$CreatedErrors || []};

    return ( $Created, [] );
}

sub CustomerUserUpdateData {
    my ( $Class, %Param ) = @_;

    return ( undef, ['Password input is not supported. Use the normal password reset workflow.'] )
        if $Param{PasswordProvided} || exists $Param{Password} || exists $Param{UserPassword};

    my $CurrentLogin = $Class->SafeString( $Param{CurrentLogin} || $Param{CustomerUserLogin} || $Param{Login}, 255 );
    return ( undef, ['CurrentLogin is required.'] ) if $CurrentLogin eq q{};

    my ( $Existing, $LookupErrors ) = $Class->CustomerUserLookupData( Login => $CurrentLogin );
    return ( undef, $LookupErrors ) if @{$LookupErrors || []};
    return ( undef, ['Customer user not found.'] ) if !$Existing;

    my $NewLogin = exists $Param{Login}
        ? $Class->SafeString( $Param{Login}, 255 )
        : $Existing->{UserLogin};
    my $FirstName = exists $Param{FirstName}
        ? $Class->SafeString( $Param{FirstName}, 100 )
        : $Existing->{UserFirstname};
    my $LastName = exists $Param{LastName}
        ? $Class->SafeString( $Param{LastName}, 100 )
        : $Existing->{UserLastname};
    my $Email = exists $Param{Email}
        ? $Class->SafeEmail( $Param{Email} )
        : $Existing->{UserEmail};
    my $CustomerID = exists $Param{CustomerID}
        ? $Class->SafeString( $Param{CustomerID}, 255 )
        : $Existing->{UserCustomerID};

    my @Errors;
    push @Errors, 'Login must not be empty.' if $NewLogin eq q{};
    push @Errors, 'FirstName must not be empty.' if $FirstName eq q{};
    push @Errors, 'LastName must not be empty.' if $LastName eq q{};
    push @Errors, 'Email must be valid.' if $Email eq q{};
    push @Errors, 'CustomerID must not be empty.' if $CustomerID eq q{};

    my $CustomerCompany = $Class->CustomerCompanyLookup($CustomerID);
    push @Errors, 'CustomerID was not found or is not valid.' if !$CustomerCompany;

    if ( lc $NewLogin ne lc $CurrentLogin ) {
        my ( $Duplicate, $DuplicateErrors ) = $Class->CustomerUserLookupData( Login => $NewLogin );
        push @Errors, @{$DuplicateErrors || []};
        push @Errors, 'Customer user login already exists.' if $Duplicate;
    }

    return ( undef, \@Errors ) if @Errors;

    my %Update = (
        ID             => $CurrentLogin,
        UserLogin      => $NewLogin,
        UserFirstname  => $FirstName,
        UserLastname   => $LastName,
        UserEmail      => $Email,
        UserCustomerID => $CustomerID,
        ValidID        => 1,
        UserID         => $Param{UserID},
    );

    my $CustomerUserObject = eval { $Kernel::OM->Get('Kernel::System::CustomerUser') };
    return ( undef, ['Customer user API is unavailable.'] ) if !$CustomerUserObject;

    my $Success = eval { $CustomerUserObject->CustomerUserUpdate(%Update) };
    return ( undef, ['Customer user could not be updated.'] ) if $@ || !$Success;

    my ( $Updated, $UpdatedErrors ) = $Class->CustomerUserLookupData( Login => $NewLogin );
    return ( undef, $UpdatedErrors ) if @{$UpdatedErrors || []};

    return ( $Updated, [] );
}

sub TicketArticleCreate {
    my ( $Class, %Param ) = @_;

    my $KindData = $Class->ArticleKindData( $Param{Kind} );
    return if !$KindData;

    my $ArticleObject = eval { $Kernel::OM->Get('Kernel::System::Ticket::Article') };
    return if !$ArticleObject;

    my $ArticleID = eval {
        $ArticleObject->ArticleCreate(
            TicketID             => $Param{TicketID},
            ChannelName          => $KindData->{ChannelName},
            SenderType           => $KindData->{SenderType},
            IsVisibleForCustomer => $KindData->{IsVisibleForCustomer},
            Subject              => $Param{Subject},
            Body                 => $Param{Body},
            ContentType          => $Param{ContentType} || 'text/plain; charset=utf8',
            HistoryType          => $KindData->{HistoryType},
            HistoryComment       => $Param{HistoryComment} || $KindData->{HistoryComment},
            UserID               => $Param{UserID},
        );
    };

    return if $@ || !$ArticleID;

    return 0 + $ArticleID;
}

sub ConfigString {
    my ( $Class, $Name, $Default, $MaxLength ) = @_;

    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return $Default if !$ConfigObject;

    my $Value = $ConfigObject->Get($Name);
    $Value = $Default if !defined $Value || ref $Value;

    return $Class->SafeString( $Value, $MaxLength || 100 );
}

sub StateData {
    my ( $Class, $State ) = @_;

    $State = $Class->SafeString( $State, 100 );
    return if $State eq q{};

    my $StateObject = eval { $Kernel::OM->Get('Kernel::System::State') };
    return if !$StateObject;

    # Znuny 6.5 resolves configured state names reliably via StateLookup().
    # Keep the lookup by name explicit so CloseState/ReopenState remain readable SysConfig values.
    my $StateID = eval { $StateObject->StateLookup( State => $State ) };
    return if $@ || !$StateID;

    my %StateData = eval { $StateObject->StateGet( ID => $StateID ) };
    return if $@ || !$StateData{ID};

    return {
        StateID     => 0 + $StateData{ID},
        State       => $StateData{Name} // q{},
        StateTypeID => 0 + ( $StateData{TypeID} || 0 ),
        StateType   => $StateData{TypeName} // q{},
    };
}

sub IsClosedStateType {
    my ( $Class, $StateType ) = @_;

    $StateType = lc $Class->SafeString( $StateType, 100 );

    return $StateType =~ m{\Aclosed} ? 1 : 0;
}

sub TicketStateUpdate {
    my ( $Class, %Param ) = @_;

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return if !$TicketObject;

    my $Success = eval {
        $TicketObject->TicketStateSet(
            TicketID => $Param{TicketID},
            State    => $Param{State},
            UserID   => $Param{UserID},
        );
    };

    return $@ ? undef : $Success;
}

sub TicketLockUpdate {
    my ( $Class, %Param ) = @_;

    my $TicketID = $Class->PositiveInt( $Param{TicketID} );
    my $UserID   = $Class->PositiveInt( $Param{UserID} );
    my $Lock     = $Class->SafeString( $Param{Lock}, 16 );

    return if !$TicketID || !$UserID;
    return if $Lock ne 'lock' && $Lock ne 'unlock';

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return if !$TicketObject;

    my $Success = eval {
        $TicketObject->TicketLockSet(
            TicketID => $TicketID,
            Lock     => $Lock,
            UserID   => $UserID,
        );
    };

    return $@ ? undef : $Success;
}

sub QueueData {
    my ( $Class, %Param ) = @_;

    my $QueueID   = $Class->PositiveInt( $Param{QueueID} );
    my $QueueName = $Class->SafeString( $Param{QueueName}, 255 );
    return if !$QueueID && $QueueName eq q{};

    my $QueueObject = eval { $Kernel::OM->Get('Kernel::System::Queue') };
    return if !$QueueObject;

    my %Queue = eval {
        $QueueID
            ? $QueueObject->QueueGet( ID => $QueueID )
            : $QueueObject->QueueGet( Name => $QueueName );
    };
    return if $@ || !$Queue{QueueID} || !$Queue{Name};
    return if $Queue{ValidID} && $Queue{ValidID} != 1;

    my $GroupID = $Class->PositiveInt( $Queue{GroupID} );
    if ( !$GroupID ) {
        $GroupID = eval { $QueueObject->GetQueueGroupID( QueueID => $Queue{QueueID} ) };
    }

    return {
        QueueID   => 0 + $Queue{QueueID},
        QueueName => $Queue{Name} // q{},
        GroupID   => 0 + ( $GroupID || 0 ),
    };
}

sub OwnerData {
    my ( $Class, %Param ) = @_;

    my $OwnerID   = $Class->PositiveInt( $Param{OwnerID} );
    my $UserLogin = $Class->SafeString( $Param{UserLogin}, 255 );
    return if !$OwnerID && $UserLogin eq q{};

    my $UserObject = eval { $Kernel::OM->Get('Kernel::System::User') };
    return if !$UserObject;

    if ( !$OwnerID ) {
        $OwnerID = eval {
            $UserObject->UserLookup(
                UserLogin => $UserLogin,
                Silent    => 1,
            );
        };
    }
    return if $@ || !$OwnerID;

    my %ActiveUsers = eval {
        $UserObject->UserList(
            Type          => 'Short',
            Valid         => 1,
            NoOutOfOffice => 1,
        );
    };
    return if $@ || !exists $ActiveUsers{$OwnerID};

    my %FullNames = eval {
        $UserObject->UserList(
            Type          => 'Long',
            Valid         => 1,
            NoOutOfOffice => 1,
        );
    };
    return if $@;

    my %UserData = eval { $UserObject->GetUserData( UserID => $OwnerID ) };
    return if $@ || !$UserData{UserID} || !$UserData{UserLogin};

    return {
        OwnerID       => 0 + $UserData{UserID},
        OwnerLogin    => $UserData{UserLogin},
        OwnerFullname => $FullNames{$OwnerID} // q{},
    };
}

sub AssignableAgents {
    my ( $Class, %Param ) = @_;

    my $Queue = $Class->QueueData( QueueID => $Param{QueueID} );
    return if !$Queue || !$Queue->{GroupID};

    my $UserObject   = eval { $Kernel::OM->Get('Kernel::System::User') };
    my $GroupObject  = eval { $Kernel::OM->Get('Kernel::System::Group') };
    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return if !$UserObject || !$GroupObject || !$ConfigObject;

    my %ActiveLogins = eval {
        $UserObject->UserList(
            Type          => 'Short',
            Valid         => 1,
            NoOutOfOffice => 1,
        );
    };
    return if $@;

    my %FullNames = eval {
        $UserObject->UserList(
            Type          => 'Long',
            Valid         => 1,
            NoOutOfOffice => 1,
        );
    };
    return if $@;

    # Mirror the owner selector used by Znuny's core ticket action screens.
    my %PermittedUsers;
    if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
        %PermittedUsers = %ActiveLogins;
    }
    else {
        %PermittedUsers = eval {
            $GroupObject->PermissionGroupGet(
                GroupID => $Queue->{GroupID},
                Type    => 'owner',
            );
        };
        return if $@;
    }

    my @Agents;
    for my $UserID ( sort { $a <=> $b } keys %PermittedUsers ) {
        next if !exists $ActiveLogins{$UserID};

        push @Agents, {
            UserID       => 0 + $UserID,
            UserLogin    => $ActiveLogins{$UserID} // q{},
            UserFullname => $FullNames{$UserID} // q{},
        };
    }

    @Agents = sort {
        lc( $a->{UserFullname} // q{} ) cmp lc( $b->{UserFullname} // q{} )
            || lc( $a->{UserLogin} // q{} ) cmp lc( $b->{UserLogin} // q{} )
            || ( $a->{UserID} || 0 ) <=> ( $b->{UserID} || 0 )
    } @Agents;

    return ( $Queue, \@Agents );
}

sub AssignableQueues {
    my ( $Class, %Param ) = @_;

    my $Owner = $Class->OwnerData( OwnerID => $Param{UserID} );
    return if !$Owner;

    my $QueueObject  = eval { $Kernel::OM->Get('Kernel::System::Queue') };
    my $GroupObject  = eval { $Kernel::OM->Get('Kernel::System::Group') };
    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return if !$QueueObject || !$GroupObject || !$ConfigObject;

    my %QueueList = eval { $QueueObject->QueueList( Valid => 1 ) };
    return if $@;

    my $ChangeOwnerToEveryone = $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ? 1 : 0;
    my %OwnerGroups;
    if ( !$ChangeOwnerToEveryone ) {
        %OwnerGroups = eval {
            $GroupObject->PermissionUserGet(
                UserID => $Owner->{OwnerID},
                Type   => 'owner',
            );
        };
        return if $@;
    }

    my @Queues;
    QUEUEID:
    for my $QueueID ( sort { $a <=> $b } keys %QueueList ) {
        next QUEUEID if !$QueueID || !$QueueList{$QueueID};

        my $Queue = $Class->QueueData( QueueID => $QueueID );
        next QUEUEID if !$Queue || !$Queue->{GroupID};
        next QUEUEID if !$ChangeOwnerToEveryone && !$OwnerGroups{ $Queue->{GroupID} };

        push @Queues, {
            QueueID  => $Queue->{QueueID},
            Name     => $Queue->{QueueName},
            FullName => $Queue->{QueueName},
        };
    }

    @Queues = sort {
        lc( $a->{FullName} // q{} ) cmp lc( $b->{FullName} // q{} )
            || lc( $a->{Name} // q{} ) cmp lc( $b->{Name} // q{} )
            || ( $a->{QueueID} || 0 ) <=> ( $b->{QueueID} || 0 )
    } @Queues;

    return (
        {
            UserID       => $Owner->{OwnerID},
            UserLogin    => $Owner->{OwnerLogin},
            UserFullname => $Owner->{OwnerFullname},
        },
        \@Queues,
    );
}

sub OwnerCanOwnQueue {
    my ( $Class, %Param ) = @_;

    my $OwnerID = $Class->PositiveInt( $Param{OwnerID} );
    my $QueueID = $Class->PositiveInt( $Param{QueueID} );
    return 0 if !$OwnerID || !$QueueID;

    my ( $Queue, $Agents ) = $Class->AssignableAgents( QueueID => $QueueID );
    return 0 if !$Queue || ref $Agents ne 'ARRAY';

    return scalar grep { $_->{UserID} == $OwnerID } @{$Agents};
}

sub TicketCustomerData {
    my ( $Class, %Param ) = @_;

    my $CustomerUserID = $Class->SafeString( $Param{CustomerUserID}, 255 );
    return if !$CustomerUserID || $CustomerUserID =~ /[*%?]/;

    my $CustomerUserObject = eval { $Kernel::OM->Get('Kernel::System::CustomerUser') };
    return if !$CustomerUserObject;

    my %UserData = eval {
        $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserID,
        );
    };
    return if $@ || !$UserData{UserLogin} || !$UserData{UserCustomerID};

    my %ActiveUsers = eval {
        $CustomerUserObject->CustomerSearch(
            UserLogin => $UserData{UserLogin},
            Valid     => 1,
            Limit     => 100,
        );
    };
    return if $@ || !grep { lc $_ eq lc $UserData{UserLogin} } keys %ActiveUsers;

    my $Fullname = eval {
        $CustomerUserObject->CustomerName(
            UserLogin => $UserData{UserLogin},
        );
    };
    if ( $@ || !defined $Fullname ) {
        $Fullname = join q{ }, grep { defined && $_ ne q{} } @UserData{qw(UserFirstname UserLastname)};
    }

    return {
        CustomerID          => $UserData{UserCustomerID} // q{},
        CustomerUserID      => $UserData{UserLogin} // q{},
        CustomerUserFullname => $Fullname // q{},
        CustomerUserEmail   => $UserData{UserEmail} // q{},
    };
}

sub TicketAssignmentSnapshot {
    my ( $Class, %Param ) = @_;

    my $Ticket = $Param{Ticket};
    return if ref $Ticket ne 'HASH' || !$Ticket->{TicketID};

    my $OwnerFullname = q{};
    my $UserObject = eval { $Kernel::OM->Get('Kernel::System::User') };
    if ($UserObject) {
        my %FullNames = eval {
            $UserObject->UserList(
                Type          => 'Long',
                Valid         => 0,
                NoOutOfOffice => 1,
            );
        };
        $OwnerFullname = $FullNames{ $Ticket->{OwnerID} } // q{} if !$@;
    }

    my $Customer = $Class->TicketCustomerData(
        CustomerUserID => $Ticket->{CustomerUserID},
    ) || {};

    return {
        QueueID       => 0 + ( $Ticket->{QueueID} || 0 ),
        QueueName     => $Ticket->{Queue} // q{},
        OwnerID       => 0 + ( $Ticket->{OwnerID} || 0 ),
        OwnerLogin    => $Ticket->{Owner} // q{},
        OwnerFullname => $OwnerFullname,
        CustomerID          => $Customer->{CustomerID} // $Ticket->{CustomerID} // q{},
        CustomerUserID      => $Customer->{CustomerUserID} // $Ticket->{CustomerUserID} // q{},
        CustomerUserFullname => $Customer->{CustomerUserFullname} // $Ticket->{CustomerUser} // q{},
        CustomerUserEmail   => $Customer->{CustomerUserEmail} // q{},
    };
}

sub TicketQueueMoveAllowed {
    my ( $Class, %Param ) = @_;

    my $TicketID = $Class->PositiveInt( $Param{TicketID} );
    my $QueueID  = $Class->PositiveInt( $Param{QueueID} );
    my $UserID   = $Class->PositiveInt( $Param{UserID} );
    return 0 if !$TicketID || !$QueueID || !$UserID;

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return 0 if !$TicketObject;

    my %MoveList = eval {
        $TicketObject->MoveList(
            TicketID => $TicketID,
            UserID   => $UserID,
            Type     => 'move_into',
        );
    };

    return $@ ? 0 : ( $MoveList{$QueueID} ? 1 : 0 );
}

sub MoveAssignValidation {
    my ( $Class, %Param ) = @_;

    my @Errors;
    my @Warnings;

    my $TicketID     = $Class->PositiveInt( $Param{TicketID} );
    my $UserID       = $Class->PositiveInt( $Param{UserID} );
    my $RawQueueID   = $Class->SafeString( $Param{QueueID}, 32 );
    my $RawQueueName = $Class->SafeString( $Param{QueueName}, 255 );
    my $RawOwnerID   = $Class->SafeString( $Param{OwnerID}, 32 );
    my $RawOwnerLogin = $Class->SafeString( $Param{OwnerLogin}, 255 );
    my $RawCustomerUserID = $Class->SafeString( $Param{CustomerUserID}, 255 );
    my $RawCustomerID = $Class->SafeString( $Param{CustomerID}, 255 );
    my $Note          = $Class->SafeString( $Param{Note}, 4000 );

    push @Errors, 'TicketID is required and must be a positive integer.' if !$TicketID;
    push @Errors, 'QueueID must be a positive integer.' if $RawQueueID ne q{} && !$Class->PositiveInt($RawQueueID);
    push @Errors, 'OwnerID must be a positive integer.' if $RawOwnerID ne q{} && !$Class->PositiveInt($RawOwnerID);

    my $QueueRequested = $RawQueueID ne q{} || $RawQueueName ne q{};
    my $OwnerRequested = $RawOwnerID ne q{} || $RawOwnerLogin ne q{};
    my $CustomerRequested = $RawCustomerUserID ne q{} || $RawCustomerID ne q{};
    push @Errors, 'CustomerUserID is required when changing customer.'
        if $RawCustomerID ne q{} && $RawCustomerUserID eq q{};
    push @Errors, 'At least one target change is required.'
        if !$QueueRequested && !$OwnerRequested && !$CustomerRequested;

    my $Ticket;
    if ( $TicketID && $UserID ) {
        $Ticket = $Class->TicketLookup(
            TicketID => $TicketID,
            UserID   => $UserID,
        );
        push @Errors, 'Ticket not found.' if !$Ticket;
    }

    my $Current = $Ticket ? $Class->TicketAssignmentSnapshot( Ticket => $Ticket ) : undef;
    my $TargetQueue;
    my $TargetOwner;
    my $TargetCustomer;

    if ($Ticket) {
        if ($QueueRequested) {
            $TargetQueue = $RawQueueID ne q{}
                ? $Class->QueueData( QueueID => $RawQueueID )
                : $Class->QueueData( QueueName => $RawQueueName );
            push @Errors, 'Target queue not found or is not valid.' if !$TargetQueue;

            if ( $TargetQueue && $RawQueueID ne q{} && $RawQueueName ne q{} && $TargetQueue->{QueueName} ne $RawQueueName ) {
                push @Warnings, 'QueueName does not match QueueID; QueueID was used.';
            }
        }
        else {
            $TargetQueue = $Class->QueueData( QueueID => $Current->{QueueID} );
            push @Errors, 'Current ticket queue could not be resolved.' if !$TargetQueue;
        }

        if ($OwnerRequested) {
            $TargetOwner = $RawOwnerID ne q{}
                ? $Class->OwnerData( OwnerID => $RawOwnerID )
                : $Class->OwnerData( UserLogin => $RawOwnerLogin );
            push @Errors, 'Target owner not found or is not active.' if !$TargetOwner;

            if ( $TargetOwner && $RawOwnerID ne q{} && $RawOwnerLogin ne q{} && $TargetOwner->{OwnerLogin} ne $RawOwnerLogin ) {
                push @Warnings, 'OwnerLogin does not match OwnerID; OwnerID was used.';
            }
        }
        else {
            $TargetOwner = {
                OwnerID       => $Current->{OwnerID},
                OwnerLogin    => $Current->{OwnerLogin},
                OwnerFullname => $Current->{OwnerFullname},
            };
        }

        if ( $RawCustomerUserID ne q{} ) {
            $TargetCustomer = $Class->TicketCustomerData(
                CustomerUserID => $RawCustomerUserID,
            );
            push @Errors, 'Target customer user not found or is not active.' if !$TargetCustomer;

            if ( $TargetCustomer && $RawCustomerID ne q{} && $TargetCustomer->{CustomerID} ne $RawCustomerID ) {
                push @Errors, 'CustomerID does not match CustomerUserID.';
            }
        }
        else {
            $TargetCustomer = {
                CustomerID          => $Current->{CustomerID},
                CustomerUserID      => $Current->{CustomerUserID},
                CustomerUserFullname => $Current->{CustomerUserFullname},
                CustomerUserEmail   => $Current->{CustomerUserEmail},
            };
        }
    }

    my $QueueChanged = $Current && $TargetQueue
        ? ( $Current->{QueueID} != $TargetQueue->{QueueID} ? 1 : 0 )
        : 0;
    my $OwnerChanged = $Current && $TargetOwner
        ? ( $Current->{OwnerID} != $TargetOwner->{OwnerID} ? 1 : 0 )
        : 0;
    my $CustomerChanged = $Current && $TargetCustomer && $RawCustomerUserID ne q{}
        ? (
            $Current->{CustomerUserID} ne $TargetCustomer->{CustomerUserID}
                || $Current->{CustomerID} ne $TargetCustomer->{CustomerID}
            ? 1
            : 0
        )
        : 0;
    my $RequiredNote = $OwnerChanged ? 1 : 0;

    if ( $QueueChanged && !$Class->TicketQueueMoveAllowed(
        TicketID => $TicketID,
        QueueID  => $TargetQueue->{QueueID},
        UserID   => $UserID,
        )
        )
    {
        push @Errors, 'Authenticated agent cannot move the ticket into the target queue.';
    }

    if ( ( $QueueChanged || $OwnerChanged ) && $TargetOwner && $TargetQueue && !$Class->OwnerCanOwnQueue(
        OwnerID => $TargetOwner->{OwnerID},
        QueueID => $TargetQueue->{QueueID},
        )
        )
    {
        push @Errors, 'Target owner is not assignable in target queue.';
    }

    push @Errors, 'Note is required when owner changes.' if $RequiredNote && $Note eq q{};

    if ( $Ticket && ( $QueueRequested || $OwnerRequested || $CustomerRequested )
        && !$QueueChanged && !$OwnerChanged && !$CustomerChanged )
    {
        push @Warnings, 'Requested targets already match the ticket.';
        push @Errors, 'No queue, owner, or customer change would be made.';
    }

    my $Target = $TargetQueue && $TargetOwner && $TargetCustomer
        ? {
            QueueID       => $TargetQueue->{QueueID},
            QueueName     => $TargetQueue->{QueueName},
            OwnerID       => $TargetOwner->{OwnerID},
            OwnerLogin    => $TargetOwner->{OwnerLogin},
            OwnerFullname => $TargetOwner->{OwnerFullname},
            CustomerID          => $TargetCustomer->{CustomerID},
            CustomerUserID      => $TargetCustomer->{CustomerUserID},
            CustomerUserFullname => $TargetCustomer->{CustomerUserFullname},
            CustomerUserEmail   => $TargetCustomer->{CustomerUserEmail},
        }
        : undef;

    return {
        Valid         => @Errors ? 0 : 1,
        RequiredNote  => $RequiredNote,
        Current       => $Current,
        Target        => $Target,
        Errors        => \@Errors,
        Warnings      => \@Warnings,
        QueueChanged  => $QueueChanged,
        OwnerChanged  => $OwnerChanged,
        CustomerChanged => $CustomerChanged,
        Note          => $Note,
        Ticket        => $Ticket,
    };
}

sub TicketQueueUpdate {
    my ( $Class, %Param ) = @_;

    my $TicketID = $Class->PositiveInt( $Param{TicketID} );
    my $QueueID  = $Class->PositiveInt( $Param{QueueID} );
    my $UserID   = $Class->PositiveInt( $Param{UserID} );
    return if !$TicketID || !$QueueID || !$UserID;

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return if !$TicketObject;

    my $Success = eval {
        $TicketObject->TicketQueueSet(
            TicketID => $TicketID,
            QueueID  => $QueueID,
            UserID   => $UserID,
        );
    };

    return $@ ? undef : $Success;
}

sub TicketOwnerUpdate {
    my ( $Class, %Param ) = @_;

    my $TicketID = $Class->PositiveInt( $Param{TicketID} );
    my $OwnerID  = $Class->PositiveInt( $Param{OwnerID} );
    my $UserID   = $Class->PositiveInt( $Param{UserID} );
    my $Comment  = $Class->SafeString( $Param{Comment}, 4000 );
    return if !$TicketID || !$OwnerID || !$UserID;

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return if !$TicketObject;

    my $Success = eval {
        $TicketObject->TicketOwnerSet(
            TicketID  => $TicketID,
            NewUserID => $OwnerID,
            UserID    => $UserID,
            Comment   => $Comment,
        );
    };

    return $@ ? undef : $Success;
}

sub TicketCustomerUpdate {
    my ( $Class, %Param ) = @_;

    my $TicketID      = $Class->PositiveInt( $Param{TicketID} );
    my $CustomerID    = $Class->SafeString( $Param{CustomerID}, 255 );
    my $CustomerUserID = $Class->SafeString( $Param{CustomerUserID}, 255 );
    my $UserID        = $Class->PositiveInt( $Param{UserID} );
    return if !$TicketID || !$CustomerID || !$CustomerUserID || !$UserID;

    my $TicketObject = eval { $Kernel::OM->Get('Kernel::System::Ticket') };
    return if !$TicketObject;

    my $Success = eval {
        $TicketObject->TicketCustomerSet(
            TicketID => $TicketID,
            No       => $CustomerID,
            User     => $CustomerUserID,
            UserID   => $UserID,
        );
    };

    return $@ ? undef : $Success;
}

sub CustomerUserData {
    my ( $Class, %UserData ) = @_;

    return {
        UserLogin      => $UserData{UserLogin}      // q{},
        UserCustomerID => $UserData{UserCustomerID} // q{},
        UserFirstname  => $UserData{UserFirstname}  // q{},
        UserLastname   => $UserData{UserLastname}   // q{},
        UserEmail      => $UserData{UserEmail}      // q{},
    };
}

sub FormatLocalTime {
    my ($Class) = @_;

    my @Time = localtime;

    return sprintf(
        '%04d-%02d-%02d %02d:%02d:%02d',
        $Time[5] + 1900,
        $Time[4] + 1,
        $Time[3],
        $Time[2],
        $Time[1],
        $Time[0],
    );
}

sub ZnunyVersion {
    my ($Class) = @_;

    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return '6.5.x' if !$ConfigObject;

    return $ConfigObject->Get('Version')
        || $ConfigObject->Get('ProductVersion')
        || $ConfigObject->Get('Framework')
        || '6.5.x';
}

1;
