#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;

use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Twitter;
use Tatsumaki::HTTPClient;

use URI;
use JSON;
use Perl6::Slurp;
use Data::Validate::URI ();

my $json_text = slurp 'oauth.json';
my $config    = decode_json($json_text);

my $ua     = AnyEvent::Twitter->new(%$config);
my $client = Tatsumaki::HTTPClient->new;

my $req = $ua->_make_oauth_request(
    request_url    => 'http://chirpstream.twitter.com/2b/user.json',
    request_method => 'GET',
    extra_params   => {}
);

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

$cv->begin;
http_request('GET' => $req->to_url,
    want_body_handle => 1,
    on_header => sub {
        my $hdr = shift;
        warn "$hdr->{Status}: $hdr->{Reason}";
    },
    sub {
        my $hdl = shift;

        my $r = sub {
            my (undef, $json) = @_;
            if (my $text = $json->{text}) {
                $json->{processed} = tweet_processor($text);

                if ($json->{processed}) {
                    my $json_text = JSON::to_json($json);
                    $client->post("http://localhost:5000/", [
                        tweet => $json_text,
                    ], sub {
                        my $len = length($json->{user}{screen_name});
                        my $screen_name = $json->{user}{screen_name} . ' ' x (15 - $len);
                        my $space = ' ' x 15;
                        if (length($text) > 70) {
                            $text = substr($text, 0, 70) . "\n" . substr($text, 71);
                        }
                        $text =~ s/[\n|\r|\r\n]/\n$space| /g;

                        my $line = encode_utf8("$screen_name| $text \n");
                        print $line;
                        $file->push_write($line);
                    });
                }
            }
        };
        $hdl->on_read(sub { $hdl->push_read( json => $r ); });
    }
);

$cv->recv;

sub tweet_processor {
    my $text = shift;

    $text =~ s{(http://[\S]+)}{<span class="url"><a href="$1">$1</a></span>}g;
    $text =~ s{\@([0-9a-zA-Z_]+)}{\@<a href="http://twitter.com/$1" target="_blank">$1</a>}g;
    $text =~ s{\s+#([0-9a-zA-Z_]+)}{<a href="http://search.twitter.com/search?q=%23$1" target="_bkank">#$1</a>}g;

    if ($text =~ /(?:4sq\.com|shindanmaker\.com|tou\.ch)/) {
        return undef;
    } else {
        return $text;
    }
}

__END__

