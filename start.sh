#! /bin/bash

echo "yo planet!"

/opt/vc/bin/tvservice -o #powers off hdmi

ck1=$(ps aux | grep /home/pi/nightsteps/pyd/readgps.py | grep -v grep | wc -l)
echo $ck1
if [ $ck1 -eq 0 ]
then
    echo 'init readgps.py'
    python /home/pi/nightsteps/pyd/readgps.py /home/pi/nsdata/gpsout.txt /home/pi/nsdata/gpslog/ &
fi

ck3=$(ps aux | grep  /home/pi/nightsteps/pyd/gpio-a-all.py | grep -v grep | wc -l)
echo $ck3
if [ $ck3 -eq 0 ]
then
    echo 'init gpio-a'
    python /home/pi/nightsteps/pyd/gpio-a-all.py &
fi

ck4=$(ps aux | grep /home/pi/nightsteps/pyd/read_lsmcompass.py | grep -v grep | wc -l)
echo $ck4
if [ $ck4 -eq 0 ]
then
    echo 'init lsm compass'
    python /home/pi/nightsteps/pyd/read_lsmcompass.py &
fi

ck2=$(ps aux | grep /home/pi/nightsteps/nightsteps_run.pl | grep -v grep | wc -l)
echo $ck2
if [ $ck2 -eq 0 ]
then
    echo 'init nightsteps'
    log=$(date +nslog-%y%m%d-%H%M.txt)
    perl /home/pi/nightsteps/nightsteps_run.pl>/home/pi/nsdata/syslog/$log &
    cp /home/pi/nsdata/gpio/dig_startlights.o /home/pi/nsdata/gpio/dig1.o &
    cp /home/pi/nsdata/gpio/dig_startlights.o /home/pi/nsdata/gpio/dig2.o &
fi

ck5=$(ps aux | grep /home/pi/nightsteps/pyd/dsig.py | grep -v grep | wc -l)
echo $ck5
if [ $ck5 -eq 0 ]
then
    echo 'init dsig out'
    python /home/pi/nightsteps/pyd/dsig.py &
fi

ck6=$(ps aux | grep /home/pi/nightsteps/pyd/dig.py | grep -v grep | wc -l)
echo $ck6
if [ $ck6 -eq 0 ]
then
    echo 'init dig out'
    python /home/pi/nightsteps/pyd/dig.py &
fi


echo "all done"
	
