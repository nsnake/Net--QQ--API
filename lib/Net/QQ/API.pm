package Net::QQ::API;

# ---------------------------------------------------------------------------
# QQ ConnectAPI
#
# CGI.NET <loveme1314@gmail.com>
# ---------------------------------------------------------------------------
# $Id$
# ---------------------------------------------------------------------------
use strict;
use warnings;
use 5.010;
use version 0.77; our $VERSION = qv("v0.8.0");
use JSON::XS();
use Carp;
use Time::HiRes qw( gettimeofday );
use URI::Escape;
use LWP::UserAgent;
use constant {
    GET_AUTH_CODE_URL    => "https://graph.qq.com/oauth2.0/authorize",
    GET_ACCESS_TOKEN_URL => 'https://graph.qq.com/oauth2.0/token',
    GET_OPENID_URL       => 'https://graph.qq.com/oauth2.0/me',
    GET_USER_INFO_URL    => 'https://graph.qq.com/user/get_user_info',
    GET_SIMPLE_USERINFO_URL =>
      'https://openmobile.qq.com/user/get_simple_userinfo',
    GET_VIP_INFO_URL      => 'https://graph.qq.com/user/get_vip_info',
    GET_VIP_RICH_INFO_URL => 'https://graph.qq.com/user/get_vip_rich_info',
    GET_LIST_ALBUM_URL    => 'https://graph.qq.com/photo/list_album',
    GET_REPOST_LIST       => 'https://graph.qq.com/t/get_repost_list',
    GET_INFO_URL          => 'https://graph.qq.com/user/get_info',
    GET_OTHER_INFO_URL    => 'https://graph.qq.com/user/get_other_info',

    POST_ADD_ONE_BLOG_URL => 'https://graph.qq.com/blog/add_one_blog',
    POST_ADD_T            => 'https://graph.qq.com/t/add_t',
    POST_UPLOAD_PIC_URL   => 'https://graph.qq.com/photo/upload_pic',
    POST_ADD_ALBUM        => 'https://graph.qq.com/photo/add_album',
    GET_LIST_PHOTO        => 'https://graph.qq.com/photo/list_photo',
    POST_DEL_T            => 'https://graph.qq.com/t/del_t',
    POST_ADD_PIC_T        => 'https://graph.qq.com/t/add_pic_t',
    GET_REPOST_LIST       => 'https://graph.qq.com/t/get_repost_list',
    GET_OTHER_INFO        => 'https://graph.qq.com/user/get_other_info',
    GET_FANSLIST          => 'https://graph.qq.com/relation/get_fanslist',
    GET_IDOLLIST          => 'https://graph.qq.com/relation/get_idollist',
    POST_ADD_IDOL         => 'https://graph.qq.com/relation/add_idol',
    POST_DEL_IDOL         => 'https://graph.qq.com/relation/del_idol',
    POST_GET_TENPAY_ADDR  => 'https://graph.qq.com/cft_info/get_tenpay_addr'
};

sub new {
    my ( $class, %params ) = @_;
    $class = ( ref $class ) || $class || __PACKAGE__;
    my $self = {};
    bless $self, $class;
    $self->{'json'}     = JSON::XS->new();
    $self->{'recorder'} = \%params;
    $self->{'browser'}  = LWP::UserAgent->new();
    $self->{'browser'}->agent('QCSDK_0.1');
    return $self;
}

#appid(*) callback(*) scope state
#如果state不存在则自动生成
sub qq_login {
    my ( $self, %params ) = @_;
    if ( !defined $params{'appid'} || !defined $params{'callback'} ) {
        croak 'appid and callback is need.';
    }
    if ( !defined $params{'state'} ) {
        my ( $s, $us ) = gettimeofday();
        $params{'state'} = sprintf( "%06d%05d%06d", $us, substr( $s, -5 ), $$ );
    }

    $self->{'recorder'}->{'appid'}    = $params{'appid'};
    $self->{'recorder'}->{'callback'} = uri_escape( $params{'callback'} );

    my %keys = (
        'response_type' => 'code',
        'client_id'     => $self->{'recorder'}->{'appid'},
        'redirect_uri'  => $self->{'recorder'}->{'callback'},
        'state'         => $params{'state'},
        'scope'         => defined $params{'scope'}
        ? $params{'scope'}
        : 'get_user_info,add_share,list_album,add_album,upload_pic,add_topic,add_one_blog,add_weibo,check_page_fans,add_t,add_pic_t,del_t,get_repost_list,get_info,get_other_info,get_fanslist,get_idolist,add_idol,del_idol,get_tenpay_addr'
    );
    my $url = GET_AUTH_CODE_URL . '?';
    foreach ( keys %keys ) {
        $url .= $_ . '=' . $keys{$_} . '&';
    }
    substr( $url, -1, 1, '' );
    return wantarray ? ( $url, $params{'state'} ) : $url;
}

