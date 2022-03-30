#    NS_LOGGER --> Logging functions for Nightsteps software 
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


package ns_logger{
    use strict;
    use warnings;
    use File::Copy;
#    use Time::Piece qw(datetime);    

    sub new{
        my $class = shift;
        my $this = {
            _loop => shift,
            _dsigLogging => shift
        };
        my $rh_time = shift;
        my $i = 0;
        my $rht = {year=>$rh_time->[5]+1900, month=>$rh_time->[4]+1, day=>$rh_time->[3], hour=>$rh_time->[2], min=>$rh_time->[1]};
        my $ts = sprintf '%04d-%02d-%02d-%02d%02d', $rht->{year}, $rht->{month}, $rht->{day}, $rht->{hour}, $rht->{min};
        my $fname = "/home/pi/nsdata/log/log$ts-" . (sprintf("%03d",$i)) . ".txt";
        while (-f $fname) {
            $fname = "/home/pi/nsdata/log/log$ts-" . (sprintf("%03d",++$i)) . ".txt";
        }
        $this->{_ts} = $ts;
        $this->{_logfile} = $fname;
        open LOG, ">>$this->{_logfile}" or die $!;
#        print LOG "logic: $this->{_loop}->{_logic}\n";
        my $headings = '"time","gpstime","lat","lon","compass","daterange_state","daterange_upper","daterange_lower","logicsound","sniffversion","sniffvalue","viewcount","datacount","gpio-a-all.py","compass.py","sig.py","dig.py"';
        print "dsig logging is $this->{_dsigLogging}\n";
        if ($this->{_dsigLogging}){
            $headings .= ',"dsig_l_file","dsig_r_file"';
        }
        print LOG "$headings\n"; 
        close LOG;
        bless $this, $class;
        return $this; 
    }

    sub logData{
        my $this = shift;
        print "logging data to $this->{_logfile}\n";
        my $rhGPS = $this->{_loop}->{_telem}->{_presPosition};
        my $rhDateRange = $this->{_loop}->{_daterange}->{_drlog};
#        my $time = $this->{_loop}->{_t}->datetime;
        my %daemon = ( "gpio-a-all.py"=>0,
				                  "compass.py"=>0,
                          "sig.py"=>0,
                          "dig.py"=>0);
        my @nsrun = `ps aux | grep nightsteps`;
        my @keys = keys %daemon;
        foreach my $l (@nsrun){
            foreach my $k(@keys){
           #l print $l;
                if ($l =~ m/$k/){
                    $daemon{$k} = 1;
                }
            }
        }

        my $time = localtime;
        open (LOG, ">>$this->{_logfile}") or die $!;
        print LOG "$time,";
        print LOG "$rhGPS->{time},$rhGPS->{lat},$rhGPS->{lon},$rhGPS->{course},";
        print LOG "$rhDateRange->{state},$rhDateRange->{tr},$rhDateRange->{br},";
#        print LOG "$this->{_loop}->{_logic},$this->{_loop}->{_version},$this->{_loop}->{_val},";
        print LOG "$this->{_loop}->{_logic},$this->{_loop}->{_option},,";
        if ($this->{_loop}->{_lastdataset}->{viewcount}) {
          print LOG "$this->{_loop}->{_lastdataset}->{viewcount},$this->{_loop}->{_lastdataset}->{datacount},";
        }else{
          print LOG '"n/a","n/a",';
        }
        print LOG "$daemon{'gpio-a-all.py'},$daemon{'compass.py'},$daemon{'sig.py'},$daemon{'dig.py'}";
        if ($this->{_dsigLogging}){
          my $dsigFiles = $this->dsigLogging();
          print LOG $dsigFiles;
        }
        print LOG "\n";
        close (LOG) or die "Couldn't close file";
    }

    sub dsigLogging{
        my $this = shift;
        my @dsigLogFile;
        my $i = 0;
        $dsigLogFile[0] = "/home/pi/nsdata/log/dsig/$this->{_ts}-0-" . (sprintf("%07d",$i)) . ".o";
        while (-f $dsigLogFile[0]) {
          $dsigLogFile[0] = "/home/pi/nsdata/log/dsig/$this->{_ts}-0-" . (sprintf("%07d",++$i)) . ".o";
        }
        my $rtn = ",$dsigLogFile[0]";
        my $ra_dsig = $this->{_loop}->{_lastdataset}->{dsig};
        my $size = @{$ra_dsig};
        for (my $k=1; $k<$size; $k++){
          $dsigLogFile[$k] = "/home/pi/nsdata/log/dsig/$this->{_ts}-$k-" . (sprintf("%07d",$i)) . ".o";
          $rtn .= ",$dsigLogFile[$k]"
        }
        for (my $l=0; $l<$size; $l++){
          copy($ra_dsig->[$l]->{path}, $dsigLogFile[$l]);
        }
        return $rtn  
    }

}1;
