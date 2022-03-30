#    NS_CONFIG --> configruation for Nightsteps software 
#    Copyright (C) 2022 Cliff Hammett
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.


package ns_config{
  use strict;
  use warnings;
  use DateTime;
  use JSON;

  sub new{
    my $class = shift;
    my $rh = shift;
    my $this = {};
    bless $this, $class;
    $this->{_json} = JSON->new;
    return $this;
  }

  sub defineControlParameters{
    my $this = shift;
#    my $qs = $this->buildQuerySetup("/home/pi/nsdata/querydefs/ldd1.json");
    my $qs = $this->buildQuerySetup("/home/pi/nsdata/querydefs/ns1.json");
    my @switchbands = (
        {low=>35, high=>110, logic=>'percussDemo'},
        {low=>135, high=>200, logic=>'percussIt', query=>$qs, option=>"textsearch-changeofuse"},
        {low=>240, high=>350, logic=>'percussIt', query=>$qs, option=>"textsearch-demolition"},
        {low=>400, high=>500, logic=>'percussIt', query=>$qs, option=>"socialhousing-decrease"},
        {low=>580, high=>760, logic=>'percussIt', query=>$qs, option=>"socialhousing-increase"},
        {low=>930, high=>1024, logic=>'percussIt', query=>$qs, option=>"everything"}
        );
    my @dateScale = (
        {low=>0, high=>175, range=>'undecided'},
        {low=>176, high=>353, range=>'stillToCome'},
        {low=>354, high=>890, range=>'dateRange'},
        {low=>891, high=>1023, range=>'mightHaveBeen'},
    );
    my %dateRangeProperties = (
            btmPin => 5,
            topPin => 6,
            lowDate => DateTime->new($qs->{minDate}),
            highDate => DateTime->new($qs->{maxDate}),
            valScale => \@dateScale
        );
    $this->{_switchbands} = \@switchbands;
    $this->{_dateRangeProperties} = \%dateRangeProperties;
    return $this;
  }

  sub buildQuerySetup{      
    my $this = shift;
    my $filename = shift;
    print "$filename\n";
    my $json_text = do {
      open(my $json_fh, "<:encoding(UTF-8)", $filename)
        or die("Can't open \$filename\": $!\n");
      local $/;
      <$json_fh>
    };
#    print "initial processing\n";
#    print $json_text;
    my $qs = $this->{_json}->decode($json_text);
    return $qs;
  }
}1;

