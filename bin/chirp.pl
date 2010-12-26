use common::sense;
use Encode;
use Data::Dumper;

use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use AnyEvent::Twitter::Stream;
use Tatsumaki::HTTPClient;

use JSON;
use HTML::Entities;
use HTML::Entities::Recursive;

use File::Spec;
use File::Basename;

use lib File::Basename::dirname(__FILE__) . '/../lib/';
use Text::Twitter;

$| = 1;

my $confbase = File::Basename::dirname(__FILE__) . '/../config/';
my $OAuth    = do File::Spec->catfile($confbase, 'oauth.pl')  or die $!;
my $secret   = do File::Spec->catfile($confbase, 'secret.pl') or die $!;

my $recursive = HTML::Entities::Recursive->new;
my $ua        = AnyEvent::Twitter->new(%$OAuth);
my $client    = Tatsumaki::HTTPClient->new;

while (1) {
    logging("IMPORTANT: wake up");
    my $cv = AE::cv;
    my $listener = AnyEvent::Twitter::Stream->new(
        consumer_key    => $OAuth->{consumer_key},
        consumer_secret => $OAuth->{consumer_secret},
        token           => $OAuth->{access_token},
        token_secret    => $OAuth->{access_token_secret},
        method          => 'userstream',
        timeout         => 45,
        on_tweet        => \&on_tweet,
        on_error        => sub { logging("IMPORTANT: on error"); $cv->send; },
    );
    $cv->recv;
}
exit;

sub on_tweet {
    my $tweet = $recursive->decode(shift);

    return unless $tweet->{text};

    if ($tweet->{source} =~ />(.+)</) {
        $tweet->{source} = $1;
    }

    return if $tweet->{source} =~ /(?:loctouch|foursquare|twittbot\.net)/;
    return if $tweet->{text} =~ /(?:shindanmaker\.com)/;

    my $escaped = $recursive->encode_numeric($tweet);
    $escaped->{processed} = Text::Twitter::process($tweet);
    $escaped->{created_at} = scalar localtime;

    return unless $escaped->{processed};

    my $tweet_text = JSON::to_json($escaped);
    $client->post("http://localhost:2222/new", [
        tweet => $tweet_text, secret => $secret
    ], sub { logging($tweet->{text}); });
}

sub logging {
    for (@_) {
        say sprintf "[%s] %s", scalar localtime, $_;
    }
}

__END__

