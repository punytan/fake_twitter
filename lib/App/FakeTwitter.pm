package App::FakeTwitter;
use practical;
our $VERSION = '0.02';

use constant DEBUG => $ENV{FT_DEBUG};
use JSON;
use Encode;
use HTML::Entities::Recursive;
use Tatsumaki::HTTPClient;
use AnyEvent::Twitter::Stream;
use App::FakeTwitter::Util;

use parent 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/
    cv oauth secret util client recursive
/);

our $PORT = 10000;

sub new {
    my $class = shift;
    my %args  = @_;

    return bless {
        cv     => $args{cv},
        oauth  => $args{oauth},
        secret => $args{secret},
        util   => App::FakeTwitter::Util->new,
        client => Tatsumaki::HTTPClient->new,
        recursive => HTML::Entities::Recursive->new,
    }, $class;
}

sub run {
    my $self = shift;

    return AnyEvent::Twitter::Stream->new(
        %{ $self->oauth },
        method   => 'userstream',
        timeout  => 45,
        on_tweet => sub {
            $self->on_tweet(@_);
        },
        on_error => sub {
            say "ALERT: on error";
            $self->cv->send;
        },
    );
}

sub on_tweet {
    my $self  = shift;
    my $tweet = $self->recursive->decode(shift);

    return unless $tweet->{text};

    if ($tweet->{source} =~ />(.+)</) {
        $tweet->{source} = $1;
    }

    return if $tweet->{source} =~ /(?:loctouch|foursquare|twittbot\.net|WiTwit|Hatena)/i
           or $tweet->{text} =~ /(?:shindanmaker\.com|Livlis)/i
           or $tweet->{text} =~ /(?:[RＲ][TＴ]|拡散)(?:希望|お?願い|して|よろしく)|\@ikedanob/i
           or $tweet->{text} =~ /[公式]?(?:リ?ツイート|[Q|R]T)された回?数.+(?:する|します)/i
           or $tweet->{text} =~ /(?:[RQ]T:? \@\w+.*){3,}/i;

    my $escaped = $self->recursive->encode_numeric($tweet);
    $escaped->{processed} = $self->util->process($tweet);
    $escaped->{created_at} = scalar localtime;

    return unless $escaped->{processed};

    my $tweet_text = JSON::to_json($escaped);
    $self->client->post("http://localhost:$PORT/new", [
        tweet  => $tweet_text,
        secret => $self->secret
    ], sub {
         if (DEBUG) {
            $tweet->{text} =~ s/\r|\n//g;
            print Encode::encode_utf8 "<$tweet->{user}{screen_name}> $tweet->{text}\n";
        }
    });
}

1;
__END__

=head1 NAME

App::FakeTwitter -

=head1 SYNOPSIS

  use App::FakeTwitter;

=head1 DESCRIPTION

App::FakeTwitter is

=head1 AUTHOR

punytan E<lt>punytan@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
