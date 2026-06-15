package Kernel::GenericInterface::Operation::ZnunyAgentList::Common;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use constant PACKAGE_NAME    => 'ZnunyAgentList';
use constant PACKAGE_VERSION => '1.1.0';
use constant AUTH_ERROR_CODE => 'ZnunyAgentList.AuthFail';

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

    my $ConfigObject = eval { $Kernel::OM->Get('Kernel::Config') };
    return if !$ConfigObject;

    my $ConfiguredGroups = $ConfigObject->Get('ZnunyAgentList::AllowedGroups');
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
