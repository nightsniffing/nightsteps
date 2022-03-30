use strict;
use warnings;
use ns_chuckout;
use Math::Trig;

my $ck = ns_chuckout->new("basic1");



my $so1 =   {
                panning => 0.2,
                starttime => 0.12,
                gain => 0.1,
                freq => 400,
                dur => 30,
            };

my $so2 =   {
                panning => 0.6,
                starttime => 0.67,
                gain => 0.9,
                freq => 1604,
                dur => 70,
            };

my $so3 =   {
                panning => 0.6,
                starttime => 0.84,
                gain => 0.7,
                freq => 2000,
                dur => 60,
            };
my @a;
push @a, $so1;
push @a, $so2;
push @a, $so3;

$ck->basicOut(\@a);
