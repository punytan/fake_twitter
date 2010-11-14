use common::sense;
use Encode;
use Data::Dumper;

use lib '/home/puny/space/HTML-Entities-Recursive/lib';

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

my $confbase = File::Basename::dirname(__FILE__) . '/../config/';
my $OAuth    = do File::Spec->catfile($confbase, 'oauth.pl')  or die $!;
my $secret   = do File::Spec->catfile($confbase, 'secret.pl') or die $!;

my $recursive = HTML::Entities::Recursive->new;
my $ua        = AnyEvent::Twitter->new(%$OAuth);
my $client    = Tatsumaki::HTTPClient->new;

our %re = (
    url   => qr{(s?https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)},
    reply => qr{(\@[0-9A-Za-z_]+)},
    hash  => qr{(\#[0-9A-Za-z_]+)},
    com   => qr{\[(co\d+)\]},
);

our $regex = qr/$re{url}|$re{reply}|$re{hash}|$re{com}/;

my $cv = AE::cv;

my $listener = AnyEvent::Twitter::Stream->new(
    consumer_key    => $OAuth->{consumer_key},
    consumer_secret => $OAuth->{consumer_secret},
    token           => $OAuth->{access_token},
    token_secret    => $OAuth->{access_token_secret},
    method          => 'userstream',
    on_tweet        => \&on_tweet,
    timeout         => 300,
    on_error        => sub { exit; },
);

$cv->recv;

exit;

sub on_tweet {
    my $tweet = $recursive->decode(shift);

    return unless $tweet->{text};

    $tweet->{processed} = tweet_processor($tweet);
    $tweet->{created_at} = scalar localtime;

    return unless $tweet->{processed};

    my $escaped = $tweet;#$recursive->encode_numeric($tweet);

    my $tweet_text = JSON::to_json($escaped);
    say $tweet_text;
    $client->post("http://localhost:2222/new", [
        tweet => $tweet_text, secret => $secret
    ], sub { print Dumper \@_; });
}

sub tweet_processor {
    my $tweet = shift;

    my $text  = defined $tweet->{retweeted_status}{text}
        ? sprintf 'RT @%s: %s',
            $tweet->{retweeted_status}{user}{screen_name}, $tweet->{retweeted_status}{text}
        : $tweet->{text};

    my $tag = q{<a href="http://%s" target="_blank"><img src="http://%s" class="thumb" /> %s</a>};
    my %web = (
        yfrog   => sprintf($tag, 'yfrog.com/%s', 'yfrog.com/%s.th.jpg'),
        twitpic => sprintf($tag, 'twitpic.com/%s', 'twitpic.com/show/thumb/%s'),
        movapic => sprintf($tag, 'movapic.com/pic/%s', 'image.movapic.com/pic/m_%s.jpeg'),
        gyazo   => sprintf($tag, '%s', 'gyazo.com/%s.png'),
        nico    => sprintf($tag, 'nicovideo.jp/watch/sm%s',
                    'tn-skr2.smilevideo.jp/smile?i=%s', '%s'),
        plixi   => sprintf($tag, '%s',
                    'http://api.plixi.com/api/TPAPI.svc/imagefromurl?size=medium&url=http://%s'),
    ); 

    my %basic = (
        url   => q{<a href="%s" target="_blank">%s</a>},
        reply => q{@<a href="http://twitter.com/%s" target="_blank">%s</a>},
        hash  => q{<a href="http://search.twitter.com/search?q=%%23%s" target="_blank">%s</a>},
        community => q{<img src="http://icon.nimg.jp/community/s/%s.jpg" class="thumb_mini" />},
    );

    my $html = '';
    for my $token (split $regex, $text) {
        next unless defined $token;

        my $safe_token = HTML::Entities::encode($token);

        if ($token =~ /^$re{url}/) {

            if ($token =~ m!http://twitpic\.com/(\w+)!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{twitpic}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://yfrog\.com/(\w+)!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{yfrog}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://movapic\.com/pic/(\w+)!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{movapic}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://(?:www\.nicovideo\.jp/watch|nico\.ms)/sm(\w+)!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{nico}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://(plixi\.com/p/\d+)!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{plixi}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://gyazo\.com/(\w+)\.png!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{gyazo}, $safe_token, $encoded, $safe_token;

            } else {
                $html .= sprintf $basic{url}, $safe_token, $safe_token;
            }

        } elsif ($token =~ m!^\#([A-Za-z0-9_]+)$!) {
            my $hash_ent = encode_entities($1);
            $html .= sprintf $basic{hash}, $hash_ent, $safe_token;

        } elsif ($token =~ m!^\@([A-Za-z0-9_]+)$!) {
            my $user = encode_entities($1);
            $html .= sprintf $basic{reply}, $user, $user;

        } elsif ($token =~ m!^co\d+!) {
            $html .= sprintf $basic{community}, $safe_token;

        } else {
            $html .= $safe_token;
        }
    }

    return $html =~ /(?:4sq\.com|shindanmaker\.com|tou\.ch|讀賣|阪神|野球|拝金|相互フォロー)/
        ? undef
        : $html;
}

__END__