#appkey(*) code(*) appid callback
sub qq_callback {
    my ( $self, %params ) = @_;
    if ( !defined $params{'code'} || !defined $params{'appkey'} ) {
        croak 'code and appkey is need.';
    }

    if ( !defined $self->{'recorder'}->{'appid'} && !defined $params{'appid'} )
    {
        croak 'appid is need.';
    }

    if (   !defined $self->{'recorder'}->{'callback'}
        && !defined $params{'callback'} )
    {
        croak 'callback is need.';
    }

    $self->{'recorder'}->{'appid'} =
      defined $params{'appid'}
      ? $params{'appid'}
      : $self->{'recorder'}->{'appid'};
    $self->{'recorder'}->{'callback'} =
      defined $params{'callback'}
      ? uri_escape( $params{'callback'} )
      : $self->{'recorder'}->{'callback'};

    $self->{'recorder'}->{'appkey'} = $params{'appkey'};
    $self->{'recorder'}->{'code'}   = $params{'code'};

    my %keys = (
        'grant_type'    => "authorization_code",
        'client_id'     => $self->{'recorder'}->{'appid'},
        'redirect_uri'  => $self->{'recorder'}->{'callback'},
        'client_secret' => $self->{'recorder'}->{'appkey'},
        'code'          => $self->{'recorder'}->{'code'}
    );

    my $url = GET_ACCESS_TOKEN_URL . '?';
    foreach ( keys %keys ) {
        $url .= $_ . '=' . $keys{$_} . '&';
    }
    substr( $url, -1, 1, '' );

    #通过Authorization Code获取Access Token
    my $params = $self->_parse_callback( $self->{'browser'}->get($url) );
    $self->{'recorder'}->{'access_token'}  = $params->{'access_token'};
    $self->{'recorder'}->{'refresh_token'} = $params->{'access_token'};

    $url =
      GET_OPENID_URL . '?access_token=' . $self->{'recorder'}->{'access_token'};
    $params = $self->_parse_callback( $self->{'browser'}->get($url) );
    $self->{'recorder'}->{'openid'} = $params->{'openid'};
    return ( $self->{'recorder'}->{'access_token'},
        $self->{'recorder'}->{'openid'} );
}

#访问用户资料
sub get_user_info {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback(
        $self->{'browser'}->get(
            GET_USER_INFO_URL . '?' . $self->_build_contents( \%params, 1 )
        )
    );
}

sub get_simple_userinfo {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback(
        $self->{'browser'}->get(
            GET_SIMPLE_USERINFO_URL . '?'
              . $self->_build_contents( \%params, 1 )
        )
    );
}

#访问用户QQ会员信息
sub get_vip_info {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback(
        $self->{'browser'}->get(
            GET_VIP_INFO_URL . '?' . $self->_build_contents( \%params, 1 )
        )
    );
}

sub get_vip_rich_info {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback(
        $self->{'browser'}->get(
            GET_VIP_RICH_INFO_URL . '?' . $self->_build_contents( \%params, 1 )
        )
    );
}

#同步动态至QQ空间
sub add_one_blog {
    my $self   = shift;
    my %params = @_;
    if ( !exists $params{'title'} || !exists $params{'content'} ) {
        croak 'title and content need';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_ADD_T, $self->_build_contents( \%params ) ) );
}

#访问我的空间相册
sub list_album {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback(
        $self->{'browser'}->get(
            GET_LIST_ALBUM_URL . '?' . $self->_build_contents( \%params, 1 )
        )
    );
}

sub upload_pic {
    my $self   = shift;
    my %params = @_;
    if ( !exists $params{'picture'} ) {
        croak 'picture need';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_UPLOAD_PIC_URL, $self->_build_contents( \%params ) ) );
}

sub add_album {
    my $self   = shift;
    my %params = @_;
    if ( !exists $params{'albumname'} ) {
        croak 'albumname need';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_ADD_ALBUM, $self->_build_contents( \%params ) ) );
}

sub list_photo {
    my $self   = shift;
    my %params = @_;
    if ( !exists $params{'albumid'} ) {
        croak 'albumid need';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->get( GET_LIST_PHOTO . '?' . $self->_build_contents( \%params, 1 ) )
    );
}

#访问我的腾讯微博资料
sub get_info {
    my $self   = shift;
    my %params = @_;

    return $self->_parse_callback( $self->{'browser'}
          ->get( GET_INFO_URL . '?' . $self->_build_contents( \%params, 1 ) ) );
}

#分享内容到我的腾讯微博
sub add_t {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_ADD_T, $self->_build_contents( \%params ) ) );
}

