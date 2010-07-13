use strict;
use warnings;
use utf8;
use Encode;
use Data::Dumper;

use JSON;
use Time::HiRes ();

use Tatsumaki;
use Tatsumaki::Error;
use Tatsumaki::Application;

package main;

our $T = {};
# hashref is $T->{filter}{unread}{time}{id}

our $FILTER = &read_filter;
# hashref is $FILTER->{filter_name}{lc screen_name}

my $app = Tatsumaki::Application->new([
    "/" => 'Root',
    "/filter" => 'Filter',
    "/unread/count" => 'UnreadCount',
]);

return $app;

sub read_filter {
    open my $fh, '<', 'filter.json' or die;
    my $json_text = <$fh>;
    close $fh or die $!;
    
    my $filter = JSON::decode_json($json_text);
    return $filter;
}

package Root;
use base qw/Tatsumaki::Handler/;

sub get {
    my $self = shift;

    my $v = $self->request->parameters;

    my $filter = $v->{filter};

    unless ($filter) {
        # fix me
        $self->finish('{"success":0}');
    }

    my $RV = {};
    for my $time (sort keys %{$main::T->{$filter}{unread}}) {
        last if (20 <= scalar keys %{$RV->{$filter}});

        my ($id) = keys %{$main::T->{$filter}{unread}{$time}};
        my $item = $main::T->{$filter}{unread}{$time};

        $RV->{$filter}{$time} = $item->{$id};

        delete $main::T->{$filter}{unread}{$time};
    }

    local $@;
    $RV->{success} = 1;
    $RV->{filter} = $filter;
    my $json_text = eval { JSON::to_json($RV); };
    $self->finish($@ ? '{"success":0}' : $json_text);
}

sub post {
    my $self = shift;

    my $v = $self->request->parameters;

    my $item = JSON::decode_json($v->{tweet});
    my $id = lc $item->{user}{screen_name};

    my $tab;
    for my $filter (keys %{$main::FILTER}) {
        for my $screen_name (keys %{$main::FILTER->{$filter}}) {
            if ($screen_name eq $id) {
                $tab =  $filter;
            }
        }
    }
    $tab ||= 'timeline';

    my $time = Time::HiRes::time;
    $main::T->{$tab}{unread}{$time}{$item->{id}} = $item;

    $self->finish('{"success":1');
}

package Filter;
use base qw/Tatsumaki::Handler/;
use Fcntl qw/:flock/;

sub get {
    shift->finish(JSON::encode_json($main::FILTER));
}

sub post {
    my $self = shift;

    my $v = $self->request->parameters;

    my $name = $v->{filter};
    my $screen_name = lc $v->{screen_name};

    $main::FILTER->{$name}{$screen_name} = 0;

    my $json_string = JSON::encode_json($main::FILTER);

    # of cource this process blocks, but this is not executed frequentry
    open my $fh, '>', 'filter.json' or die $!;
    flock $fh, LOCK_EX;
    print $fh $json_string;
    close $fh or die $!;

    $self->finish($json_string);
}

package UnreadCount;
use base qw/Tatsumaki::Handler/;

sub get {
    my $self = shift;

    my $v = $self->request->parameters;

    my %r;
    for (keys %$main::T) {
        $r{$_} = scalar keys %{$main::T->{$_}{unread}};
    }

    {
        local $@;
        $r{success} = 1;
        my $json_text = eval { JSON::encode_json(\%r) };
        $self->finish($@ ? '{"success":0}' : $json_text);
    }
}
