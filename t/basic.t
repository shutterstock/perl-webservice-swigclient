#! /usr/bin/env perl

use Test::Most tests => 2;
use Test::Easy qw(resub wiretap);

my $class = 'WebService::SwigClient';

use_ok $class;

our $response_body;
our $perform_retcode = 0;
our $response_code = 200;
{
  package Mock::WWW::Curl::Easy;
  use WWW::Curl::Easy;
  sub new {
    return bless({opts => {}, performed => 0}, $_[0]);
  }
  sub setopt {
    my ($self, $opt, $value) = @_;
    $self->{opts}->{$opt} = $value;
  }
  sub perform {
    $_[0]->{performed} = 1;
    ${$_[0]->{opts}->{CURLOPT_WRITEDATA()}} = $response_body;
    return $perform_retcode;
  }
  sub getinfo { return $response_code if($_[1] == CURLINFO_HTTP_CODE); }
  sub strerror { return "Error description"; }
  sub errbuf { return "error data"; }

  sub reset { $_[0]->{performed} = 0; }
}

my $render_curl = Mock::WWW::Curl::Easy->new();

subtest "basic success call" => sub {
  plan tests => 4;

  local $perform_retcode = 0;
  local $response_code   = 200;
  local $response_body   = 'foo';

  my $new_rs = resub 'WWW::Curl::Easy::new' => sub { $render_curl };
  my $test;

  lives_ok { $test = $class->new( service_url => 'http://localhost:1234' ) };
  isa_ok $test->curl, 'Mock::WWW::Curl::Easy';

  is $test->render( '/foo/path', { foo => 'bar' } ), 'foo';

  is $test, $class->new( service_url => 'http://localhost:1234' ), 'verify we have a singleton';
}
