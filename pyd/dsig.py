#    DSIG --> signal output control daemon 
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


from gpiozero import PWMOutputDevice
from gpiozero import DigitalOutputDevice
import os
import time
import datetime
import re
import random
from collections import deque
import pprint

#digOut = [DigitalOutputDevice(5), DigitalOutputDevice(6)]
out = [PWMOutputDevice(12), PWMOutputDevice(13), DigitalOutputDevice(23)]
outType = ["pwm","pwm","dig" ]
state = [0.0,0.0,0.0]
basebeat = 48.0
speedDivider = 200.0 
beatlength = basebeat/speedDivider
magnetic = [True,True,False]
#look in the following files for instructions
filepath = ["/home/pi/nsdata/gpio/dsig_r.o", "/home/pi/nsdata/gpio/dsig_l.o", "/home/pi/nsdata/gpio/dsig_i.o"]
statepath = ["/home/pi/nsdata/gpio/mag1.s", "/home/pi/nsdata/gpio/mag2.s", "/home/pi/nsdata/gpio/mag_null.s"]
#the active instruction contains both instructions, and data on the processing of the instruction
#  inspecting: the list element it is currently being looked at, starts at 0
#  timepassed: how much time has passed while looking at this instruction, starts at 0.0
#  instr:      the original received instruction text from the filepath
#  instrset:   the instruction text broken down into a list of pin states, with force and duration.
activeInstruction = [ {'inspecting':0, 'timepassed':0.0, 'instr': "", 'instrset': [{'force':0.0, 'dur':basebeat}]},
                      {'inspecting':0, 'timepassed':0.0, 'instr': "", 'instrset': [{'force':0.0, 'dur':basebeat}]},
                      {'inspecting':0, 'timepassed':0.0, 'instr': "", 'instrset': [{'force':0.0, 'dur':basebeat}]} ]
#this is the fallback instruction element if an instruction is not present, or cannot be read 
defaultInstr = {'force':0.0, 'dur':basebeat}
#the instrLibrary is a set of already processed instructions. This lets the datasniffer run more efficiently once
#you have locked on to a signal/
instrLibrary = {};
pp = pprint.PrettyPrinter(indent=4)

for sp in statepath:
    with open(sp, "w") as s:
        s.write("0")
        s.close()
#for instr in activeInstruction:
#    instr.clear()

def combineInstrSets(instrCols, maxdur):
    start = time.time()
    comboInstr = {'ttldur':maxdur, 'set':[]}
    ele = {'force':0.0, 'dur':0.0}
#    print "max dur is " + str(maxdur)
    for d in range(0,int(maxdur)):
#      print "examining dur unit " + str(d)
      force = 0.0
      for ip in instrCols:
        p = ip['place']
        if p < ip['length']:
          ins = ip['set'][p]
#          print "adding " + str(ins['force']) + " to force"
          force += ins['force']
          if ins['dur'] + ip['durlapsed'] <= d+1:
            ip['durlapsed'] += ins['dur']
            ip['place'] += 1
      #if our total force for all colums equals present force, let's add one...
      if force == ele['force']:
        ele['dur'] += 1.0
#        print "continuing.. add 1 to dur"
      else:
#        print "starting new instruction stage"
        comboInstr['set'].append(ele)
        ele = {'force':force, 'dur':1.0}
    comboInstr['set'].append(ele)
#    printFinalComboInstr(comboInstr)
    end = time.time()
    print "CombineInstrSets1: " + str(end-start)
    return comboInstr

def combineInstrSets2(instrCols, maxdur):
# this is the new version, with improvement performance in most scenarios
#    start = time.time()
    comboInstr = {'ttldur':maxdur, 'set':[]}
    ele = {'force':0.0, 'dur':0.0}
#    print "max dur is " + str(maxdur)
    d = 0
    while d < maxdur:
#    for d in range(0,int(maxdur)):
#      print "examining dur unit " + str(d)
      force = 0.0
      presDur = []
      for ip in instrCols:
        p = ip['place']
        if p < ip['length']:
          presDur.append(ip['set'][p]['dur'])
      if len(presDur)>0:
        dp = min(presDur)
        d += dp
      else:
  #      print "no min found"
        dp = 0
        d = maxdur
  #    print "dp is " + str(dp)
      for ip in instrCols:
        p = ip['place']
        if p < ip['length']:
          ins = ip['set'][p]
#          print "adding " + str(ins['force']) + " to force"
          force += ins['force']
          if ins['dur']  <= dp:
            ip['place'] += 1
   #         print "Moving place"
          else:
            ins['dur'] -= dp
      #if our total force for all colums equals present force, let's add one...
    #  print "force is " + str(force) 
      ele['force'] = force
      ele['dur'] += dp
     # print "starting new instruction stage"
      comboInstr['set'].append(ele)
      ele = {'force':force, 'dur':0.0}
      #print str(d) + " out of " + str(maxdur)
#    pp.pprint(comboInstr)
#    printFinalComboInstr(comboInstr)
#    end = time.time()
#    print "CombineInstrSets2: " + str(end-start)
    return comboInstr


def printFinalComboInstr(comboInstr):
    print "Outputting combined instr"
    for e in comboInstr['set']:
      print str(e['dur']) + "," + str(e['force'])

def adjDurAndForce(instr):
    check = instr['ttldur'] > basebeat
    if check:
      adj = basebeat/instr['ttldur']
    else:
      adj = 1
    for ind in instr['set']:
      if ind['force'] > 1.0:
        ind['force'] = 1.0
      ind['dur'] = (ind['dur'] * adj)/speedDivider;
    return instr

