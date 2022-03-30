 ####################################################################
# This is the central logic hub of nightsteps, where each possible #
# process it can run lives, as used by nightsteps_run. It gives a  #
# subroutinte for a single iteration of the logic, before returning#
# to nightsteps_run to see if the user has switched                #
####################################################################

package ns_loopit{
    use strict;
    use warnings;
    use lib ".";
    use ns_testtools;
    use ns_dbinterface;
    use ns_telemetry;
    use ns_audinterface;
    use ns_gpio;
    use ns_logger;
    use Switch;
    use Time::Piece;
    use Data::Dumper;

    sub new{
        my $class = shift;
        my $rh = shift;
        my $this = {
            _daterange => $rh->{daterange},
            _logic => $rh->{logic},
            _val => $rh->{val},
            _option => $rh->{option},
            _maxdist => $rh->{maxdist},
            _query => $rh->{query},
            _datalightfile => '/home/pi/nsdata/gpio/dig1.o',
            _warnlightfile => '/home/pi/nsdata/gpio/dig2.o',
            _lastdataset => {viewcount=>0, viewIDs=>{}, detectcount=>0, detectcount_l=>0, detectcount_r=>0, dsig=>[]},
            _testtools => ns_testtools->new($rh->{printmsg}),
            _telem => ns_telemetry->new,
            _db => ns_dbinterface->new,
            _dbfilepath => '/home/pi/nsdata/',
            _t => Time::Piece->new,      
        };
        my @time = localtime(time);
        $this->{_listenshapeLeft} = $rh->{listenshapeLeft};
        $this->{_listenshapeRight} = $rh->{listenshapeRight};
        my $year = $time[5] + 1900;
        if ($this->{_printmsg}) { print "present year is $year";}
        $this->{_maxyear} = $year;
        bless $this, $class;
        $this->{_logger} = ns_logger->new($this, 1, \@time);
        $this->loopitSetup;
        return $this;
    }

    sub loopitSetup{
        my $this = shift;
        switch ($this->{_logic}){
#            case "LDDBpercuss1"{ $this->LDDBpercussSetup} this has been removed May 2020
#            case "LDDBpercuss2"{ $this->LDDBpercussSetup}
            case "percussIt"{ $this->percussSetup}
        }
    }

    sub iterate{
        my $this = shift;
        switch ($this->{_logic}){
#            case "LDDBpercuss1"{ $this->LDDBpercussIt} this has been removed May 2020
#            case "LDDBpercuss2"{ $this->LDDBpercussItPoly}
            case "percussIt"{ $this->percussItPoly}
            case "percussDemo"{ $this->percussDemoIt}
        }
        $this->{_logger}->logData;
    }

    #####################################################
    ### Configurable Block #############################

    sub percussDemoIt{
        my $this = shift;
        #my @fn = ("digtest1.o", "digtest2.o", "digtest3.o", "digtestPause.o");
#        my @fn = ("pwmtest1.o", "pwmtest3.o");
        my @demotrack = ( {src=>"/home/pi/nsdata/gpio/dsig_demo_l.o", dst=>"/home/pi/nsdata/gpio/dsig_l.o"},
                          {src=>"/home/pi/nsdata/gpio/dsig_demo_r.o", dst=>"/home/pi/nsdata/gpio/dsig_r.o"},
                          {src=>"/home/pi/nsdata/gpio/dig1_demo.o", dst=>$this->{_datalightfile}} );
        my $size = @demotrack;
        for(my $i=0; $i<$size; $i++){
            $this->{_testtools}->outputText("cp $demotrack[$i]->{src} $demotrack[$i]->{dst}");
            system "cp $demotrack[$i]->{src} $demotrack[$i]->{dst}";
        }
        $this->{_lastdataset}->{datacount} = "demo";
        $this->{_lastdataset}->{viewcount} = "demo";
        sleep(1);
    }

    sub percussSetup{
        my $this = shift;
        $this->{_testtools}->outputText("$this->{_query}->{databaseName}, $this->{_query}->{databaseType})\n");
        $this->{_db}->connectDB($this->{_query}->{databaseName}, $this->{_query}->{databaseType}, $this->{_query}->{databasePw});
        $this->{_pcField} = $this->{_query}->{viewQuery}->{options}->{$this->{_option}}->{percentileFieldAndQuery};
        my $pc = $this->{_query}->{percentileQuery}->{$this->{_pcField}};
        $this->{_thres}->{_pcField} = $this->{_pcField};
        $this->{_thres}->{_pcBands} = $pc->{bands};
        $this->{_thres}->{_distanceBands} = $this->{_query}->{listenSettings};
        my $sql = $pc->{query};
        my $ra = $this->{_db}->runsql_rtnArrayRef($sql);
        my $size = @{$ra};
        for (my $i=0; $i<$size; $i++){
          $this->{_thres}->{_pcBands}->[$i+1]->{minval} = $ra->[$i]; #the PC band is at $i+1 because the lowest band has a max val i.e zero! 
        }
        $this->{_testtools}->outputText("setting up aud\n");
        $this->{_aud} = ns_audinterface->new($this->{_query}->{_sonification}, $this->{_thres}, $this->{_option});
        $this->{_aud}->{_minyear} = $this->{_query}->{minDate}->{year};
        $this->{_aud}->{_maxyear} = $this->{_query}->{maxDate}->{year};
    }

    sub percussItPoly{
        my $this = shift;
        my $rh_loc = $this->{_telem}->readGPS;
        if ($rh_loc->{success} == 1){
            $this->{_testtools}->outputText("GPS success!\n");
            my $rah_places = $this->prepPolygonPlaces($rh_loc);
            $this->pipSortDataset($rah_places);
            if ($rah_places){
                $this->{_testtools}->outputText("sending data light signal\n");
                my @datalight = ("q", "h50", "l50");
                $this->pipSigSound($rah_places);
                $this->{_aud}->physSendInstructions($this->{_datalightfile}, \@datalight);
            }else{
                $this->{_lastdataset}->{dsig} = $this->{_aud}->createEmptyScore; 
                #$this->{_aud}->resetSonicSig; 
                $this->{_testtools}->outputText("sending data light signal\n");
                my @datalight = ("q", "h10","l25","h10", "l50");
                $this->{_aud}->physSendInstructions($this->{_datalightfile}, \@datalight);
            }
#        }elsif ($this->{_soundmode} == 2){
        }else{
            $this->{_lastdataset}->{dsig} = $this->{_aud}->createEmptyScore; 
            my @warnlight = ("t", "h50", "l100");
            $this->{_testtools}->outputText("sending status light signal\n");
            $this->{_aud}->physSendInstructions($this->{_warnlightfile}, \@warnlight);
        }
    }

    sub pipSortDataset{
        my ($this, $rah_places) = @_;
        @{$rah_places} = sort { $b->{detected_left} <=> $a->{detected_left}    or 
                                $b->{detected_right} <=> $a->{detected_right}    or 
                                $a->{distance} <=> $b->{distance} 
                              } @{$rah_places};
    }

    sub pipSigSound{
        my ($this, $rah_places) = @_;
        my @do;
        foreach my $rh_pl (@{$rah_places}){
            if ($rh_pl->{detected_left} || $rh_pl->{detected_right}){
                $this->{_testtools}->outputText("$rh_pl->{borough_ref} detected! Left $rh_pl->{detected_left}. Right $rh_pl->{detected_right}. Distance is $rh_pl->{distance}\n\n");
                push @do, $rh_pl;
            }
        }
        $this->{_lastdataset}->{datacount} = @do;
        if (@do){
            $this->{_lastdataset}->{dsig} = $this->{_aud}->createScore(\@do);
        }else{
            $this->{_lastdataset}->{dsig} = $this->{_aud}->createEmptyScore;
        }
    }

    sub prepPolygonPlaces{
        my ($this, $rh_loc) = @_;
        my $viewFormed = $this->createNearbyView($rh_loc);
        my $rah = [];
        if ($viewFormed) {
          my $rh_view = $this->{_query}->{viewQuery};
          my $rh_geoquery = $this->{_query}->{geosonQuery};
          my $option = $this->{_option};
          my $sql = "SELECT COUNT($rh_view->{keyField}->{name}) FROM $rh_view->{viewName}";
          $this->{_lastdataset}->{viewcount} = $this->{_db}->runsql_rtnScalar($sql);
          $this->{_testtools}->outputText("$this->{_lastdataset}->{viewcount} in view \n"); 
          my $ra_geofield = $this->setupPlaceGeoFields($rh_loc);
          # Now we go on to the polygon calcs
          my @fields = ();
          push @fields, @{$rh_geoquery->{otherSelectFields}};
          push @fields, @{$ra_geofield};
          if ($this->{_query}->{geosonQuery}->{options}->{$option}){
              push @fields, $this->{_query}->{geosonQuery}->{options}->{$option}->{fields};
          }
          my %sqlhash = ( fields=>\@fields,
                      table=>$rh_geoquery->{from},
                      where=>"",
  #                    groupbys=>\(),
                      having=>"",
                      orderby=>"");
          $rah = $this->{_db}->runSqlHash_rtnAoHRef(\%sqlhash, 1);
        }else{
          $this->{_testtools}->outputText("View formation failed\n");
        }
        return $rah;
    }

    sub createNearbyView{
        my ($this, $rh_loc) = @_;
        $this->{_testtools}->outputText("creating view sub started\n");
        my $DLen = $this->{_telem}->getDegreeToMetre($rh_loc);
        my $scoopDist = 600; # this is how far away the points are the sniffer can check. For very large sites, this may cause problems.
        my $dateCondition = $this->createDateCondition;
        my $option = $this->{_option};
        my $rh_sc = $this->{_query}->{viewQuery}->{options}->{$option};
        my $distlon = $scoopDist/$DLen->{lon};
        my $distlat = $scoopDist/$DLen->{lat};
        #Get the dimensions of the query box we are looking in/
        my %lon = (min=>$rh_loc->{lon} - $distlon, max=>$rh_loc->{lon} +$distlon) ;
        my %lat = (min=>$rh_loc->{lat} - $distlat, max=>$rh_loc->{lat} +$distlat) ;
        my $rh_view = $this->{_query}->{viewQuery};
        #first we have to do a view that limits what we are looking at, so we don't have to do complicated polygon calcs on the whole DB!
        my $groupby = $rh_view->{otherGroupbyFields} . ", $rh_view->{latField}, $rh_view->{lonField}, $rh_view->{keyField}->{table}\.$rh_view->{keyField}->{name}";
        my $field = "$groupby, $rh_view->{selectOnlyFields}";
        if (length($rh_sc->{fields}) > 1){
          $field .= ", $rh_sc->{fields} ";
        } 
#        foreach my $f (@{$rh_sc->{ra_fields}}){ $field .= ", $f";}
        my $from = $rh_view->{from} . $rh_sc->{from}; 
        my $where =  " WHERE ($rh_view->{lonField} BETWEEN $lon{min} AND $lon{max}) AND " .
                     "($rh_view->{latField} BETWEEN $lat{min} AND $lat{max}) " . 
                      $dateCondition . $rh_sc->{where};
        my $having = $rh_view->{having} . $rh_sc->{having} ;
        $this->{_testtools}->outputText("dropping existing view...\n");
        my $sv = $this->{_db}->runsql_rtnSuccessOnly("DROP VIEW IF EXISTS $rh_view->{viewName};");
        $this->{_testtools}->outputText("creating view...\n");
        my $sql = "CREATE VIEW $rh_view->{viewName} AS SELECT $field FROM $from $where GROUP BY $groupby $having;";
        $this->{_testtools}->outputText($sql);
        my $sq = $this->{_db}->runsql_rtnSuccessOnly($sql);
        return $sq;
    }
 
    sub setupPlaceGeoFields{
        my ($this, $rh_loc) = @_;
        my @geofield;
        #if ($this->{_soundmode} != 0){
        my @listenPolys = ($this->{_telem}->prepPolyCo($rh_loc, $this->{_listenshapeLeft}),
                          $this->{_telem}->prepPolyCo($rh_loc, $this->{_listenshapeRight}));
        my @poly;
        foreach my $lp (@listenPolys){
            my @listenPts = $lp->points;
            my $polyStr = "";
            foreach my $pt (@listenPts){ $polyStr .= "$pt->[0] $pt->[1],"; }
            chop $polyStr;
            push @poly, $polyStr;
        }
        my $geoshape = $this->{_query}->{geosonQuery}->{polygonField};
        my $geopoint = $this->{_query}->{geosonQuery}->{pointField};
        @geofield = ( "CASE WHEN $geoshape IS NOT NULL THEN ST_DWithin($geoshape\::geography, 'SRID=4326;POLYGON(($poly[0]))'::geography, 5) " . 
                      "ELSE ST_DWithin($geopoint\::geography, 'SRID=4326;POLYGON(($poly[0]))'::geography, 5) END AS detected_left",  
                      "CASE WHEN $geoshape IS NOT NULL THEN ST_DWithin($geoshape\::geography, 'SRID=4326;POLYGON(($poly[1]))'::geography, 5) " . 
                      "ELSE ST_DWithin($geopoint\::geography, 'SRID=4326;POLYGON(($poly[1]))'::geography, 5) END AS detected_right",  
                      "CASE WHEN $geoshape IS NOT Null THEN ST_Distance($geoshape\::geography, 'SRID=4326;POINT($rh_loc->{lon} $rh_loc->{lat})'::geography) " . 
                      "ELSE ST_Distance($geopoint\::geography, 'SRID=4326;POINT($rh_loc->{lon} $rh_loc->{lat})'::geography) END AS distance");
        return \@geofield;
    }
 
    sub createDateCondition{
        my $this = shift;
        $this->{_testtools}->outputText("creating date condition\n");
        my $dateset = $this->{_query}->{viewQuery}->{dateFields};
        my $statusfield = $dateset->{stausField};
        my $rh = $this->{_daterange}->readDateRange;
        my $cond;
        switch ($rh->{state}){
            case (0){  # StillToCome status 
                        $cond = " AND " . $dateset->{undecidedStatusCheck};}
            case (3){
                        $cond = " AND ( $dateset->{undecidedStatusCheck}  OR $dateset->{stillToComeStatusCheck})";}
            case (4){
                        $cond = " AND " . $dateset->{stillToComeStatusCheck};}

            case (6){  # StillToCome <--> Lower Date Range
                        my $btmyear = $rh->{btm}->strftime('%Y-%m-%d');
                        $cond = " AND ($dateset->{stillToComeStatusCheck} OR $dateset->{undecidedStatusCheck} OR ($dateset->{dateRangeStatusCheck} AND $dateset->{dateField} >= '$btmyear'))";
                    }
            case (7){  # StillToCome <--> Lower Date Range
                        my $btmyear = $rh->{btm}->strftime('%Y-%m-%d');
                        $cond = " AND ($dateset->{stillToComeStatusCheck} OR ($dateset->{dateRangeStatusCheck} AND $dateset->{dateField} >= '$btmyear'))";
                    }
            case (8){  # Upper Date Range <--> Lower Date Range
                        my $topyear = $rh->{top}->strftime('%Y-%m-%d');
                        my $btmyear = $rh->{btm}->strftime('%Y-%m-%d');
                        $cond = " AND ($dateset->{dateRangeStatusCheck} AND $dateset->{dateField} <= '$topyear' AND $dateset->{dateField} >= '$btmyear') ";
                    }
            case (9){ # All conditions
                        my $topyear = $this->{_daterange}->{_drp}->{highDate};
                        my $btmyear = $this->{_daterange}->{_drp}->{lowDate};
                        $cond = " AND ($dateset->{undecidedStatusCheck} OR $dateset->{mightHaveBeenStatusCheck} OR $dateset->{stillToComeStatusCheck} OR " .
                                " ($dateset->{dateRangeStatusCheck} AND $dateset->{dateField} <= '$topyear' AND $dateset->{dateField} >= '$btmyear')) ";
                    }
            case (10){ # All conditions bar undecided
                        my $topyear = $this->{_daterange}->{_drp}->{highDate};
                        my $btmyear = $this->{_daterange}->{_drp}->{lowDate};
                        $cond = " AND ($dateset->{mightHaveBeenStatusCheck} OR $dateset->{stillToComeStatusCheck} OR " .
                                " ($dateset->{dateRangeStatusCheck} AND $dateset->{dateField} <= '$topyear' AND $dateset->{dateField} >= '$btmyear')) ";
                    }
            case (11){ # Upper Data Range <--> mightHaveBeen
                        my $topyear = $rh->{top}->strftime('%Y-%m-%d');
                        my $btmyear = $this->{_daterange}->{_drp}->{lowDate};
                        #$cond = " AND (status_rc = 'DELETED' OR status_rc = 'LAPSED' OR (status_rc = 'COMPLETED' AND p.completed_date <= '$topyear')) ";
                        $cond = " AND ($dateset->{mightHaveBeenStatusCheck} OR ($dateset->{dateRangeStatusCheck} AND $dateset->{dateField} <= '$topyear'  AND $dateset->{dateField} >= '$btmyear'))";
                    }
            case (12){  # mighthaveBeen; 
                        $cond = " AND $dateset->{mightHaveBeenStatusCheck}";}
        }
        return $cond;
    }
}
1;
