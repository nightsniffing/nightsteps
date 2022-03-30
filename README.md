# Nightsteps - the heart/mind/something of the London Development Datasniffer

Nightsteps is the operating software for the London Development Datasniffer. It's what makes the lights blink and 
the solenoids click.

The London Development Datasniffer is a device for investigating and interrogating the London Development Database and other
planning datasets... whilst on a bat walk. Why would you do this, you ask? Bat walks are engaging events (which, let's face 
it, conversations about planning data... aren't) which can attract people who might not engage with the planning system.
Meanwhile, bats are profoundly affected by changes to the built environment - they roost in our buildings, gardens and parks,
forage in green areas, and can be repelled by overbearing street lighting. So it all affects bats too, and bringing such
a device on a bat walk can start conversations on how bats are impacted by the built environment.

This software is published in the event that you might 1) like to make your own datasniffer or 2) might like to see an 
example of a piece of mobile sonic media using the Raspberry Pi. Details of licensing for this software is in LICENSE.TXT
(or will be soon). The intention is to have everything within this that can be Free Software as Free Software.

## What is all this?

This is the complete software repository for Nightsteps. You can use this to set up Nightsteps on your own Pi. Alternatively,
you can wait until I release something a little more complete and compressed.

The script start.sh boots all the necessary components for Nightsteps to work. This includes the following...

The main Nightsteps program

* *nightsteps_run.pl*: The core perl program that runs Nightsteps. This picks up data on GPS, orientation and user controls
in order to query the London Development Database and/or whatever other planning datasets have been incorporated. It then creates
two score files that consistute the output of the device.
* *ns_loop.pm*: This module covers the main logic and run order of the program.
* *ns_dbinterface.pm*: This is the main interface to the database
* *ns_audinterface.pm*: Presently, this module handles the signal logic for the solenoids or whatever electromechanical output
  you want to hook up.
* *ns_gpio.pm*: This interfaces with the Pi's input and output pins, handling things like control input and compass readings
* *ns_telemetry.pm*: This handles some matters relating to spatial calculation, but in truth this is mostly done by postgis now
* *ns_logger.pm*: logging functionality for the main program.

A clutch of python daemons:

* *pyd/readgps.py*: this constantly polls for GPS data and deposits it in /home/pi/nsdata/
* *pyd/read_lsmcompass.py*: like above, this polls for accelerometer and compass data, converting it to tilt-compensated orientation and 
depositing it in /home/pi/nsdata/gpio/0.c
* *pyd/gpio-a-all.py*: queries the Analog-to-Digital Convertor in order to get readings from the Datasniffer controls
* *pyd/dig.py*: a script for picking up and queuing simple one off signals. Used for two of the Datasniffer indicator lights
* *pyd/dsig.py*: this script controls the main output of the datasniffer. It picks up the score left by the main Nightsteps program and 
plays it. If the score changes, so does the output - however, the score doesn't start from the beginning, but continues from wherever
it had got to before it changes.

And a couple of settings files:

* *nsdata/ns_config.pm*: this includes configurations for the controls, and selecting which query definition the datasniffer will use.
* *nsdata/querydefs/???.json*: query definitions, which include which database will be used, what the password will be, and what each query on each setting
should look for. Two examples are given, one reads straight from the This is configurable but not a masterclass in neat and legible writing. Sorry! I'm not
sure why I did these as jsons, it just felt easier at the time?


## Dependencies

This is a list of modules and libraries you will need to install to get Nightsteps to run on a Raspberry Pi.

There may be other ways of installing these tools - this is the approach I have dound works

### Debian modules

Generally you install these with the command 'sudo apt install ' followed by the module name.

* libdbi-perl (DBI perl)
* libdbd-pg-perl - postgre drivers for perl
* libnet-gpsd3-perl
* python-pyproj
* python-gps
* gpsd
* postgresql 
* libpq-dev 
* postgresql-client
* postgresql-server-dev-XX - postgre dev server (XX is version number)
* postgis
* postgresql-XX-postgis-XX  - (XX is version number)
* postgresql-XX-postgis-XX-scripts  - (XX is version number)
* python-psycopg2
* i2c-tools
* python-smbus

### Perl libraries

You install these using CPAN. Run 'perl -MCPAN -e shell'. Each library is installed by writing 'install ' followed by the library name.

* DBI
* DBI::Pg
* JSON
* Math::Polygon
* Math::Polygon::Calc
* GIS::Distance
* Math::Clipper
* Math::Trig
* Math::Round
* Switch
* Time::Piece
* Time::HiRes
* \(Net::GPSD3\*\)
* Data::Dumper

### Python libraries

You install these with pip. Run 'pip install ' followed by the library name

* gpiozero
* mag3110
* smbus
* psycopg2
* json
* Adafruit\_GPIO.SPI
* Adafruit\_MCP3008

For some reason I have starred these... I think because I ended up install them with apt?

* pyproj\*
* gps\*

## Setting up Nightsteps

1) Install all the dependencies above

2) Get Nightsteps on you pi

* Create a directory called 'nightsteps' in '/home/pi/' and download the contents of this repository to there.
* Copy the directry 'nsdata' from nightsteps to '/home/pi/' (include the directory itself so you will have a directory
called '/home/pi/nsdata'

3) Configure your Pi for Nightsteps
* Enable SPI and I2C interfaces using raspi-config



## Setting up Postgre SQL

as postgres user in postgres database
```
CREATE ROLE ldd login nosuperuser inherit nocreatedb nocreaterole noreplicationi
CREATE DATABASE ldd OWNER ldd
CREATE SCHEMA app\_ldd AUTHORIZATION ldd;
```

as postgres user in ldd database
```
CREATE EXTENSION postgis;
CREATE EXTENSION postgis\_topology;
```

Get the LDD sql extract: https://data.london.gov.uk/dataset/london-development-database-sql-extract

As postgres user from command line, in directory with LDD sql extract
pg\_restore --clean -d ldd ldddata\_DDDDDDDD.sql.tar (where Ds are the date info at the end of the filename)

This process will take a while and give little indication as to where it is up to. Be patient and let it do its thing!

change the following line in pg\_hba.conf:
local   all    all     peer
to:
local   all    all     md5

then as postgres user in ldd database:
````
grant all privileges on database ldd to pi;
grant usage on schema app\_ldd to pi;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app\_ldd TO pi;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO pi;
GRANT ALL PRIVILEGES ON DATABASE ldd TO pi;
GRANT ALL PRIVILEGES ON SCHEMA app\_ldd TO pi;
````

Then decide on/generate a password for the pi's database and enter it in:

```
ALTER USER pi WITH PASSWORD 'yourchosenpassword'
```

Copy the directory nsdata to /home/pi/

Run the following from the database /home/pi/nsdata/dataprocessing/

```
python convertGeoLatLon.py all
```

This takes a long time as well - make sure the datasniffer is fully charged and plugged in before you start. 
The program will give you some indication of where it is up to.

And then run the following:

```
python ns\_tableprep\_0\_1.py qt/01\_setupNSBaseTable.sql qd:=q/
```

Edit the file /home/pi/nsdata/querydefs/ns1.json and enter the pi's database password into it
