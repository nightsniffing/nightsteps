#! /usr/bin/python
# Written by Dan Mandle http://dan.mandle.me September 2012
# Editied by Cliff Hammett July 2020
# License: GPL 2.0
 
from shutil import copyfile
import sys
from gps import *
from time import *
from datetime import datetime
import time
import threading
 
gpsd = None #seting the global variable
fileout = sys.argv[1]
logdir = sys.argv[2]
 
class GpsPoller(threading.Thread):
  def __init__(self):
    threading.Thread.__init__(self)
    global gpsd #bring it in scope
    gpsd = gps(mode=WATCH_ENABLE) #starting the stream of info
    self.current_value = None
    self.running = True #setting the thread running to true
 
  def run(self):
    global gpsd
    while gpsp.running:
      gpsd.next() #this will continue to loop and grab EACH set of gpsd info to clear the buffer
 
if __name__ == '__main__':
  gpsp = GpsPoller() # create the thread
  try:
    gpsp.start() # start it up
    i = 0
    time.sleep(1)
    while True:
      #It may take a second or two to get good data
      if i>300 or i == 0:
        now = datetime.now()
        logfile = now.strftime("gps%Y%m%d-%H%M%S.txt")
        copyfile(fileout, logdir + "/" + logfile)
        filemode = 'w'
        i = 1
      else:
        filemode = 'a'
      with open(fileout, filemode) as f:
        f.write("lat: ")
        f.write(str(gpsd.fix.latitude))
        f.write(" lon: ")
        f.write(str(gpsd.fix.longitude))
        f.write(" time: ")
        f.write(str(gpsd.fix.time))
        f.write("\n")
      time.sleep(1) #set to whatever
      i +=1
 
  except (KeyboardInterrupt, SystemExit): #when you press ctrl+c
    print "\nKilling Thread..."
    gpsp.running = False
    gpsp.join() # wait for the thread to finish what it's doing
  print "Done.\nExiting."
