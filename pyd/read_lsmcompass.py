""" Display compass heading data five times per second """
## original code by Adafruit
## edited by Cliff using guide: https://www.instructables.com/id/Tilt-Compensated-Compass/

import LSM303DLHC_ce
import time


path = "/home/pi/nsdata/gpio/"
c = LSM303DLHC_ce.lsm303()
c.loadCalibration()
ha = 0
filestocheck = 2
state = 1
waitct = 0
waitmax = 3
adjustfile = open(path + 'compassadjust.0', "r")
adjtxt = adjustfile.read()
adjust = int(adjtxt)


def checkMagState():
    rtn = False
    for i in range(1, filestocheck):
        try:
            s = open(path + "mag" + str(i) + ".s", "r")
            t = s.read()
            if t == "1":
                rtn = True
            s.close()
        except:
            print "no mag file " + str(i)
    return rtn

while True:

  with open(path + '0.c', 'w') as f:
    f.write(str(ha) + "\n") 
  for i in range(0,1000):
    mag = checkMagState()
    if mag == False:
        if state == 1:
            #c = compass.getCompenstatedBearing()
          hc = c.get_compensated_heading()
          hu = c.get_uncompensated_heading()
          if hc == "ERROR" or hu == "ERROR":
            ha = "ERROR"
          else:
            ha = (hc - ((hu - hc) * 0.25)) + adjust
            if ha > 360:
              ha -= 360
            if ha == 0:
              print "zero\n"
            with open(path + '0.c', 'a') as f:
              f.write(str(ha) + "\n")
            #print ha
        else:
            if waitct >= waitmax:
                state = 1
            waitct += 1
    else:
        print "mag warning!"
        state = 0
        waitct = 0
    time.sleep(0.08)
    mag = checkMagState()
    if mag:
        print "mag warning!"
        state = 0
        waitct = 0
    time.sleep(0.02)
