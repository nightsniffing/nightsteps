#    GPIO-A-ALL --> analogue input control daemon
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

import time
import os
# Import SPI library (for hardware SPI) and MCP3008 library.
import Adafruit_GPIO.SPI as SPI
import Adafruit_MCP3008

# Hardware SPI configuration:
SPI_PORT   = 0
SPI_DEVICE = 0
mcp = Adafruit_MCP3008.MCP3008(spi=SPI.SpiDev(SPI_PORT, SPI_DEVICE))

a = [0,0,0,0,0,0,0,0]
path = "/home/pi/nsdata/gpio/"
while True:

    line = ""
    # Set up output files
    for c in range(0,1000):
        line = ""
        f = open(path + "a.a", "a")
        for i in range(0,8):
            a[i] = mcp.read_adc(i)
            value = '{num:04d}'.format(num=a[i])
            line += str(value) + "-"
        print >> f, line
        f.close()
        time.sleep(0.1)
    time.sleep(0.05)
    f = open(path + "a.a", "w")
    print >> f, line
    f.close()
