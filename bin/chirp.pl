use practical;
use FindBin '$Bin';
use lib "$Bin/../lib";
use App::FakeTwitter;

local $| = 1;
local $App::FakeTwitter::PORT = 10000;

my $confbase = "$Bin/../config";
my $OAuth    = do "$confbase/oauth.pl"  or die $!;
my $secret   = do "$confbase/secret.pl" or die $!;

my $cv = AE::cv;

say "ALERT: wake up";
my $listener = App::FakeTwitter->new(
    cv     => $cv,
    oauth  => $OAuth,
    secret => $secret,
)->run;

$cv->recv;

__END__