def processLineset(ls):
    lineset = ls.split(",")
    iset = []
    ttldur = 0.0
    for l in lineset:
      match = re.match(r'd([0-9]+(\.[0-9]+)?)@f(-?\d+)', l, re.M|re.I)
      if match:
        dur = float(match.group(1))
        force = float(match.group(3))/100.0
        ele = {'force': force, 'dur': dur}
        ttldur += ele['dur']
        iset.append(ele)
    rtn = {'ttldur': ttldur, 'set': iset, 'length': len(iset), 'place':0, 'durlapsed':0}
    return rtn

def getInstrFromFile(fileName, i, prevInstr):
    #This pulls out a line from the score file as designated by i
    #If there are multiple instruction columns, it will resolve them
    #It will also log resolved instructions in the instruction library, to save on future processing
    with open(fileName) as f:
        lines = f.read().splitlines()
        newInstr ={'inspecting':0, 'timepassed':0.0, 'instr': "", 'instrset': []}
        if len(lines) > i:
#        print "lines read\n"
          if prevInstr['instr'] != lines[i]:
            try:
              newInstr['instrset'] = instrLibrary[lines[i]]['set']
            except:
#              print "no instr in library:" + lines[i] + "\n" 
              newInstr['instr'] = lines[i]
              instrSets = []
              linesets = lines[i].split("|")
              maxdur = 0.0
              for ls in linesets:
                iset = processLineset(ls)
                if iset['ttldur'] > maxdur:
                  maxdur = iset['ttldur']
                instrSets.append(iset)
              setLen = len(instrSets)
              if setLen > 1: 
#                print lines[i]
                combinedInstr = combineInstrSets2(instrSets, maxdur)
              elif setLen == 1:
                combinedInstr = instrSets[0]
              if setLen > 0:
                resolvedInstr = adjDurAndForce(combinedInstr)
                instrLibrary[lines[i]] = resolvedInstr
                newInstr['instrset'] = list(resolvedInstr['set'])    
            else:
              newInstr['instr'] = lines[i]
#              print "found instr in library:" + lines[i] + "\n" 
          else:
 #           print "i = " + str(i) + "; lines[i] = " + lines[i]
            #instrLibrary[lines[i]]['uses'] += 1
#            print "Repeating prev instr:" + lines[i] + "\n" 
            newInstr['instr'] = str(prevInstr['instr'])
            newInstr['instrset'] = list(prevInstr['instrset'])
        if len(newInstr) == 0:
          newInstr['instrset'].append(defaultInstr)  
        return newInstr

#An instrSet is a column of instructions for this line of the score

#def getSpeedDivFromFile(fileName):
#    with open(fileName) as f:
#        line = f.read()
#        try:
#            rtn = float(line)
#        except:
#            return baseSpeedDiv
#        else:
#            if (rtn > baseSpeedDiv): 
#                return rtn
#            else:
#                return baseSpeedDiv

def pauseCompass(onoff, fp):
    with open(statepath[fp], "w") as s:
        s.write(onoff)
        s.close()
    if onoff == "1":
        return True
    else:
        return False 

def setSignalToNewValue(sig, fp):
    if sig > 0.0:
        if magnetic[fp]:
            pauseCompass("1", fp)
        elif magnetic[fp]:
            pauseCompass("0", fp)
    else:
        pauseCompass("0", fp)
    if outType[fp] == "pwm":
        out[fp].value = sig
    elif outType[fp] == "dig":
        if sig > 0:
            out[fp].on() 
        else: out[fp].off()

def logOutput(actIn, i, fn):
    with open('/home/pi/nsdata/gpio/dsig-log/' + fn + '.o', 'a') as logfile:
      po = "scorePlace,dur,force\n"
      for e in actIn['instrset']:
        po += str(i) + "," + str(e['dur']) + "," + str(e['force']) + "\n" 
      logfile.write(po)

i = 0
instrSize = [24,24,24]
while True:
    #speedDivider = getSpeedDivFromFile(speedDivPath) # Get the present 'SpeedDiv' file - higher numbers = faster.
    #beatlength = basebeat/speedDivider               # The beatlength here is the base 'beat' value divider by the speed div - this is how 
                                                     # | many seconds the beat will last --- but now speedDiv is constant, no need to recalc this
    for fp in range(0, len(filepath)):                # It's time to check to see if there are any new rhythm instructions in each designated filepath
        activeInstruction[fp] = getInstrFromFile(filepath[fp], i, activeInstruction[fp])
    t = beatlength                                       # The value t is set to the whole duration of a standard beat - t will diminish as the beat resolves
    lasttime = time.time()
    while (t > 0.0):
        for fp in range(0, len(filepath)):
            p = activeInstruction[fp]['inspecting']
            if i < instrSize[fp] and p < len(activeInstruction[fp]['instrset']) :
              instr = activeInstruction[fp]['instrset'][p]
             # print activeInstruction[f]['instrset']
             # print instr
              if state[fp] != instr['force']:
                  state[fp] = instr['force']
                  setSignalToNewValue(instr['force'], fp)
              if (beatlength - instr['dur'] - activeInstruction[fp]['timepassed']) > t:
                  activeInstruction[fp]['inspecting'] += 1
        nowtime = time.time() 
        gap = nowtime - lasttime
        t -= gap
        lasttime = nowtime
        #print "now: " +str(nowtime) + " before: " + str(lasttime) + " t: " + str(t)
        time.sleep(0.005)
#    logOutput(activeInstruction[0], i, "r")
#    logOutput(activeInstruction[1], i, "l")
    i += 1
#    print "now processing score position " + str(i)
    for fp in range (0, len(filepath)):
        if i >= instrSize[fp]:
            i = 0
            now = datetime.datetime.now()
            #print("Current date and time: ")
            #print(str(now))
