use practical;
use FindBin;
use Data::Dumper;
use JSON;
use Encode;

our $Bin = $FindBin::Bin;
$main::Tweets = {};
$main::Filter = do "$Bin/../config/filter.pl" or die $!;

package Logout;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub post {
    my $self = shift;

    if ($self->request->session->{verified}) {
        $self->request->session_options->{expire}++;
    }
    $self->response->redirect('/');
    $self->finish;
}

package Login;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
my $phrase = do "$Bin/../config/phrase.pl" or die $!;

sub get {
    my $self = shift;

    if ($self->request->session->{verified}) {
        $self->response->redirect('/');
        $self->finish;
    } else {
        $self->render('login.html', {});
    }
}

sub post {
    my $self = shift;

    if ($self->request->param('phrase') eq $phrase) {
        $self->request->session->{verified} = 1;
        $self->request->session_options->{change_id}++;

        if ($self->request->user_agent =~ /iPhone/) {
            $self->response->redirect('/mobile');
        } else {
            $self->response->redirect('/');
        }
        $self->finish;
    } else {
        $self->render('login.html', {});
    }
}

package Root;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;

    if ($self->request->session->{verified}) {
        $self->render('root.html');
    } else {
        $self->render('login.html');
    }
}

package Twitter;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
use AnyEvent::Twitter;
use HTML::Entities::Recursive;

my $OAuth = do "$Bin/../config/oauth.pl" or die $!;

my $ua = AnyEvent::Twitter->new(%$OAuth);
my $recursive = HTML::Entities::Recursive->new;

sub get {
    my ($self, $api) = @_;

    unless ($self->request->session->{verified}) {
        $self->render('login.html');
    }
    $self->do($api, 'GET');
}

sub post {
    my ($self, $api) = @_;

    unless ($self->request->session->{verified}) {
        $self->render('login.html');
    }
    $self->do($api, 'POST');
}

sub do {
    my ($self, $api, $method) = @_;
    my $req_opts = $self->request->parameters->as_hashref;

    my %opts;
    for my $key (keys %$req_opts) {
        $opts{$key} = Encode::decode_utf8($req_opts->{$key});
    }

    $ua->request(
        method => $method,
        api    => $api,
        params => {%opts},
        $self->async_cb(sub {
            $self->on_response(@_)
        })
    );
}

sub on_response {
    my $self = shift;
    my ($hdr, $res, $reason) = @_;

    if ($res) {
        $res = $recursive->decode($res);
        $res = $recursive->encode_numeric($res);
    }

    $self->response->content_type('application/json');
    $self->finish(JSON::to_json([$hdr, $res, $reason]));
}

package Settings;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html');
    }
    $self->render('settings.html');
}

package API::Filter;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
use Try::Tiny;

sub get {
    my $self = shift;

    unless ($self->request->env->session->{verified}) {
        $self->render('login.html');
    }

    $self->response->content_type('application/json');
    $self->finish(JSON::encode_json($main::Filter));
}

sub post {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html');
    }

    $self->response->content_type('application/json');

    my $screen_name = $self->request->param('screen_name');
    my $filter = $self->request->param('filter');

    if ($screen_name && $filter) {
        $main::Filter->{$screen_name} = $filter;

        try {
            open my $fh, '>', "$Bin/../config/filter.pl" or die $!;
            print {$fh} Data::Dumper::Dumper($main::Filter);
            close $fh or die $!;
            $self->finish(JSON::encode_json({success => 1}));
        } catch {
            $self->finish(JSON::encode_json({success => 0}));
        }
    } else {
        $self->finish(JSON::encode_json({success => 0}));
    }
}

package API::Filter::Unread;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html');
    }

    my $rv = {};
    for my $name (keys %{$main::Tweets}) {
        $rv->{$name} = scalar @{$main::Tweets->{$name}};
    }

    $self->response->content_type('application/json');
    $self->finish(JSON::encode_json($rv));
}

package API::Tweet::Show;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $filter) = @_;

    unless ($self->request->session->{verified}) {
        $self->render('login.html');
    }

    $filter ||= 'timeline';

    my @v;
    while (@{$main::Tweets->{$filter} || []}) {
        last if 25 <= scalar @v;
        push @v, shift @{$main::Tweets->{$filter}};
    }

    $self->response->content_type('application/json');
    $self->finish(JSON::to_json(\@v));
}

