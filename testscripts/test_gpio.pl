use strict;
use warnings;
use ns_gpio;

my $aport = ns_gpio->new('a',7);
sleep 1;
my $out = $aport->readValue;
print $out;
