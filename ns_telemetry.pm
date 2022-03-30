#    NIGHTSTEPS_RUN --> geolocation calculation for Nightsteps software 
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


package ns_telemetry{
    
    use strict;
    use warnings;
    use lib ".";
    use ns_gpio;
    use Math::Polygon;
    use Math::Polygon::Calc;
    use GIS::Distance;
    use Math::Clipper;
    use Math::Trig;

    sub new{
        my $class = shift;
        my $this = {
            _gis => GIS::Distance->new(),
            _gpslog => 'gpsout.txt',
            _gpspath => '/home/pi/nsdata/',
            _compass => ns_gpio->new('c',0),
            _compasslog => {count=>0, value=>0},
            _presPosition => {lat =>'', lon =>'', course=>'', time=>''},
            _indicatorLED => ns_gpio->new('digOut',3),
            _LEDwarnings => {gps=>['t','l100','h500','l200','h500','l1000'],
                            compass=>['t','l50','h50','l50','h50','l50','h50','l50']},
            _LEDsuccess => {gps=>['t','l300','h100','l1200']},
            _GPSchecks => 0
        };
        bless $this, $class;
        return $this;
    }

    sub getDegreeToMetre{
        my $this = shift;
        my $l = shift;
        #print "lat: $l->{lat}, lon: $l->{lon}\n";
        my $DLon = $this->{_gis}->distance( $l->{lat},$l->{lon} => $l->{lat},$l->{lon}+1);
        my $DLat = $this->{_gis}->distance( $l->{lat},$l->{lon} => $l->{lat}+1,$l->{lon});
        my $DLen->{lon} = $DLon->meters();
        $DLen->{lat} = $DLat->meters();
        return $DLen;
    }

    sub getDistanceInMetres{
        my ($this, $l1, $l2) = @_;
        my $distance = $this->{_gis}->distance( $l1->{lat}, $l1->{lon} => $l2->{lat}, $l2->{lon} );
        return $distance->meters;
    }

    sub getPointToPointAngle{
        my ($this, $l1, $l2) = @_;
        my $delta_x = $l2->{lon} - $l1->{lon};
        my $delta_y = $l2->{lat} - $l1->{lat};
        my $radians = atan2($delta_y, $delta_x);
        my $degrees = $radians * (180/pi);
        return $degrees;
    }

    sub getLeftRightPosition{
        my ($this, $angle1, $angle2) = @_;
        my $diff = $angle2 - $angle1;
    }

    sub prepPolyCo{
        my ($this, $rh_loc, $ra_shape) = @_;
        my $DLen = $this->getDegreeToMetre($rh_loc);
        my $poly = Math::Polygon->new(@{$ra_shape});
        #print "Poly rotate course: $rh_loc->{course}\n";
        my $spun = $poly->rotate(centre=>[0,0], degrees=>$rh_loc->{course});
        my $polyco = $this->convertPolyCoord($spun, $rh_loc, $DLen);
        return $polyco;
    }

    sub convertPolyCoord{
        my ($this, $poly, $l, $DLen) = @_; 
    #    print "\nchecking incoming from spun\n";
#        $this->printPolyPoints($poly);
        my @points = $poly->points;
        my @coord = (); 
        foreach my $p(@points){
            my $lat = ($p->[1]/$DLen->{lat}) + $l->{lat};
            my $lon = ($p->[0]/$DLen->{lon}) + $l->{lon};
            my $rlon = sprintf("%.8f", $lon);
            my $rlat = sprintf("%.7f", $lat);
#            print "\n coord point: $rlon,$rlat\n";
            push @coord, [$rlon, $rlat];
        }   
        my $rtn = Math::Polygon->new(@coord);
    #    &printPolyPoints($rtn);
        return $rtn;
    } 

    sub checkPointIsInShape{
        my ($this, $rh_pl, $polyco) = @_;
#        print "test locale: " . $rh_pl->{Lon} . ", " . $rh_pl->{Lat} . "\n";
        my $rtn;
        my @point = ($rh_pl->{lon}, $rh_pl->{lat});
        if ($polyco->contains(\@point)){
            $rtn = 1;
        }else{
            $rtn = 0;
        }
        return $rtn;
    }

#    sub checkShapesOverlap{
#      my ($this, $poly1, $poly2) = @_;
#    }

    sub readGPS{
        my $this = shift;
        my $file = "$this->{_gpspath}$this->{_gpslog}";
        my $gpscheck = 1;
       open GPSLOG, "<$file" or $gpscheck = 0;
        my %loc = ();
        $loc{success} = 0;
        if ($gpscheck){
      #    my $gpsout = `"tail $file"`;
          my @gps = <GPSLOG>;
          my $size = @gps;
          if ($size > 30){
            $size = 30; # only interested in readings from the last half minute, otherwise better to be in error state
          }
      #   print $gps[-1];
          for (my $i=-1; $i>=($size * -1) && $loc{success} == 0; $i-- ){
              chomp $gps[$i];
  #            print $gps[$i];
              if($gps[$i] =~ m/lat: (.+) lon: (.+) time: (.*)/){
                  chomp $3;
                  $loc{lat} = $1;
                  $loc{lon} = $2;
                  $loc{time} = $3;
                  $loc{course} = $this->{_compass}->readValue;
                  if ($loc{course} == $this->{_compasslog}->{value}){
                    $this->{_compasslog}->{count} += 1
                  }else{
                    $this->{_compasslog}->{value} = $loc{course};
                    $this->{_compasslog}->{count} = 0;
                  }
                  if ($this->{_compasslog}->{count} > 150){
                    $this->{_indicatorLED}->writeInstructions($this->{_LEDwarnings}->{compass});
                  }
  #                $loc{course} = $4;
                  print "\n Time: $loc{time} Lon: $loc{lon} Lat: $loc{lat} Course: $loc{course}\n";
                  unless ($loc{lat} eq "nan" || $loc{lon} eq "nan"){
                    $loc{success} = 1;
                    $this->{_presPosition} = \%loc;
                  #  $this->{_indicatorLED}->writeInstructions($this->{_LEDsuccess}->{gps});
                  }else{
                    print "NaN\n";
                    $loc{success} = 0;
                    $this->{_indicatorLED}->writeInstructions($this->{_LEDwarnings}->{gps});
                  }
              }else{
                  $loc{success} = 0;
                  $this->{_indicatorLED}->writeInstructions($this->{_LEDwarnings}->{gps});
              }
          }
          $this->{_checks}++;
      #    close GPSLOG;
        }
#        print "loc success is $loc{success}\n";
        return \%loc;
    }

    sub printPolyPoints{
        my $this = shift;
        my $poly = shift;
        my @rtnpts = $poly->points;
        foreach my $p(@rtnpts){
            print "$p->[0],$p->[1]\n";
        }
    }

}
1;
