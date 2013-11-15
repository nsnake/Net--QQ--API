#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
use Net::QQ::API;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use CGI qw/:standard/;
use Data::Dumper qw/Dumper/;

my $q = CGI->new();
given ( $q->param('action') ) {
    when ('logincallback') { qq_callback() }
    default {
        qq_login();
    }
}

sub qq_login {
    my $qc = Net::QC->new();
    my ( $url, $state ) =
      $qc->qq_login( appid => 'your appid', callback => 'your callback url' );
    print $q->redirect( -uri => $url );
}

sub qq_callback {
    print $q->header();
    my $code = $q->param('code');
    my $qc   = Net::QC->new();
    my ( $access_token, $openid ) = $qc->qq_callback(
        appid    => 'your appid',
        callback => 'your callback url',
        appkey   => 'your appkey',
        code     => $code
    );
    say Dumper $qc->get_user_info();
}
