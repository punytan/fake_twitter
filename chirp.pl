#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;

use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use AnyEvent::Twitter::Stream;
use Tatsumaki::HTTPClient;

use URI;
use JSON;
use HTML::Entities;
use Perl6::Slurp;
use Data::Validate::URI ();

our %re = (
    url   => qr{(s?https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)},
    reply => qr{(\@[0-9A-Za-z_]+)},
    hash  => qr{(\#[0-9A-Za-z_]+)},
    com   => qr{\[(co\d+)\]},
);

our $regex = qr/$re{url}|$re{reply}|$re{hash}|$re{com}/;

my $json_text = slurp 'oauth.json';
my $config    = decode_json($json_text);

my $ua     = AnyEvent::Twitter->new(%$config);
my $client = Tatsumaki::HTTPClient->new;

my $cv = AE::cv;

open my $outfile, '+>>', 'chirp.log' or die $!;

my $file; $file = new AnyEvent::Handle
    fh => $outfile,
    on_error => sub {
        my ($file_hdl, $fatal, $msg) = @_;
        warn "Error $msg";
        $file_hdl->destroy;
        $cv->send;
    };

my $listener = AnyEvent::Twitter::Stream->new(
    consumer_key    => $config->{consumer_key},
    consumer_secret => $config->{consumer_secret},
    token           => $config->{access_token},
    token_secret    => $config->{access_token_secret},
    method          => 'userstream',
    on_tweet        => \&on_tweet,
    timeout         => 300,
    on_error        => sub { exit; },
);

$cv->recv;

exit;

sub on_tweet {
    my $tweet = shift;

    if (my $text = $tweet->{text}) {
        $tweet->{processed} = tweet_processor($text);
        $tweet->{created_at} = scalar localtime;

        if ($tweet->{processed}) {
            my $tweet_text = JSON::to_json($tweet);
            $client->post("http://localhost:5000/", [ tweet => $tweet_text ], sub { write_log($tweet); });
        }
    }
}

sub write_log {
    my $tweet = shift;

    my $text = $tweet->{text};
    my $len = length($tweet->{user}{screen_name});
    my $screen_name = $tweet->{user}{screen_name} . ' ' x (15 - $len);
    my $space = ' ' x 15;
    if (length($text) > 70) {
        $text = substr($text, 0, 70) . "\n" . substr($text, 71);
    }
    $text =~ s/[\n|\r|\r\n]/\n$space| /g;

    my $line = encode_utf8("$screen_name| $text \n");
    print $line;
    $file->push_write($line);
}

sub tweet_processor {
    my $text = decode_entities(shift);

    my $html = '';

    for my $token (split $regex, $text) {
        next unless defined $token;

        if ($token =~ /^$re{url}/) {

            if ($token =~ m!http://twitpic\.com/(\w+)!) {
                my $encoded = encode_entities($1);

                $html .= qq{<a href="http://twitpic.com/$encoded" target="_blank">
                    <img src="http://twitpic.com/show/thumb/$encoded" class="thumb" /></a>};

            } elsif ($token =~ m!http://yfrog\.com/(\w+)!) {
                my $encoded = encode_entities($1);

                $html .= qq{<a href="http://yfrog.com/$encoded" target="_blank">
                    <img src="http://yfrog.com/$encoded.th.jpg" class="thumb"/></a>};

            } elsif ($token =~ m!http://movapic\.com/pic/(\w+)!) {
                my $encoded = encode_entities($1);

                $html .= qq{<a href="http://movapic.com/pic/$encoded" target="_blank">
                    <img src="http://image.movapic.com/pic/m_$encoded.jpeg" class="thumb" /></a>};

            } elsif ($token =~ m!http://(?:www\.nicovideo\.jp/watch|nico\.ms)/sm(\w+)!) {
                my $encoded = encode_entities($1);

                $html .= qq{<a href="http://www.nicovideo.jp/watch/sm$encoded" target="_blank">
                    <img src="http://tn-skr2.smilevideo.jp/smile?i=$encoded" class="thumb" /></a>};

            } elsif ($token =~ m!(http://plixi\.com/p/\d+)!) {
                my $encoded = encode_entities($1);

                $html .= qq{<a href="$encoded" target="_blank">
                    <img src="http://api.plixi.com/api/TPAPI.svc/imagefromurl?size=medium&url=$encoded"
                        class="thumb" /></a>};

            } elsif ($token =~ m!http://gyazo\.com/(\w+)\.png!) {
                my $encoded = encode_entities($1);
                my $token_encoded = encode_entities($token);

                $html .= qq{<a href="$token_encoded" target="_blank">
                    <img src="http://gyazo.com/$encoded.png" class="thumb" /></a>};

            } else {
                my $encoded = encode_entities($token);

                $html .= qq{<a href="$encoded" target="_blank">$encoded</a>};
            }

        } elsif ($token =~ m!^\#(.+)$!) {
            my $hash_ent = encode_entities($1);
            my $hash_tag = encode_entities($token);
            $html .= qq{<a href="http://search.twitter.com/search?q=%23$hash_ent" target="_blank">$hash_tag</a>};

        } elsif ($token =~ m!^\@(.+)$!) {
            my $user = encode_entities($1);
            $html .= qq{\@<a href="http://twitter.com/$user" target="_blank">$user</a>};

        } elsif ($token =~ m!^co\d+!) {
            my $co = encode_entities($token);
            $html .= qq{<a href="http://com.nicovideo.jp/community/$co" target="_blank">
                <img src="http://icon.nimg.jp/community/s/$co.jpg" style="height:64px;width:64px;" /></a>};

        } else {
            $html .= encode_entities($token);

        }
    }

    return $html =~ /(?:4sq\.com|shindanmaker\.com|tou\.ch|讀賣|阪神|野球|拝金|相互フォロー)/ ? undef : $html;
}

__END__

