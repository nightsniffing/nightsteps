#    NS_GPIO --> sensor input control for Nightsteps software 
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

package ns_gpio{
    use strict;
    use warnings;
    use Switch;
    use DateTime;

    sub new{
        my $class = shift;
        my $this = {
                    _mode => shift,
                    _channel => shift,
                    _datapath => '/home/pi/nsdata/gpio/',
                    };
        if ($this->{_mode} eq 'a'){
            $this->{_presReadings} = {'','','','','','','',''};
        }
        bless $this, $class;
#        $this->setupReading;
        return $this;
    }

    sub newDateRange{
        my $class = shift;
        my $rh = shift;
        my $this = {
                    _mode => 'dr',  
                    _datapath => '/home/pi/nsdata/gpio/',
                    _drp => $rh,
                    _drlog => {state => '', tr => '', br => ''}
                   };
        bless $this, $class;
        return $this;
    }
    
    sub readDateRange{
        my $this = shift;
        my $ra_sens = $this->readAllAnalogue;
        my $bp = $this->{_drp}->{btmPin};
        my $tp = $this->{_drp}->{topPin};
        my $br = $ra_sens->[$bp];
        my $tr = $ra_sens->[$tp];
        my $rtn = { btm => "error",
                    top => "error",
                    ba => -1,
                    ta => -1 };
        my $ra_vs = $this->{_drp}->{valScale};
        my $size = @{$ra_vs};
        for (my $i=0; $i<$size; $i++) {
            if(($br >= $ra_vs->[$i]->{low}) && ($br <= $ra_vs->[$i]->{high})){
                $rtn->{btm} = $ra_vs->[$i]->{range};
                $rtn->{ba} = $i;
            }
            if(($tr >= $ra_vs->[$i]->{low}) && ($tr <= $ra_vs->[$i]->{high})){
                $rtn->{top} = $ra_vs->[$i]->{range};
                $rtn->{ta} = $i;
            }
        }
        if ($rtn->{btm} eq 'dateRange'){
            my $max = $ra_vs->[$rtn->{ba}]->{low};
            my $min = $ra_vs->[$rtn->{ba}]->{high};
            $rtn->{btm} = $this->convertValsToDates($min, $max, $br);       
        }
        if ($rtn->{top} eq 'dateRange'){
            my $max = $ra_vs->[$rtn->{ta}]->{low};
            my $min = $ra_vs->[$rtn->{ta}]->{high};
            $rtn->{top} = $this->convertValsToDates($min, $max, $tr);       
        }
        $rtn->{state} =  $rtn->{ta} + ($rtn->{ba} * 3); #this creates a unique 0-6 scale for each state, though states 2 and 5 are impossible
                                                        #due to physical constraint
        print "Date Range - $rtn->{state}; Top: $rtn->{top}; Btm: $rtn->{btm}\n";
        $this->{_drlog} = {state => $rtn->{state}, tr => $rtn->{top}, br => $rtn->{btm}};
        return $rtn;
    }

    sub convertValsToDates{
        my ($this, $oldMin, $oldMax, $oldValue) = @_;
        my $ld = $this->{_drp}->{lowDate};
        my $newMin = 0;
        my $newMax = $this->getDifferenceBetweenDates($ld, $this->{_drp}->{highDate}); 
        my $oldRange = ($oldMax - $oldMin);  
        my $newRange = ($newMax - $newMin); 
        my $newValue = ((($oldValue - $oldMin) * $newRange) / $oldRange) + $newMin;
        my $newDate = DateTime->new(year => $ld->year, month => $ld->month, day => $ld->day);
        $newDate->add(days => int($newValue)); 
#        print "low date is now $this->{_drp}->{lowDate}\n";
        return $newDate;
#        return $newDate;
    }

    sub getDifferenceBetweenDates{
        my ($his, $d1, $d2) = @_;
        my $dur = ($d1 > $d2 ? ($d1->subtract_datetime_absolute($d2)) :
                               ($d2->subtract_datetime_absolute($d1)));
        my $days = $d1->delta_days($d2)->delta_days;
        return $days;
    }


    sub setupReading{
        my $this = shift;
#        system "touch $this->{_datapath}$this->{_channel}.$this->{_mode}";
    }

    sub writeInstructions{
        my $this = shift;
        my $ra_instr = shift;
        my $prefix = "";
        if ($this->{_mode} eq 'digOut'){
            $prefix = "dig";
        }elsif ($this->{_mode} eq 'pmwOut'){
            $prefix = "pwm";
        }
        my $file = $this->{_datapath} . $prefix . $this->{_channel} . ".o";
        open (FO, ">", $file);
        foreach my $l (@{$ra_instr}){
            print FO "$l\n";
        }
        close FO;
    }

    sub readValue{
        my $this = shift;
        my $out;
        switch ($this->{_mode}){
            case 'a' {$out = $this->readAnalogue($this->{_channel});}
            case 'd' {$out = $this->readDigital;}
            case 'c' {$out = $this->readCompass;}
            case 'digOut' {print "Not readable";}
        }
        return $out;
    }

    sub readAllAnalogue{
        my $this = shift;
        open SENSOUT, "<$this->{_datapath}a.a" or die $!;
        my @sens = <SENSOUT>;
        my $size = @sens;
        my @out;
        for(my $i=$size-1; $i>0 && @out < 1; $i--){
            chomp $sens[$i];
            if ($sens[$i] =~ m/(\d\d\d\d)-(\d\d\d\d)-(\d\d\d\d)-(\d\d\d\d)-(\d\d\d\d)-(\d\d\d\d)-(\d\d\d\d)-(\d\d\d\d)-/){
                push @out, $1;
                push @out, $2;
                push @out, $3;
                push @out, $4;
                push @out, $5;
                push @out, $6;
                push @out, $7;
                push @out, $8;
			      }
        }
        $this->{_presReadings} = \@out;
        return \@out;
    }


    sub readAnalogue{
        my ($this, $channel) = @_;
        my $rh_out = $this->readAllAnalogue;
        my $out = $rh_out->[$channel];
#        my @sens = <SENSOUT>;
#        my $size = @sens;
#        my $out = -1;
#        for(my $i=$size-1; $i>0 && $out == -1; $i--){
#            chomp $sens[$i];
#            if ($sens[$i] =~ m/(\d\d\d\d)/){
#                $out = $1;
#			}
#        }   
#        print "sensor $channel: $out\n";
        return $out;
    }

    sub readCompass{
        my $this = shift;
        open SENSOUT, "<$this->{_datapath}0.$this->{_mode}" or die $!;
        my @sens = <SENSOUT>;
        my $size = @sens;
        my $out = -1;
        for(my $i=$size-1; $i>0 && $out == -1; $i--){
            chomp $sens[$i];
            if ($sens[$i] =~ m/([0-9]+\.[0-9]+)/){
                $out = $1;
	      		}
        }
        if ($out > 360){
            $out -= 360;
        }
#        print "compass:  $out\n";
        return $out;

    }

    sub readDigital{
        print "readDigital sub not yet written!!\n\n";
    }
}
1;
