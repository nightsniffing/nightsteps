#    NS_AUDINTERFACE --> signal output control for Nightsteps software 
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

package ns_audinterface{
#the audio interface layer translates data structures into audio parameters;
    use strict;
    use warnings;
    use lib ".";
    use Switch;
    use ns_testtools;
#    use ns_audlibrary;
    use Math::Round qw(round);
    use Data::Dumper;

    sub new {
        my ($class, $son, $thres, $option) = @_;
        my $ra_rules = $son->{rules};
        if ($son->{optionSpecificRules}->{$option}){
          push @{$ra_rules}, @{$son->{optionSpecificRules}->{$option}};
        }
        my $rh_effects = $son->{effectSets};
        if ($son->{optionSpecificEffects}->{$option}){
          $rh_effects = {$rh_effects, $son->{optionSpecificEffects}->{$option}};
        }
        my $this  = {
#            _mode => shift,
            _sonicspace=>1152,
            _scorelines=>24,
            _linedur=>48,
            _standardbeatdur=>4,
            _thres => $thres,
            _sonification => $son,
            _rules => $ra_rules,
            _effects=> $rh_effects,
            _testtools => ns_testtools->new(0),
#            _audlib => ns_audlibrary->new,
            _outputs => [{path=>'/home/pi/nsdata/gpio/dsig_l.o', field=>'detected_left', ra_sig=>[]}, 
                         {path=>'/home/pi/nsdata/gpio/dsig_r.o', field=>'detected_right', ra_sig=>[]}],
            _gpoutpath => '/home/pi/nsdata/gpio/'
        };
        bless $this, $class;
        return $this;
    }

    sub physSendInstructions{
        my ($this, $file, $ra_instr) = @_;
        open (FO, ">", $file);
        foreach my $l (@{$ra_instr}){
            print FO "$l\n";
        }
        close FO;
    }

######################################## NEWNEWNEW SONIC LOGIC ##############################################
#############################################################################################################

  sub createScore{
    my ($this, $rah_do) = @_;
    my $number = @{$rah_do};
    $this->{_testtools}->outputText("creating score from $number records\n");
    foreach my $out (@{$this->{_outputs}}){
      $out->{ra_sig} = [];
    }

    foreach my $rh_do (@{$rah_do}){
      my $o = 0;
      foreach my $out (@{$this->{_outputs}}){
        if ($rh_do->{$out->{field}}){
          $o++;
          $this->{_testtools}->outputText("$out->{field} is true\n");
        }
      }
      foreach my $out (@{$this->{_outputs}}){
        my $ra_instr = [];
        if ($rh_do->{$out->{field}}){
          my $distthres;
          my $rh_attr = {elecount =>16, repeats=>0, solstr=>0, rhythmstr=>0};
          if ($o == 2){
            $distthres = $this->{_thres}->{_distanceBands}->{centreThresholds};
          }else{
            $distthres = $this->{_thres}->{_distanceBands}->{offcentreThresholds};
          }      
          if ($rh_do->{$out->{field}}){
            $ra_instr = $this->generateScoreColumn($rh_do, $rh_attr, $out, $distthres);
          }
        }else{
          $ra_instr = $this->generateEmptyColumn;
        }
        push @{$out->{ra_sig}}, $ra_instr;
      }
    }
    $this->outputScore;
    return $this->{_outputs};
  }

  sub createEmptyScore{
    my $this = shift;
    $this->{_testtools}->outputText("creating empty score\n");
    foreach my $out (@{$this->{_outputs}}){
      $out->{ra_sig} = [];
      my $ra_instr = $this->generateEmptyColumn;
      push @{$out->{ra_sig}}, $ra_instr;
    }
    $this->outputScore;
    return $this->{_outputs};
  }

  sub generateScoreColumn{
    my ($this, $rh_do, $rh_attr, $out, $distthres) = @_;
    #print "generating Score column\n";
    my $ra_instr = [];
    #print Dumper($distthres);
    foreach my $t (@{$distthres}){
      $this->{_testtools}->outputText("$rh_do->{distance} <> $t->{maxdist}\n");
      if ($rh_do->{distance} < $t->{maxdist}){
        $rh_attr->{repeats} = $t->{repeats};
        $rh_attr->{solstr} = $t->{solstr};
      }
    }
    foreach my $b (@{$this->{_thres}->{_pcBands}}){
      my $solbonus = 0;
      #print Dumper($rh_do->{$this->{_thres}->{_pcBands}});
      $this->{_testtools}->outputText("MINVAL:  $b->{minval}\n");
      $this->{_testtools}->outputText("Field: $this->{_thres}->{_pcField}\n");
      $this->{_testtools}->outputText("Act Val: $rh_do->{$this->{_thres}->{_pcField}}\n");
      if ($rh_do->{$this->{_thres}->{_pcField}} > $b->{minval}){
        $rh_attr->{rhythmstr} = $b->{rhythmstr};
        $solbonus = $b->{solstr};
      }
      $rh_attr->{solstr} += $solbonus; 
    }
    #print Dumper($rh_attr);
    if ($rh_attr->{repeats} > 0){
      my $base = $this->generateBase($rh_do->{descr}, $rh_attr->{rhythmstr});
      my $ra_rhythm = $this->processBaseIntoRhythm($base, $rh_attr->{rhythmstr});
      $ra_instr = $this->convertRhythmIntoInstr($rh_attr, $ra_rhythm);
    }else{
      #print "no repeats\n";
      $ra_instr = $this->generateEmptyColumn;
    }
    #print "pre returned instr:\n";
    return $ra_instr;
  }

  sub generateEmptyColumn{
    my $this = shift;
    my @instr = ();
    $this->{_testtools}->outputText("generating Empty Column\n");
    for(my $i=0; $i<$this->{_scorelines}; $i++){
      my $l = {line=>"d$this->{_linedur}\@f0", hasstrike=>0};
      my $ra_l = $l;
      push @instr, $ra_l;
    }
    return \@instr;
  }

  sub outputScore{
    my $this = shift;
    foreach my $out (@{$this->{_outputs}}){
      my @lines = ();
      $this->{_testtools}->outputText("Outputting to $out->{path}\n");
      #foreach my $ra (@{$ra_sig}){
      my $ra = $out->{ra_sig};
      my $sizerows = @{$ra->[0]};
      my $sizecolumns = @{$ra};
      for (my $i=0; $i<$sizerows; $i++){
        my $l = "";
        for (my $k=0; $k<$sizecolumns; $k++){
          if ($k > 0){ $l .= "|";}
          $l .= $ra->[$k]->[$i]->{line};
        }
        push @lines, $l;
      }
      $this->physSendInstructions($out->{path}, \@lines);
    }
  }

  sub generateBase{
    my ($this, $s, $v) = @_;
    $this->{_testtools}->outputText("generating base from: $s\n");
    my $substr = substr $s, 0, 31;
    my @char = split //, $s;
    my $size = @char;
    my @prebaserhythm;
    my @baserhythm;
    for (my $i=0; $i<32; $i+=2){
      my $cn = 0;
      if ($i < $size){
       $cn = ord($char[$i]);
      }
      $this->{_testtools}->outputText("$cn\n");
      push @prebaserhythm, $cn;
    }
    my @percentile = sort {$a <=> $b} @prebaserhythm;
    my $pp = $this->makePercentileThres($v);
    my $small = $percentile[$pp->[0]];
    my $medium = $percentile[$pp->[1]];
    my $large = $percentile[$pp->[2]];
    foreach my $n (@prebaserhythm){
      if ($n <= $small)    { push @baserhythm,0}
      elsif ($n <= $medium){ push @baserhythm,1}
      elsif ($n <= $large) { push @baserhythm,2}
      else                { push @baserhythm,3};
    }
    return \@baserhythm;
  }

  sub makePercentileThres{
      my ($this, $v) = @_;
      my @thres = ([9,12,15],
                   [8,11,14],
                   [7,10,13],
                   [6,9,12],
                   [4,8,11]);
      return $thres[$v];
  }


  sub processBaseIntoRhythm{
      my ($this, $ra, $v) = @_;
      $this->{_testtools}->outputText("processing base into rhythm\n");
      my $laststate = "";
      my $lastval = 0;
      my $size = @{$ra};
      my @rhythm = ();
      #my $st = $this->makeStrengthValues($v); #v must be between 0 and 4
      my $st = {strongcrit=> 3, strongthres => 2, restcrit =>0};
      my $p = -1;
      for (my $i=0; $i<$size; $i++){
        if ($lastval == $st->{strongcrit} && $ra->[$i] >= $st->{strongthres} && $laststate eq "littlebeat"){
          $rhythm[$p]->{type} = "strongbeat";
          $rhythm[$p]->{ebLength} += 1;
          $laststate = "strongbeat";
        }elsif ($lastval < $st->{strongcrit} && $lastval > $st->{restcrit} &&  $ra->[$i] == 1 && $laststate eq "littlebeat"){
          $rhythm[$p]->{ebLength} += 1;
        }elsif ($ra->[$i] <= $st->{restcrit} && $laststate eq "rest"){
          $rhythm[$p]->{ebLength} += 1;
        }elsif ($ra->[$i] <= $st->{restcrit}){
          my $rh = {type => "rest", ebLength => 1};
          push @rhythm, $rh;
          $p++;
          $laststate = "rest";
        }else{
          my $rh = {type => "littlebeat", ebLength => 1};
          push @rhythm, $rh;
          $p++;
          $laststate = "littlebeat";
        }
        $lastval = $ra->[$i];
      }
      return \@rhythm;
  }

  sub makeStrengthValues{
    my ($this, $i) = @_;
    my @val = ({strongcrit=> 4, strongthres => 2, restcrit =>1},
               {strongcrit=> 3, strongthres => 2, restcrit =>1},
               {strongcrit=> 3, strongthres => 1, restcrit =>1},
               {strongcrit=> 3, strongthres => 1, restcrit =>0},
               {strongcrit=> 2, strongthres => 1, restcrit =>0});
    return $val[$i];
  }

  sub convertRhythmIntoInstr{
    my ($this, $rh, $ra_rhythm) = @_;
    $this->{_testtools}->outputText("converting rhythm into instr\n");
    my $rhylength = @{$ra_rhythm};
    my $blockdur = $this->{_sonicspace} / ($rh->{elecount} * $rh->{repeats});
    $this->{_testtools}->outputText("Blockdur is $blockdur\n");
    my @scorepart = ();
    my $curdur = 0;
    my $linesadded = 0;
    my $uf = 0;
    my $rh_attr = { blockdur=>$blockdur,
                    baseStrength=>$rh->{solstr},
                    unfinishedLine=>$uf };
    for(my $i=0;$linesadded < $this->{_scorelines}; $i++){
      if ($i == $rhylength){
        $this->{_testtools}->outputText("resetting\n");
        $i=0;
      }
      $rh_attr->{type} = $ra_rhythm->[$i]->{type};
      $rh_attr->{eleBlockLength} = $ra_rhythm->[$i]->{ebLength};
      my $ra_curBeat = $this->resolveBeat($rh_attr);
      for my $c (@{$ra_curBeat}){
        #print Dumper($c);
        if ($c->{ttldur} >= $this->{_linedur}){
          push @scorepart, $c;
          $rh_attr->{unfinishedLine} = 0;
          $linesadded++;
        }else{
          $rh_attr->{unfinishedLine} = $c;
        }
      }
    }
    return \@scorepart;
  }
  
  sub resolveBeat{
    my ($this, $rh_attr) = @_;
    my $ra_return = [];
    switch ($rh_attr->{type}){
      case "rest"{ $ra_return = $this->addRestBlock($rh_attr)}
      case "strongbeat"{ $ra_return = $this->addStrongBeatBlocks($rh_attr)}
      case "littlebeat"{ $ra_return = $this->addLittleBeatBlocks($rh_attr)}
      case "tap"{ $ra_return = $this->addTapBlocks($rh_attr)}
    }
    return $ra_return;
  }

  sub addRestBlock{
    my ($this, $rh_attr) = @_;
    my $rah = [{dur=>$rh_attr->{blockdur} * $rh_attr->{eleBlockLength},
                force=>0}
                ];
    my $ra_return = $this->composeBlock($rh_attr, $rah);
    return $ra_return;
  }

  sub addStrongBeatBlocks{
    my ($this, $rh_attr) = @_;
    my $dur = $rh_attr->{blockdur} * $rh_attr->{eleBlockLength}; 
    my $rah = [{dur=>($dur/2)-$this->{_standardbeatdur},
                force=>0},
               {dur=>$this->{_standardbeatdur} * 2,
                force=>$rh_attr->{baseStrength}},
               {dur=>($dur/2)-$this->{_standardbeatdur},
                force=>0}
                ];
    my $ra_return = $this->composeBlock($rh_attr, $rah);
    return $ra_return;
  }
  
  sub addLittleBeatBlocks{
    my ($this, $rh_attr) = @_;
    my $dur = $rh_attr->{blockdur} * $rh_attr->{eleBlockLength}; 
    my $rah = [{dur=>($dur/2)-($this->{_standardbeatdur}/2),
                force=>0},
               {dur=>$this->{_standardbeatdur},
                force=>$rh_attr->{baseStrength}},
               {dur=>($dur/2)-($this->{_standardbeatdur}/2),
                force=>0}
                ];
    my $ra_return = $this->composeBlock($rh_attr, $rah);
    return $ra_return;
  }

  sub addTapBlocks{
    my ($this, $rh_attr) = @_;
    my $dur = $rh_attr->{blockdur};
    my $reps = $rh_attr->{eleBlockLength}; 
    my $rah = [];
    for (my $i=0; $i<$reps; $i++){
      push @{$rah}, {dur=>($dur/2)-($this->{_standardbeatdur}/2),force=>0};
      push @{$rah}, {dur=>$this->{_standardbeatdur}, force=>$rh_attr->{baseStrength}};
      push @{$rah}, {dur=>($dur/2)-($this->{_standardbeatdur}/2),force=>0};
    }
    my $ra_return = $this->composeBlock($rh_attr, $rah);
    return $ra_return;
  }

  sub composeBlock{
    my ($this, $rh_attr, $rah) = @_;
    my $ra_return;
    if ($rh_attr->{unfinishedLine}){
      $ra_return = [$rh_attr->{unfinishedLine}]
    }else{
      $ra_return = [{line => "",
                    ttldur => 0,
                    hasstrike => 0}];
    }
    my $i = 0;
    for my $rh (@{$rah}){
      #print Dumper($rh);
      while ($rh->{dur} > 0){
        my $remains = $this->{_linedur} - $ra_return->[$i]->{ttldur};
        my $pref = "";
        if ($rh->{force} > 0){
          $ra_return->[$i]->{hasstrike} = 1;
        }
        if ($rh->{dur} > $remains){
          if (length($ra_return->[$i]->{line}) > 0){
            $pref = ",";
          }
          $ra_return->[$i]->{line} .= $pref . "d$remains\@f$rh->{force}";
          $ra_return->[$i]->{ttldur} += $remains;
          $rh->{dur} -= $remains;
          push @{$ra_return}, {line=>"", ttldur=> 0, hasstrike => 0};
          $i++;
        }else{
          if (length($ra_return->[$i]->{line}) > 0){
            $pref = ",";
          }
          $ra_return->[$i]->{line} .= $pref . "d$rh->{dur}\@f$rh->{force}";
          $ra_return->[$i]->{ttldur} += $rh->{dur};
          $rh->{dur} = 0;
        }
      }
    }
    return $ra_return;
  }

}
1;



