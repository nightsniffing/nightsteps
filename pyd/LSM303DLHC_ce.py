
# Distributed with a free-will license.
# Use it any way you want, profit or free, provided it fits in the licenses of its associated works.
# LSM303DLHC
# This code is designed to work with the LSM303DLHC_I2CS I2C Mini Module available from ControlEverything.com.
# https://www.controleverything.com/products

import smbus
import time
from math import atan2, degrees, cos, asin, sin, radians, pi, sqrt
import json
import hashlib

class lsm303:

  def __init__(self):
    # Get I2C bus
    self.bus = smbus.SMBus(1)
    self.calibrations = {'maxX':0, 'minX':0, 'maxY':0, 'minY':0, 'maxZ':0, 'minZ':0}
    # The offset is what is acutally applied to make it more accurate
    self.offset = {'x':0, 'y':0, 'z':0}
    self.calibrationFile = "/home/pi/nsdata/lsm303.cal"

  def calibrate(self):
    calibrations = self.calibrations
    #logging.info('Starting Debug, please roate the magnetomiter about all axis')
    start = True
    while True:
      try:
        change = False
        try:
          reading = self.getMagReading()
        except:
          print "mag error"
          time.sleep(0.1)
        else:
          if start:
            # get an initial reading, setting everything to zero means that the mimum
            # only gets updated if it goes negative
            calibrations['maxX'] = reading['x']
            calibrations['minX'] = reading['x']
            calibrations['maxY'] = reading['y']
            calibrations['minY'] = reading['y']
            calibrations['maxZ'] = reading['z']
            calibrations['minZ'] = reading['z']
            start = False
          # X calibration
          if reading['x'] > calibrations['maxX']:
            calibrations['maxX'] = reading['x']
            change = True
          if reading['x']< calibrations['minX']:
            calibrations['minX'] = reading['x']
            change = True
          # Y calibrations
          if reading['y'] > calibrations['maxY']:
            calibrations['maxY'] = reading['y']
            change = True
          if reading['y']< calibrations['minY']:
            calibrations['minY'] = reading['y']
            change = True
          # Z calibrations
          if reading['z'] > calibrations['maxZ']:
            calibrations['maxZ'] = reading['z']
            change = True
          if reading['z']< calibrations['minZ']:
            calibrations['minZ'] = reading['z']
            change = True
          if change:
            print('Calibration Update:')
            print(json.dumps(calibrations, indent=2))
            self.saveCalibration()
          time.sleep(0.1)
      except KeyboardInterrupt:
        print('saving calibration')
        self.saveCalibration()
        return True

  def saveCalibration(self):
    '''Once calibrated we need to find a way to save it to the local file system
    '''
    try:
      with open(self.calibrationFile, 'w') as calibrationFile:
        calibration = json.dumps(self.calibrations, sort_keys=True)
        calibration.encode('utf-8')
        checksum = hashlib.sha1(calibration).hexdigest()
        calibrationFile.write(calibration)
        calibrationFile.write('\n')
        calibrationFile.write(checksum)
        calibrationFile.write('\n')
    except:
      print('unable to save calibration: {0}')

  def loadCalibration(self):
    '''loads the json file that has the magic offsets in them
    Hopefully this will mean that it points within 15 degrees,
    '''
    try:
      with open(self.calibrationFile) as calibrationFile:
        calibration = calibrationFile.readline()
        checksum    = calibrationFile.readline()
    except:
        print('Unable to open com[ass calibration: {0}')

    calibration = calibration.rstrip()
    checksum    = checksum.rstrip()
    if hashlib.sha1(calibration).hexdigest() == checksum:
      # we are good
      #logging.debug('good calibrations')
      calibration = json.loads(calibration)
      print (calibration)
      self.calibrations = calibration
    else:
      print('compass calibration file checksum mismatch')
      return False
    # http://www.bajdi.com/mag3110-magnetometer-and-arduino/
    self.offset['x'] = (calibration['minX'] + calibration['maxX'])/2
    self.offset['y'] = (calibration['minY'] + calibration['maxY'])/2
    self.offset['z'] = (calibration['minZ'] + calibration['maxZ'])/2
    print(json.dumps(self.offset))


  def getAccelReading(self):
    # LSM303DLHC Accl address, 0x19(25)
    # Select control register1, 0x20(32)
    #		0x27(39)	Acceleration data rate = 10Hz, Power ON, X, Y, Z axis enabled
    self.bus.write_byte_data(0x19, 0x20, 0x27)
    # LSM303DLHC Accl address, 0x19(25)
    # Select control register4, 0x23(35)
    #		0x00(00)	Continuos update, Full scale selection = +/-2g,
    self.bus.write_byte_data(0x19, 0x23, 0x00)
    time.sleep(0.02)

    # LSM303DLHC Accl address, 0x19(25)
    # Read data back from 0x28(40), 2 bytes
    # X-Axis Accl LSB, X-Axis Accl MSB
    data0 = self.bus.read_byte_data(0x19, 0x28)
    data1 = self.bus.read_byte_data(0x19, 0x29)

    # Convert the data
    xAccl = data1 * 256 + data0
    if xAccl > 32767 :
      xAccl -= 65536

    # LSM303DLHC Accl address, 0x19(25)
    # Read data back from 0x2A(42), 2 bytes
    # Y-Axis Accl LSB, Y-Axis Accl MSB
    data0 = self.bus.read_byte_data(0x19, 0x2A)
    data1 = self.bus.read_byte_data(0x19, 0x2B)

    # Convert the data
    yAccl = data1 * 256 + data0
    if yAccl > 32767 :
      yAccl -= 65536

    # LSM303DLHC Accl address, 0x19(25)
    # Read data back from 0x2C(44), 2 bytes
    # Z-Axis Accl LSB, Z-Axis Accl MSB
    data0 = self.bus.read_byte_data(0x19, 0x2C)
    data1 = self.bus.read_byte_data(0x19, 0x2D)

    # Convert the data
    zAccl = data1 * 256 + data0
    if zAccl > 32767 :
      zAccl -= 65536
    accel = {"x":xAccl, "y":yAccl, "z":zAccl}
    return accel

  def getOffsetMagReading(self):
    mag = self.getMagReading()
    magoff = {}
    for k in list(mag.keys()):
      magoff[k] = mag[k] - self.offset[k]
    return magoff

  def getMagReading(self):
    # LSM303DLHC Mag address, 0x1E(30)
    # Select MR register, 0x02(02)
    #		0x00(00)	Continous conversion mode
    self.bus.write_byte_data(0x1E, 0x02, 0x00)
    # LSM303DLHC Mag address, 0x1E(30)
    # Select CRA register, 0x00(00)
    #		0x10(16)	Temperatuer disabled, Data output rate = 15Hz
    self.bus.write_byte_data(0x1E, 0x00, 0x10)
    # LSM303DLHC Mag address, 0x1E(30)
    # Select CRB register, 0x01(01)
    #		0x20(32)	Gain setting = +/- 1.3g
    self.bus.write_byte_data(0x1E, 0x01, 0x20)

    time.sleep(0.02)

    # LSM303DLHC Mag address, 0x1E(30)
    # Read data back from 0x03(03), 2 bytes
    # X-Axis Mag MSB, X-Axis Mag LSB
    data0 = self.bus.read_byte_data(0x1E, 0x03)
    data1 = self.bus.read_byte_data(0x1E, 0x04)

    # Convert the data
    xMag = data0 * 256 + data1
    if xMag > 32767 :
      xMag -= 65536

    # LSM303DLHC Mag address, 0x1E(30)
    # Read data back from 0x05(05), 2 bytes
    # Y-Axis Mag MSB, Y-Axis Mag LSB
    data0 = self.bus.read_byte_data(0x1E, 0x07)
    data1 = self.bus.read_byte_data(0x1E, 0x08)

    # Convert the data
    yMag = data0 * 256 + data1
    if yMag > 32767 :
      yMag -= 65536

    # LSM303DLHC Mag address, 0x1E(30)
    # Read data back from 0x07(07), 2 bytes
    # Z-Axis Mag MSB, Z-Axis Mag LSB
    data0 = self.bus.read_byte_data(0x1E, 0x05)
    data1 = self.bus.read_byte_data(0x1E, 0x06)

    # Convert the data
    zMag = data0 * 256 + data1
    if zMag > 32767 :
      zMag -= 65536
    mag ={"x":xMag, "y":yMag, "z":zMag}
    return mag


  def vector_2_degrees(self, x, y):
    #  print("x" + str(x) + ", y" + str(y))
      angle = degrees(atan2(y, x))
      #angle = 180 * atan2(y, x)/pi
      #print (angle)
      if angle < 0:
          angle += 360
      return angle

  def gaussMethod(self, x, y):
      xGaussData = x * 0.48828125 * 2
      yGaussData = y * 0.48828125 * 2
      angle = atan2(yGaussData, xGaussData)*(180/pi)
      if angle < 0:
          angle += 360
      return angle

  def get_uncompensated_heading(self):
      try:
        mag1 = self.getOffsetMagReading()
        mag2 = self.getOffsetMagReading()
        mag = { 'x':(mag1['x'] + mag2['x'])/2, 'y':(mag1['y']+mag2['y'])/2,'z':(mag1['z']+mag2['z'])/2}
      except:
        rtn = "ERROR"
      else:
        rtn = self.vector_2_degrees(mag['x'], mag['y'])
        #rtn = self.gaussMethod(mag['x'], mag['y'])
      return rtn

  def get_compensated_heading(self):
      accelnorm = {}
      #print(json.dumps(accel))
      try:
        mag1 = self.getOffsetMagReading()
        accel1 = self.getAccelReading()
        mag2 = self.getOffsetMagReading()
        accel2 = self.getAccelReading()
      except:
        rtn = "ERROR"
      else:
        mag = { 'x':(mag1['x'] + mag2['x'])/2, 'y':(mag1['y']+mag2['y'])/2,'z':(mag1['z']+mag2['z'])/2}
        accel = { 'x':(accel1['x'] + accel2['x'])/2, 'y':(accel1['y']+accel2['y'])/2,'z':(accel1['z']+accel2['z'])/2}
        acceldiv = sqrt((accel['x']*accel['x'])+(accel['y']*accel['y'])+(accel['z']*accel['z']))
        accelnorm['x'] = accel['x']/ acceldiv
        accelnorm['y'] = accel['y']/ acceldiv
        pitch = asin(-accelnorm['x']);
        roll = asin(accelnorm['y']/cos(pitch))
        xh = (mag['x'] * cos(pitch)) + (mag['z'] * sin(pitch))
        yh = (mag['x'] * sin(roll) * sin(pitch)) + (mag['y'] * cos(roll)) -( mag['z'] * sin(roll) * cos(pitch))
        #zh = (-mag['x'] * cos(roll) * sin(pitch)) + (mag['y'] * sin(roll)) + (mag['z'] * cos(roll) * cos(pitch))
        rtn = self.vector_2_degrees(xh, yh)
        #rtn = self.gaussMethod(xh, yh)
      return rtn

