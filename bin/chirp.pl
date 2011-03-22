use practical;
use Encode;
use JSON;
use HTML::Entities::Recursive;
use Tatsumaki::HTTPClient;
use AnyEvent::Twitter::Stream;

use lib 'lib';
use Text::Twitter;

$| = 1;

my $confbase = 'config';
my $OAuth    = do "$confbase/oauth.pl"  or die $!;
my $secret   = do "$confbase/secret.pl" or die $!;

my $recursive = HTML::Entities::Recursive->new;
my $client    = Tatsumaki::HTTPClient->new;

while (1) {
    warn now() . "ALERT: wake up";
    my $cv = AE::cv;
    my $listener = AnyEvent::Twitter::Stream->new(
        %$OAuth,
        method   => 'userstream',
        timeout  => 45,
        on_tweet => \&on_tweet,
        on_error => sub {
            warn now() . "ALERT: on error";
            $cv->send;
        },
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

    return if $tweet->{source} =~ /(?:loctouch|foursquare|twittbot\.net|WiTwit)/;
    return if $tweet->{text} =~ /(?:shindanmaker\.com|Livlis)/i;
    return if $tweet->{text} =~ /(?:[RＲ][TＴ]|拡散)(?:希望|お?願い|して|よろしく)|\@ikedanob/i;
    return if $tweet->{text} =~ /[公式]?(?:リ?ツイート|[Q|R]T)された回?数.+(?:する|します)/i;
    return if $tweet->{text} =~ /(?:[RQ]T:? \@\w+.*){2,}/i;

    my $escaped = $recursive->encode_numeric($tweet);
    $escaped->{processed} = Text::Twitter::process($tweet);
    $escaped->{created_at} = scalar localtime;

    return unless $escaped->{processed};

    my $tweet_text = JSON::to_json($escaped);
    $client->post("http://localhost:2222/new", [
        tweet => $tweet_text, secret => $secret
    ], sub {
        $tweet->{text} =~ s/\r|\n//g;
        print encode_utf8 "<$tweet->{user}{screen_name}> $tweet->{text}\n\n";
    });
}

sub now { "[" .  scalar localtime . "] " }

__END__

