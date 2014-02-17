package WebService::SwigClient;
use Moo;

use JSON::XS qw(encode_json);
use WWW::Curl::Easy;

has service_url => ( required => 1, is => 'ro' );
has curl        => ( required => 1, is => 'ro', default => sub {
  my $render_curl = WWW::Curl::Easy->new;
  $render_curl->setopt(CURLOPT_POST, 1);
  $render_curl->setopt(CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
  return $render_curl;
});

has error_handler => ( is => 'rw' );

sub render {
  my ($self, $path, $data) = @_;

  my $body = encode_json($data);
  my $curl = $self->curl;

  $curl->setopt(CURLOPT_URL, "${\$self->service_url}/template/$path");
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
      $self->error_handler->("Swig service render error: $response_code");
      return ();
    }
    if ( $response_body) {
      utf8::decode($response_body);
    }
    return $response_body;
  } else {
    if ( $self->error_handler ) {
      $self->error_handler->(join " ",("Swig service render error: $retcode", $curl->strerror($retcode), $curl->errbuf));
    }
    return ();
  }
}

1;