sub del_t {
    my $self   = shift;
    my %params = @_;
    if ( !exists $params{'id'} ) {
        croak 'id need';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_DEL_T, $self->_build_contents( \%params ) ) );
}

sub add_pic_t {
    my $self   = shift;
    my %params = @_;
    if ( !exists $params{'content'} || !exists $params{'pic'} ) {
        croak 'content pic need';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_ADD_PIC_T, $self->_build_contents( \%params ) ) );
}

sub get_repost_list {
    my $self   = shift;
    my %params = @_;
    if (   !exists $params{'flag'}
        || !exists $params{'rootid'}
        || !exists $params{'pageflag'}
        || !exists $params{'pagetime'}
        || !exists $params{'reqnum'}
        || !exists $params{'twitterid'} )
    {
        croak 'params invalid';
    }
    return $self->_parse_callback(
        $self->{'browser'}->get(
            GET_REPOST_LIST . '?' . $self->_build_contents( \%params, 1 )
        )
    );
}

#获得我的微博好友信息
sub get_other_info {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback( $self->{'browser'}
          ->get( GET_OTHER_INFO . '?' . $self->_build_contents( \%params, 1 ) )
    );
}

sub get_fanslist {
    my $self   = shift;
    my %params = @_;
    if (   !exists $params{'reqnum'}
        || !exists $params{'startindex'} )
    {
        croak 'params invalid';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->get( GET_FANSLIST . '?' . $self->_build_contents( \%params, 1 ) ) );
}

sub get_idollist {
    my $self   = shift;
    my %params = @_;
    if (   !exists $params{'reqnum'}
        || !exists $params{'startindex'} )
    {
        croak 'params invalid';
    }
    return $self->_parse_callback( $self->{'browser'}
          ->get( GET_IDOLLIST . '?' . $self->_build_contents( \%params, 1 ) ) );
}

sub add_idol {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_ADD_IDOL, $self->_build_contents( \%params ) ) );
}

sub del_idol {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_DEL_IDOL, $self->_build_contents( \%params ) ) );
}

#访问我的财付通信息
sub get_tenpay_addr {
    my $self   = shift;
    my %params = @_;
    return $self->_parse_callback( $self->{'browser'}
          ->post( POST_GET_TENPAY_ADDR, $self->_build_contents( \%params ) ) );
}

#构建登陆后post请求必须的参数
sub _build_contents($$) {
    my ( $self, $params, $wantstring ) = @_;
    foreach ( ( 'appid', 'access_token', 'openid' ) ) {

        #检查必要参数,如果没有则从传入的参数中获取
        if (   !defined $self->{'recorder'}->{$_}
            && !defined $params->{$_} )
        {
            croak( $_ . ' is need' );
        }
        else {
            $self->{'recorder'}->{$_} =
              defined $params->{$_}
              ? $params->{$_}
              : $self->{'recorder'}->{$_};
        }
    }
    $params->{'oauth_consumer_key'} = $self->{'recorder'}->{'appid'};
    $params->{'access_token'}       = $self->{'recorder'}->{'access_token'};
    $params->{'openid'}             = $self->{'recorder'}->{'openid'};
    $params->{'format'}             = 'json';
    if ( defined $wantstring ) {
        my $contents;
        foreach ( keys %{$params} ) {
            $contents .= $_ . '=' . $params->{$_} . '&';
        }
        return $contents;
    }

    return $params;
}

sub _parse_callback {
    my ( $self, $response ) = @_;
    croak "Error " . $response->status_line
      unless $response->is_success;
    my $param_string = $response->decoded_content();
    if ( $param_string =~ /callback/ ) {
        $param_string = substr( $param_string, 9, -3 );
        $param_string = $self->{'json'}->decode($param_string);
        if ( defined $param_string->{'error'} ) {
            croak(  $param_string->{'error'} . ':'
                  . $param_string->{'error_description'} );
        }
        return $param_string;
    }

    #json格式
    if ( $param_string =~ /^\{/ ) {
        return $self->{'json'}->decode($param_string);
    }
    else {
        my %params;
        foreach ( split( /[&]/, $param_string ) ) {
            my ( $p, $v ) = split( '=', $_, 2 );
            if ($p) { $params{$p} = $v; }
        }
        return \%params;
    }
}

1;

=pod

=head1 NAME

QQ ConnectAPI - QQ互联SDK

=head1 VERSION

version 0.8.0

=head1 DEPRECATION

具体API和参数请参看http://wiki.connect.qq.com/api%e5%88%97%e8%a1%a8

=head1 AUTHORS

=over 4

=item *

CGI.NET <loveme1314@gmail.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by CGI.NET

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__
