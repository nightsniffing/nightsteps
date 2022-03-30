#    NS_TESTTOOLS --> debugging tools for Nightsteps software 
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
#


package ns_testtools{
    use strict;
    use warnings;
#    use Data::Dumper;
# generic test tools for nightsteps modules
    sub new{
        my $class = shift;
        my $debug = shift;
        my $this = {_debug=>$debug};
        print $this->{_debug};
        bless $this, $class;
        return $this;
    }

    sub outputText{
      my ($this, $text) = @_;
      if ($this->{_debug} == 1){
        print $text;
      }
    }

    sub printRefArray{
        my ($this, $ra) = @_;
        my $size = @{$ra};
        print "testtools: printing array\n";
        for (my $i=0; $i<$size; $i++){
            print $ra->[$i] . "\n";
        }

    }

    sub printRefHashValues{
        my ($this, $rh_hash) = @_;
        my @keys = keys %{$rh_hash};
        my $size = @keys;
        for (my $i=0; $i < $size; $i++){
            print $keys[$i] . " = " . $rh_hash->{$keys[$i]} . "\n";
        }
    }

    sub printRefArrayOfHashes{
        my ($this, $rah) = @_;
        my $size = @{$rah};
        print "testtools: printing array\n";
        for (my $i=0; $i<$size; $i++){
            print "New line...\n";
            my @keys = keys %{$rah->[$i]};
            foreach my $k (@keys){
                print $k . ": " . $rah->[$i]->{$k} . "\n";        
            }
        }
    }

}1;
