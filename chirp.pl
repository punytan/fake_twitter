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

http_request('GET' => $req->to_url,
    want_body_handle => 1,
    on_header => sub {
        my $hdr = shift;
        warn "$hdr->{Status}: $hdr->{Reason}";
    },
    sub {
        my $hdl = shift;
        exit unless $hdl;
        $hdl->on_read(sub { $hdl->push_read( json => \&on_tweet ); });
    }
);

$cv->recv;

exit;

sub on_tweet {
    my ($handle, $json) = @_;
    exit unless $handle;

    if (my $text = $json->{text}) {
        $json->{processed} = tweet_processor($text);
        $json->{created_at} = scalar localtime;

        if ($json->{processed}) {
            my $json_text = JSON::to_json($json);
            $client->post("http://localhost:5000/", [ tweet => $json_text ], sub { write_log($json); });
        }
    }
    $handle->on_read(sub { $handle->push_read( json => \&on_tweet ); });
}

sub write_log {
    my $json = shift;

    my $text = $json->{text};
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
}

sub tweet_processor {
    my $text = shift;

    my @re = ( # add
        qr{\[co(\d+)\]}, # niconico community
        qr{(http://tweetphoto\.com/\d+)}, #tweetphoto
        qr{http://www\.nicovideo\.jp/watch/sm(\w+)}, # nicovideo
        qr{http://movapic.com/pic/(\w+)}, # movapic
        qr{http://yfrog\.com/(\w+)},   # yfrog
        qr{http://twitpic\.com/(\w+)}, # twitpic_re
        qr/@([0-9a-zA-Z_]+)/,          # reply_re
        qr/#([0-9a-zA-Z_]+)/,          # hash_re
        qr{(http://[^ ]+)},            # uri_re
    );

    my $regexp = qr/$re[0]|$re[1]|$re[2]|$re[3]|$re[4]|$re[5]|$re[6]|$re[7]|$re[8]/; # add

    $text =~ s/$regexp/_process($1, $2, $3, $4, $5, $6, $7, $8, $9)/ge; # add

    return $text =~ /(?:4sq\.com|shindanmaker\.com|tou\.ch|讀賣|阪神|野球)/ ? undef : $text;
}

sub _process {
    my @args = reverse @_;

    if (defined $args[0]) {
        return qq{<span class="url"><a href="$args[0]" target="_blank">$args[0]</a></span>};

    } elsif (defined $args[1]) {
        return qq{<a href="http://search.twitter.com/search?q=%23$args[1]" target="_blank">#$args[1]</a>};

    } elsif (defined $args[2]) {
        return qq{\@<a href="http://twitter.com/$args[2]" target="_blank">$args[2]</a>};

    } elsif (defined $args[3]) {
        return qq{<a href="http://twitpic.com/$args[3]" target="_blanmk">
            <img src="http://twitpic.com/show/thumb/$args[3]" class="thumb"/></a>};

    } elsif (defined $args[4]) {
        return qq{<a href="http://yfrog.com/$args[4]" target="_blank">
            <img src="http://yfrog.com/$args[4].th.jpg" class="thumb"/></a>};

    } elsif (defined $args[5]) {
        return qq{<a href="http://movapic.com/pic/$args[5]" target="_blank">
            <img src="http://image.movapic.com/pic/m_$args[5].jpeg" class="thumb" /></a>};

    } elsif (defined $args[6]) {
        return qq{<a href="http://www.nicovideo.jp/watch/sm$args[6]" target="_blank">
            <img src="http://tn-skr2.smilevideo.jp/smile?i=$args[6]" class="thumb" /></a>};

    } elsif (defined $args[7]) {
        return qq{<a href="$args[7]" target="_blank">
            <img src="http://tweetphotoapi.com/api/TPAPI.svc/imagefromurl?size=medium&url=$args[7]"
                class="thumb" /></a>};

    } elsif (defined $args[8]) {
        return qq{<img src="http://icon.nimg.jp/community/s/co$args[8].jpg"
            style="width:64px;height:64px;display:block"/>};

    } else {
        # noop

    }
}

__END__

