use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;

use Plack;
use Plack::Builder;
use Plack::Session;
use Plack::Session::Store::TokyoTyrant;

use JSON;
use Text::Xslate;
use LWP::UserAgent;
use Web::Scraper;

my $phrase = &load_phrase;
warn $phrase;
my $storage = 'http://localhost:5000/';

my $xslate = Text::Xslate->new(
    path      => ['./templates'],
    cache_dir => File::Spec->tmpdir,
);

my $ua = LWP::UserAgent->new();

builder {
    enable 'Lint';

    enable 'Session',
        store => Plack::Session::Store::TokyoTyrant->new(server => ['localhost', 1978]);

    mount '/' => \&app;
    mount '/login' => \&login;
    mount '/logout' => \&logout;
    mount '/timeline' => \&timeline;
    mount '/api/filter/new' => \&api_filter_new;
    mount '/api/unread/count' => \&api_unread_count;
    mount '/api/status' =>\&api_status;
};

sub load_phrase {
    open my $fh, '<', 'phrase' or die $!;
    my $phrase = <$fh>;
    close $fh;
    chomp $phrase;
    return $phrase;
}

sub api_status {
    my $env = shift;

    my $s = $env->{'psgix.session'};
    return [500, ['Content-Type' => 'text/html'], []] unless ($s->{verified});

    my $req = Plack::Request->new($env);
    my $v = $req->parameters;

    my $response = $ua->get("http://twitter.com/" . $v->{screen_name} . '/status/' . $v->{id});
    my $content = $response->decoded_content;

    my $ts = scraper {
        process '.entry-content', 'text' => 'TEXT';
        process '.screen-name', 'screen_name' => 'TEXT';
        process '.profile-pic > img', 'icon' => '@src';
    };

    my $r = encode_json $ts->scrape($content);
    return [200, ['Content-Type' => 'application/json'], [$r]];
}

sub api_unread_count {
    my $env = shift;

    my $s = $env->{'psgix.session'};
    return [500, ['Content-Type' => 'text/html'], []] unless ($s->{verified});

    my $req = Plack::Request->new($env);
    my $v = $req->parameters;

    my $response = $ua->get($storage . 'unread/count');
    my $content = $response->content;

    return [200, ['Content-Type' => 'application/json'], [$content]];
}

sub api_filter_new {
    my $env = shift;

    my $s = $env->{'psgix.session'};
    return [500, ['Content-Type' => 'text/html'], []] unless ($s->{verified});

    my $req = Plack::Request->new($env);
    my $v = $req->parameters;

    my $filter = $v->{filter};
    my $screen_name = $v->{screen_name};

    my $response = $ua->post($storage . "filter", {
        filter => $filter,
        screen_name => $screen_name,
    });

    return [
        200,
        ['Content-Type' => 'text/html'],
        [encode_utf8($response->content)]
    ];
}

sub timeline {
    my $env = shift;

    my $s = $env->{'psgix.session'};
    return [500, ['Content-Type' => 'text/html'], []] unless ($s->{verified});

    my $req = Plack::Request->new($env);
    my $v = $req->parameters;

    my $filter = $v->{filter};
    return [500, ['Content-Type' => 'text/html'], []] unless ($filter);

    my $response = $ua->get($storage . '?filter=' . $filter);
    my $json = decode_json($response->content);

    my $res_unread = $ua->get($storage . 'unread/count');
    my $unread_count = decode_json($res_unread->content);

    my $content = $xslate->render("timeline.xt", {
            json => $json,
            unread_count => $unread_count,
        });

    return [
        200,
        ['Content-Type' => 'text/html; charset=UTF-8'],
        [encode_utf8($content)]
    ];
}

sub logout {
    my $env = shift;

    my $s = Plack::Session->new($env);
    $s->expire;

    return [301, ['Location' => '/'], []];
}

sub login {
    my $env = shift;

    my $s = $env->{'psgix.session'};
    my $req = Plack::Request->new($env);
    my $v = $req->parameters;

    if ($v->{p} eq $phrase) {
        $s->{verified} = 1;
        return [
            200,
            ['Content-Type' => 'text/html'],
            [encode_utf8('<a href="/timeline?filter=timeline">/timeline</a>')]
        ];
    } else {
        return [301, ['Location' => '/'], []];
    }
}

sub app {
    my $env = shift;

    my $s = $env->{'psgix.session'};

    if ($s->{verified}) {
        return [
            200,
            ['Content-Type' => 'text/html'],
            [encode_utf8('<a href="/timeline?filter=timeline">/timeline</a>')]
        ];
    } else {
        my $content = $xslate->render('app.xt', {});
        
        return [
            200,
            ['Content-Type' => 'text/html; charset=UTF-8'],
            [encode_utf8($content)]
        ];
    }
}
