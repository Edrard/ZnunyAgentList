package Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use constant PACKAGE_NAME    => 'ZnunyAgentList';
use constant PACKAGE_VERSION => '1.2.5';
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
        TicketID       => 0 + ( $Ticket{TicketID} || 0 ),
        TicketNumber   => $Ticket{TicketNumber}   // q{},
        Title          => $Ticket{Title}          // q{},
        QueueID        => 0 + ( $Ticket{QueueID} || 0 ),
        Queue          => $Ticket{Queue}          // q{},
        OwnerID        => 0 + ( $Ticket{OwnerID} || 0 ),
        Owner          => $Ticket{Owner}          // q{},
        CustomerUserID => $Ticket{CustomerUserID} // q{},
        CustomerUser   => $Ticket{CustomerUser}   // q{},
        StateID        => 0 + ( $Ticket{StateID} || 0 ),
        State          => $Ticket{State}          // q{},
        StateType      => $Ticket{StateType} || $Ticket{StateTypeName} || q{},
        PriorityID     => 0 + ( $Ticket{PriorityID} || 0 ),
        Priority       => $Ticket{Priority}       // q{},
        Created        => $Ticket{Created}        || $Ticket{CreateTime} || q{},
        Changed        => $Ticket{Changed}        || $Ticket{ChangeTime} || q{},
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

    return $SafeTicket;
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
