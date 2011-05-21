package App::FakeTwitter::Util;
use strict;
use warnings;
our $VERSION = '0.04';

use HTML::Entities;

our %re = (
    url   => qr{(s?https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)},
    reply => qr{(\@[0-9A-Za-z_]+)},
    hash  => qr{(\#[0-9A-Za-z_]+)},
    com   => qr{\[(co\d+)\]},
);

our $regex = qr/$re{url}|$re{reply}|$re{hash}|$re{com}/;

our $tag = q{<img src="http://%s" class="thumb" /><a href="http://%s" target="_blank">%s</a>};

our %web = (
    yfrog     => sprintf($tag, 'yfrog.com/%s.th.jpg', 'yfrog.com/%s', '%s'),
    twitpic   => sprintf($tag, 'twitpic.com/show/thumb/%s', 'twitpic.com/%s', '%s'),
    movapic   => sprintf($tag, 'image.movapic.com/pic/m_%s.jpeg', 'movapic.com/pic/%s', '%s'),
    gyazo     => sprintf($tag, 'gyazo.com/%s.png', 'gyazo.com/%s.png', '%s'),
    instagram => sprintf($tag, 'api.linknode.net/instagram/%s', 'instagr.am/p/%s', '%s'),
    nico      => sprintf($tag,
        'tn-skr2.smilevideo.jp/smile?i=%s', 'www.nicovideo.jp/watch/sm%s', '%s'),
    plixi     => sprintf($tag,
        'api.plixi.com/api/TPAPI.svc/imagefromurl?size=medium&url=http://%s', '%s', '%s'),
    twipple   => sprintf($tag, 'p.twipple.jp/data/%s_m.jpg', 'p.twipple.jp/%s', '%s'),
);

our %basic = (
    url   => q{<a href="%s" target="_blank">%s</a>},
    reply => q{@<a href="http://twitter.com/%s" target="_blank">%s</a>},
    hash  => q{<a href="http://search.twitter.com/search?q=%%23%s" target="_blank">%s</a>},
    community => q{<img src="http://icon.nimg.jp/community/s/%s.jpg" class="thumb_mini" />},
);

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub process {
    my $self  = shift;
    my $tweet = shift;

    my $text  = defined $tweet->{retweeted_status}{text}
        ? sprintf 'RT @%s: %s',
            $tweet->{retweeted_status}{user}{screen_name}, $tweet->{retweeted_status}{text}
        : $tweet->{text};

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
                $html .= sprintf $web{gyazo}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://instagr.am/p/([\w\-]+)!) {
                my $encoded = encode_entities($1);
                $html .= sprintf $web{instagram}, $encoded, $encoded, $safe_token;

            } elsif ($token =~ m!http://p\.twipple\.jp/([\w]+)!) {
                my $encoded = encode_entities($1);
                my @part = join '/', split //, $encoded;
                my $str = join '', @part;
                $html .= sprintf $web{twipple}, $str, $encoded, $safe_token;

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

    return $html;
}

sub is_valid_tweet {
    my ($self, $tweet) = @_;

    use utf8;
    return if $tweet->{source} =~ /(?:loctouch|foursquare|twittbot\.net|WiTwit|Hatena)/i
           or $tweet->{text} =~ /(?:shindanmaker\.com|Livlis)/i
           or $tweet->{text} =~ /(?:[RＲ][TＴ]|拡散)(?:希望|お?願い|して|よろしく)|\@ikedanob/i
           or $tweet->{text} =~ /[公式]?(?:リ?ツイート|[Q|R]T)された回?数.+(?:する|します)/i
           or $tweet->{text} =~ /(?:[RQ]T:? \@\w+.*){3,}/i;

    return 1;
}

1;
__END__

