use strict;
use warnings;
use File::Spec;
use File::Basename;
use Data::Dumper;
use JSON;
use Encode;

$main::confbase = File::Basename::dirname(__FILE__) . '/../config/';

$main::Tweets = {};
$main::Filter = do File::Spec->catfile($main::confbase, 'filter.pl') or die $!;
$main::OAuth  = do File::Spec->catfile($main::confbase, 'oauth.pl')  or die $!;
$main::guid   = do File::Spec->catfile($main::confbase, 'guid.pl')   or die $!;
$main::phrase = do File::Spec->catfile($main::confbase, 'phrase.pl') or die $!;
$main::secret = do File::Spec->catfile($main::confbase, 'secret.pl') or die $!;

package Logout;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
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

sub get {
    my $self = shift;

    if ($self->request->session->{verified}) {
        $self->response->redirect('/');
    } else {
        $self->render('login.html', {});
    }

    $self->finish;
}

sub post {
    my $self = shift;

    if ($self->request->param('phrase') eq $main::phrase) {
        $self->request->session->{verified} = 1;
        $self->request->session_options->{change_id}++;
        $self->response->redirect('/');
    } else {
        $self->render('login.html', {});
    }

    $self->finish;
}

package Root;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    $self->render('root.html', {});
    $self->finish;
}

package Twitter;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
use Try::Tiny;
use AnyEvent::Twitter;
use HTML::Entities::Recursive;

my $ua = AnyEvent::Twitter->new(%$main::OAuth);
my $recursive = HTML::Entities::Recursive->new;

sub get {
    my $self = shift;
    my $api  = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    my $requested_opts = $self->request->parameters;

    my %opts;
    for my $key (keys %$requested_opts) {
        $opts{$key} = Encode::decode_utf8($requested_opts->{$key});
    }

    $ua->request(method => 'GET', api => $api,
        params => {%opts}, sub { $self->on_response(@_); });
}

sub post {
    my $self = shift;
    my $api  = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    my $requested_opts = $self->request->parameters;

    my %opts;
    for my $key (keys %$requested_opts) {
        $opts{$key} = Encode::decode_utf8($requested_opts->{$key});
    }

    $ua->request(method => 'POST', api => $api,
        params => {%opts}, sub { $self->on_response(@_); });
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
        $self->render('login.html', {});
        $self->finish;
    }

    $self->render('settings.html', {});
    $self->finish;
}

package API::Filter;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
use Try::Tiny;

sub get {
    my $self = shift;

    unless ($self->request->env->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    $self->response->content_type('application/json');
    $self->finish(JSON::encode_json($main::Filter));
}

sub post {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    $self->response->content_type('application/json');

    my $screen_name = $self->request->param('screen_name');
    my $filter = $self->request->param('filter');

    if ($screen_name && $filter) {
        $main::Filter->{$screen_name} = $filter;

        try {
            open my $fh, '>', $main::confbase . "filter.pl" or die $!;
            print $fh Data::Dumper::Dumper($main::Filter);
            close $fh;

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
use Try::Tiny;

sub get {
    my $self = shift;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    my $rv = {};
    for my $name (keys %{$main::Tweets}) {
        $rv->{$name} = scalar @{$main::Tweets->{$name}};
    }

    $self->response->content_type('application/json');
    $self->finish(JSON::encode_json($rv));
}

package New;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);
use Try::Tiny;

sub post {
    my $self = shift;

    if ($self->request->param('secret') ne $main::secret) {
        $self->finish("ERROR");
    }

    my $tweet = try {
        JSON::decode_json($self->request->param('tweet')) } catch { undef };

    unless ($tweet) {
        $self->finish("ERROR");
    }

    if (my $filter = $main::Filter->{$tweet->{user}{screen_name}}) {
        push @{$main::Tweets->{$filter}}, $tweet;
    } else {
        push @{$main::Tweets->{timeline}}, $tweet;
    }

    $self->finish("OK");
}

package API::Tweet::Show;
use parent 'Tatsumaki::Handler';
__PACKAGE__->asynchronous(1);

sub get {
    my ($self, $filter) = @_;

    unless ($self->request->session->{verified}) {
        $self->render('login.html', {});
        $self->finish;
    }

    $filter ||= 'timeline';

    my @v;
    while (@{$main::Tweets->{$filter}}) {
        last if 20 <= scalar @v;
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
    path      => [File::Basename::dirname(__FILE__) . "/../templates"],
    cache_dir => File::Spec->tmpdir,
);

sub get {
    my $self = shift;

    if ($self->request->env->{'HTTP_X_DCMGUID'} ne $main::guid) {
        $self->response->redirect('/');
    }

    my $filter = $self->request->param('filter');
    $filter ||= 'timeline';

    my @v;
    while (@{$main::Tweets->{$filter}}) {
        last if 20 <= scalar @v;
        my $item = shift @{$main::Tweets->{$filter}};
        #$item->{processed} =~ s{http://}{http://mobazilla.jp/index.php?}g;
        push @v, $item;
    }

    my $unread = {};
    for my $name (keys %{$main::Tweets}) {
        $unread->{$name} = scalar @{$main::Tweets->{$name}};
    }

    my $body = $xslate->render('mobile_root.html', {unread => $unread, list => \@v});
    #$self->render('mobile_root.html', {unread => $unread, list => \@v});

    $self->response->content_type('text/html');
    $self->finish(Encode::encode_utf8($body));
}

package main;

use Plack::Builder;
use Plack::Middleware::Session;
use Plack::Session::Store::File;
use Plack::Session::State::Cookie;
use Plack::Middleware::DoCoMoGUID;
use Tatsumaki::Application;

my $app = Tatsumaki::Application->new([
    '/twitter/([a-zA-z0-9_/]+)' => 'Twitter',
    '/api/tweet/show/([\w\-]+)' => 'API::Tweet::Show',
    '/api/filter/unread' => 'API::Filter::Unread',
    '/api/filter' => 'API::Filter',
    '/settings' => 'Settings',
    '/logout' => 'Logout',
    '/login' => 'Login',
    '/' => 'Root',
]);

$app->template_path(File::Basename::dirname(__FILE__) . "/../templates");
$app->static_path(File::Basename::dirname(__FILE__) . "/../static");

my $mobile = Tatsumaki::Application->new([
    '' => 'Mobile::Root',
]);

$mobile->template_path(File::Basename::dirname(__FILE__) . "/../templates");
$mobile->static_path(File::Basename::dirname(__FILE__) . "/../static");

my $on_tweet = Tatsumaki::Application->new([
    '' => 'New',
]);

builder {
    enable 'Lint';
    #enable 'Debug';

    mount '/mobile' => builder {
        $mobile;
    };

    mount '/new' => $on_tweet;

    mount '/' => builder {
        enable 'Session',
            store => Plack::Session::Store::File->new(
                dir => File::Basename::dirname(__FILE__) . "/../sessions"
            ),
            state => Plack::Session::State::Cookie->new(
                session_key => 'uid',
            );
        $app;
    };
}

__END__

