package WebService::SwigClient;
use Moo;

our $VERSION = '0.001';

use JSON::XS qw(encode_json);
use WWW::Curl::Easy;

has api_key     => ( required => 0, is => 'ro' );
has service_url => ( required => 1, is => 'ro' );
has curl        => ( required => 1, is => 'ro', default => sub {
  my $render_curl = WWW::Curl::Easy->new;
  $render_curl->setopt(CURLOPT_POST, 1);
  $render_curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
  return $render_curl;
});

has error_handler => ( is => 'rw' );

{
  my $singleton;
  sub instance {
    my ($class, %args) = @_;
    return $singleton ||= $class->new(%args);
  }
}

sub render {
  my ($self, $path, $data) = @_;

  my $body = encode_json($data);
  my $curl = $self->curl;

  my $url = $self->api_key ?
    join('/',($self->service_url, $self->api_key, $path)) :
    join('/',($self->service_url, 'template', $path));

  $curl->setopt(CURLOPT_URL, $url);
  {
    use bytes;
    $curl->setopt(CURLOPT_POSTFIELDSIZE, length($body));
  }
  $curl->setopt(CURLOPT_COPYPOSTFIELDS, $body);
  my $response_body;
  $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
  my $retcode = $curl->perform;
  if ($retcode == 0) {
    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
    if($response_code != 200 && $self->error_handler ) {
      $self->error_handler->("Swig service render error: $response_code", $curl);
      return ();
    }
    if ( $response_body) {
      utf8::decode($response_body);
    }
    return $response_body;
  } else {
    if ( $self->error_handler ) {
      $self->error_handler->(
        join(" ", "Swig service render error: $retcode", $curl->strerror($retcode), $curl->errbuf),
        $curl,
      );
    }
    return ();
  }
}

sub healthcheck {
  my ($self) = @_;
  #use local curl here to make sure we do not send post requests
  my $curl = __PACKAGE__->new(service_url => $self->service_url)->curl;
  $curl->setopt(CURLOPT_URL, "${\$self->service_url}/healthcheck");
  my $response_body;
  $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
  my $retcode = $curl->perform;
  if ($retcode == 0) {
    utf8::decode($response_body);
    return $response_body;
  } else {
    if ( $self->error_handler ) {
      $self->error_handler->(
        join(" ", "An error happened: $retcode", $curl->strerror($retcode), $curl->errbuf),
        $curl,
      );
    }
    return 'NO';
  }
}

=head1 NAME

WebService::SwigClient - A client for hitting swig.io

=head1 SYNOPSIS

  use WebService::SwigClient; 

  my $client = WebService::SwigClient->new(
    api_key       => $api_key,
    service_url   => $service_url,
    error_handler => sub {
      my ($error, $curl_object) = @_;
      warn $error;
    },
  );

  $client->render('foo.html', {});


=cut

1;
