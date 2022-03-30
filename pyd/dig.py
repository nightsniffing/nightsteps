#    DIG --> queued output control daemon for pi pins 
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

from gpiozero import DigitalOutputDevice
import os
import time
import re
from collections import deque

#########################################################################
# instruction | behaviour                                               #
#-------------|---------------------------------------------------------#
#  l          | Set output to low for number of miliseconds (e.g l500)  #
#  h          | Set output to high for number of miliseconds (e.g. h200)#
#  q          | Append following instructions to end of queue           #
#  t          | Reset the queue, and go straight to the new instructions#
#  i          | Add following instructions to beginning of queue        #
#-----------------------------------------------------------------------#
#########################################################################

digOut = [DigitalOutputDevice(27), DigitalOutputDevice(22)]
state = [0,0]
#stripped out magnetic checks, as this has only been used for leds for a while
#magnetic = [False,False]
#look in the following files for instructions
filepath = ["/home/pi/nsdata/gpio/dig1.o", "/home/pi/nsdata/gpio/dig2.o"]
#statepath = []
#statepath = ["/home/pi/nsdata/gpio/mag1.s", "/home/pi/nsdata/gpio/mag2.s"]
#make two double ended queues for instructions, one for eeach of the digital outs
queuedInstruction = [deque(['s']), deque(['s'])]
activeInstruction = [deque(['s']), deque(['s'])]
#for sp in statepath:
#    with open(sp, "w") as s:
#        s.write("0")
#        s.close()
for instr in activeInstruction:
    instr.clear()
for instr in queuedInstruction:
    instr.clear()

def getInstrFromFile(fileName):

    with open(fileName) as f:
        lines = deque (f.read().splitlines())
#        print "instructions received\n"
        return lines

def processInstr(newInstr, instr):
  
    mode = 'q'
    while (len(newInstr) > 0):
        ni = newInstr.popleft()
        ni.rstrip()
        if (ni == 'q' or ni == 'i'):
            mode = ni
        elif (ni == 't'):
            instr.clear()
            mode = 'q'
        elif (mode == 'q'):
            instr.append(ni)
        elif (mode == 'i'):
            instr.appendleft(ni)            
    return instr

##main loop
oldtimemillis = int(round(time.time() * 1000))
while True:
    # Cycle through the two instruction sets.
    nowtimemillis = int(round(time.time() * 1000))
    gap = nowtimemillis - oldtimemillis
    for i in range(0,len(activeInstruction)):
        if (len(activeInstruction[i]) > 0):
            l = len(activeInstruction[i])
            mi = activeInstruction[i].popleft()
            matchObjHigh = re.match(r'h(\d+)', mi, re.M|re.I)
            matchObjLow = re.match(r'l(\d+)', mi, re.M|re.I)
            if (matchObjHigh):
                #print "matched high"
                if (state[i] == 0):
                    state[i] = 1
#                    if magnetic[i]:
#                        with open(statepath[i], "w") as s:
#                            s.write("1")
#                            s.close()
                    digOut[i].on()
                millis = int(matchObjHigh.group(1)) - gap
                if (millis > 0):
                    ni = 'h' + str(millis)
                    activeInstruction[i].appendleft(ni)
            if (matchObjLow):
                #print "matched low"
                if (state[i] == 1):
                    state[i] = 0
                    digOut[i].off()
#                    if magnetic[i]:
#                        with open(statepath[i], "w") as s:
#                            s.write("0")
#                            s.close()
                    #print str(i) + "off\n"
                millis = int(matchObjLow.group(1)) - gap
                if (millis > 0):
                    ni = 'l' + str(millis)
                    activeInstruction[i].appendleft(ni)
        elif (os.path.exists(filepath[i])):
                newInstr = getInstrFromFile(filepath[i])
                os.remove(filepath[i])
                activeInstruction[i] = processInstr(newInstr, activeInstruction[i])
    oldtimemillis = nowtimemillis
    time.sleep(0.005)
    