package Mobile::Root;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
use Text::Xslate;

my $xslate = Text::Xslate->new(
    path      => ["$Bin/../templates"],
    cache_dir => '/tmp',
);

sub get {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
    }

    my $filter = $self->request->param('filter');
    $filter ||= 'timeline';

    my @v;
    while (@{$main::Tweets->{$filter} || []}) {
        last if 25 <= scalar @v;
        my $item = shift @{$main::Tweets->{$filter}};
        push @v, $item;
    }

    my $unread = {};
    for my $name (keys %{$main::Tweets}) {
        $unread->{$name} = scalar @{$main::Tweets->{$name}};
    }

    my $body = $xslate->render('mobile_root.html',
        {unread => $unread, list => \@v});

    $self->response->content_type('text/html');
    $self->finish(Encode::encode_utf8($body));
}

package main;

use Plack::Builder;
use Plack::Middleware::Session;
use Plack::Session::Store::File;
use Plack::Session::State::Cookie;
use Tatsumaki::Application;
use Twiggy::Server;
use AnyEvent::Twitter::Stream;
use HTML::Entities::Recursive;
use FindBin;
use lib "$FindBin::Bin/../lib";
use App::FakeTwitter::Util;

my $oauth_token = do "$Bin/../config/oauth.pl" or die $!;
my $tpath = "$Bin/../templates";
my $spath = "$Bin/../static";

my $app = Tatsumaki::Application->new([
    '/twitter/([a-zA-z0-9_/]+)' => 'Twitter',
    '/api/tweet/show/(.+)' => 'API::Tweet::Show',
    '/api/filter/unread' => 'API::Filter::Unread',
    '/api/filter' => 'API::Filter',
    '/settings' => 'Settings',
    '/logout' => 'Logout',
    '/login' => 'Login',
    '/' => 'Root',
]);
$app->template_path($tpath);
$app->static_path($spath);

my $mobile = Tatsumaki::Application->new([ '' => 'Mobile::Root' ]);
$mobile->template_path($tpath);
$mobile->static_path($spath);

my $mapp = builder {
    mount '/' => builder {
        enable 'Session',
            store => Plack::Session::Store::File->new(
                dir => "$Bin/../sessions"
            ),
            state => Plack::Session::State::Cookie->new(
                session_key => 'uid',
            );
        mount '/mobile' => builder { $mobile; };
        mount '/'       => builder { $app; };
    };
};

my $server; $server = Twiggy::Server->new(
    host => undef,
    port => 10000,
)->register_service($mapp);

my ($STREAM_CONN, $listener);
my $w; $w = AE::timer 1, 10, sub {
    return if $STREAM_CONN;

    say "ALERT: wake up";
    $listener = AnyEvent::Twitter::Stream->new(
        %$oauth_token,
        method     => 'userstream',
        on_error   => sub { $STREAM_CONN = 0; },
        on_connect => sub { $STREAM_CONN = 1; },
        on_tweet   => sub {
            my $tweet = HTML::Entities::Recursive->new->decode(shift);

            return unless $tweet->{text};

            if ($tweet->{source} =~ />(.+)</) {
                $tweet->{source} = $1;
            }

            return if $tweet->{source} =~ /(?:loctouch|foursquare|twittbot\.net|WiTwit|Hatena)/i
                or $tweet->{text} =~ /(?:shindanmaker\.com|Livlis)/i
                or $tweet->{text} =~ /(?:[RＲ][TＴ]|拡散)(?:希望|お?願い|して|よろしく)|\@ikedanob/i
                or $tweet->{text} =~ /[公式]?(?:リ?ツイート|[Q|R]T)された回?数.+(?:する|します)/i
                or $tweet->{text} =~ /(?:[RQ]T:? \@\w+.*){3,}/i;

            my $escaped = HTML::Entities::Recursive->new->encode_numeric($tweet);
            $escaped->{processed} = App::FakeTwitter::Util->new->process($tweet);
            $escaped->{created_at} = scalar localtime;

            return unless $escaped->{processed};

            if (my $filter = $main::Filter->{$tweet->{user}{screen_name}}) {
                push @{$main::Tweets->{$filter}}, $escaped unless $filter eq 'mute';
            } else {
                push @{$main::Tweets->{timeline}}, $escaped;
            }

            $STREAM_CONN = 1;
        },
    );
};

AE::cv->recv;

__END__

