import getpass
import io
import os
import sys
import pyproj
import psycopg2
import psycopg2.extras
import string
import re
import json
import datetime

#Arguments
# q:=xxxx.sql - run query
# qd:=xxxx/ - run all queries in directory
# u:=xxxx.json - update records based on borough_ref
# s:=xxxx.json - update records based on permission_id
# am:=xxxx.json - insert new major records
# at:=xxxx.json - insert new tree records
# ab:=xxxx.json - insert new bat mitigation records

def connectToDb():
  n = 'ldd'
  u = raw_input("Username:")
  pw = getpass.getpass("Password:")
  db = {}
  db['connect'] = psycopg2.connect("dbname='ldd' user='" + u + "' host='localhost' password='" + pw + "'")
  #dbConnect = psycopg2.connect("dbname='ldd' user='ldd' host='localhost' password=''")
  db['cursor'] = db['connect'].cursor(cursor_factory=psycopg2.extras.DictCursor)
  bng = pyproj.Proj(init='epsg:27700')
  wgs84 = pyproj.Proj(init='epsg:4326')
  return db

def checkAndCreateTable(tablename, tablefile, db):
  checkTableSql = "SELECT EXISTS (  SELECT 1  FROM   pg_tables  WHERE  schemaname = 'app_ldd'  AND tablename = '" + tablename + "' );"
  db['cursor'].execute(checkTableSql)
  checkTable = db['cursor'].fetchone()
  print str(checkTable[0]) + "\n"
  if not checkTable[0]:
    print "no table... createing"
    with open(tablefile, 'r') as f:
      sql=f.read().replace('\n', ' ')
    print sql
    db['cursor'].execute(sql)
    db['connect'].commit()
  else:
    print "table present"

def runQueryDirectory(queryDir, db):
  queries = os.listdir(queryDir)
  queries.sort()
  for q in queries:
    if re.search(".sql$", q):
      print "Running: " + q
      chk = runQuery(queryDir + q, db)
      #chk = True
      if chk:
        print "Executed successfully"
      else:
        print "Error with query"
    else:
      print q + " does not end with .sql -- skipping"

def runQuery(fn, db):
  with open(fn, 'r') as f:
    sql=f.read().replace('\n', ' ')
  print sql
  db['cursor'].execute(sql)
  db['connect'].commit()
  return True

def updateUsingJson(fn, db, updatefield):
  i = 0
  with open(fn) as f:
    dataIn = json.loads(f.read())
  for pa in dataIn:
    cs = "commentStats"
    #print "updating " + str(pa[updatefield])
    sql = ""
    if (cs in pa) or ("constraints" in pa) or (checkFloorspaceOverAmount(pa, 1)) or ("housing" in pa):
      i += 1
      sql = "UPDATE app_ldd.ns_base "
      sql += "SET is_in_conservationarea = " + testConstraints(pa, "Conservation Area")
    if cs in pa:
      sql += ", comments_total=" + pa[cs]['Comments Received'] + ", comments_objecting=" + pa[cs]['Objections'] +", comments_supporting=" + pa[cs]['Supporting']
    if 'housing' in pa:
      sql += ", change_to_housing = TRUE"
    if checkFloorspaceOverAmount(pa,1):
      sql += ", change_to_floorspace = TRUE"
    if len(sql) > 1:
      if updatefield == "borough_ref" and 'ref' in pa:
        sql += " WHERE " + updatefield + "='" + pa['ref'] + "'"
      if updatefield == "borough_ref" and 'borough_ref' in pa:
        sql += " WHERE " + updatefield + "='" + pa[updatefield] + "'"
      else:
        sql += " WHERE " + updatefield + "=" + str(pa[updatefield])
      db['cursor'].execute(sql)
  db['connect'].commit()
  print "updated " + str(i) + " records"

def testConstraints(pa, ss):
  rtn = "FALSE"
  if 'constraints' in pa:
    for c in pa['constraints']:
      motype = re.match(r".*" + ss + ".*", c['type'], re.I|re.M)
      moname = re.match(r".*" + ss + ".*", c['name'], re.I|re.M)
      if motype or moname:
        rtn = "TRUE"
  return rtn

def checkCritMet(pa, nstype):
  rtn = False
  if nstype == "tree" or nstype == "bat":
    rtn = True
  elif nstype == "major":
    fscrit = checkFloorspaceOverAmount(pa, 100)
    if ('housing' in pa) or fscrit:
      rtn = True
  return rtn

def insertNewJsonRecords(args, db, intype, nstype):
  with open(args[intype]) as f:
    dataIn = json.loads(f.read())
  print str(len(dataIn)) + " records found"
  for pa in dataIn:
    checkCrit = checkCritMet(pa, nstype) 
    if checkCrit:
      br1 = pa['ref']
      br2 = pa['ref'].replace('/','-')
      sqlCheck = "SELECT COUNT(permission_id) FROM app_ldd.ns_base WHERE borough_ref='" + br1 + "' OR borough_ref='" + br2 + "'"
      db['cursor'].execute(sqlCheck)
      check = db['cursor'].fetchone()
      print br2 + ": " + str(check[0])
      if check[0] == 0:
        ins = {'s':{}, 'n':{}} #s is for string (or quoted) values, n is for numeric (or unquoted) values
        ins['s']['source'] = "onlinePlanDb"
        ins['s']['borough_ref'] = br1
        if "bn" in args:
          ins['s']['borough_name'] = args['bn']
        ins['s']['descr'] = pa['descr'].replace("'","''")
        ins['s']['ns_type'] = nstype
        ins['s']['status_rc'] = determineStatus(pa)
        ins['n']['is_in_conservationarea'] = testConstraints(pa, "Conservation Area")
        ins['n']['existing_socialhousing'] = determineSocialHousing(pa, "Proposed")
        ins['n']['proposed_socialhousing'] = determineSocialHousing(pa, "Existing")
        tf = "textFields"
        if tf in pa:
          if ("siteArea" in pa[tf]) and ("siteAreaUnit" in pa[tf]):
            ins['n']['sitearea_total'] = determineSiteArea(pa) 
        cs = "commentStats"
        if cs in pa:
          ins['n']['comments_total'] = pa[cs]['Comments Received'] 
          ins['n']['comments_objecting'] = pa[cs]['Objections']
          ins['n']['comments_supporting'] = pa[cs]['Supporting']
        if 'permission_date' in pa:
          ins['s']['permission_date'] = processPermissionDate(pa['permission_date'])
        if 'geo' in pa:
          ins['n']['lat'] = pa['geo']['lat']
          ins['n']['lon'] = pa['geo']['lon']
        sql = setupJsonInsertQuery(ins)
        db['cursor'].execute(sql)
  sqlpointfix = "UPDATE app_ldd.ns_base SET the_geom_pt = ST_SetSRID(ST_MakePoint(lon,lat), 4326) WHERE the_geom_pt IS NULL;"
  db['cursor'].execute(sqlpointfix)
  db['connect'].commit()

def processPermissionDate(pdate):
  mo1 = re.match(r"[A-Za-z]+\s\d\d\s[A-Za-z]+\s\d\d\d\d", pdate, re.I|re.M)
  mo2 = re.match(r"[0-9]+\/[0-9]+\/[0-9]+", pdate, re.I|re.M)
  rtndate = ""
  if mo1: 
    d = datetime.datetime.strptime(pdate, '%a %d %b %Y')
  elif mo2:
    d = datetime.datetime.strptime(pdate, '%d/%m/%Y')
  rtndate = d.strftime('%Y-%m-%d')
  return rtndate

def checkFloorspaceOverAmount(pa, amount):
  fscrit = False
  fscat = ['existing', 'proposed']
  for fs in fscat:
    if 'floorspace' in pa:
      if fs in pa['floorspace']:
        if 'Total' in pa['floorspace'][fs]:
          if pa['floorspace'][fs]['Total'] > amount:
            fscrit = True
  return fscrit

def determineSocialHousing(pa, ht):
  rtn = 0
  h = 'housing'
  if h in pa:
    if ht in pa[h]:
      for k in list(pa[h][ht].keys()):
        mo = re.match(r"(.*ocial.*)", k, re.I|re.M)
        if mo:
          rtn = pa[h][ht][k]
  return rtn  

def determineStatus(pa):
  status = "UNKNOWN"
  print "###STARTING status###"
  if pa['status'] == "Awaiting decision" or pa['status'] == "Under consideration/assessment" or pa['status'] == "REGISTERED":
    status = "UNDECIDED"
  elif pa['status'] == "Withdrawn":
    status = "WITHDRAWN"
  elif "decision" in pa:
    matchstr = [r".*Grant.*", r".+ - GRANTED", r".+cceptable.*", r".+granted.*", r"Approv.+", r".+Auto Permit"]
    status = multiRegexCheck(pa, "decision", matchstr, status, "GRANTED")
    matchstr2 = [r".*Refuse.*", r".+ - REFUSED", r".+refused.*", r"Refusal.*"]
    status = multiRegexCheck(pa, "decision", matchstr2, status, "REFUSED")
    matchstr3 = [r".*Withdrawn.*", r".+withdrawn.*"]
    status = multiRegexCheck(pa, "decision", matchstr3, status, "WITHDRAWN")
    matchstr4 = [r"Completed.*"]
    status = multiRegexCheck(pa, "decision", matchstr4, status, "COMPLETED")
  return status  

def multiRegexCheck(pa, field, matchstr, failedOutcome, passedOutcome):
  rtn = failedOutcome
  for ms in matchstr:
    print "comparing " + ms + " to " + pa[field]
    mo = re.match(ms, pa[field], re.I|re.M)
    if mo:
      rtn = passedOutcome
  return rtn

def determineSiteArea(pa):
  tf = "textFields"
  baseArea = float(pa[tf]['siteArea'])
  areaUnit = pa[tf]['siteAreaUnit']
  finalArea = 0.0
  if areaUnit == "hectares" or areaUnit == "Hectares":
    finalArea = baseArea
  elif areaUnit == "sq.metres" or areaUnit == "Sq. metres":
    finalArea = baseArea/10000
  return finalArea

def setupJsonInsertQuery(ins):
  fields = ""
  values = ""
  for k in list(ins['s'].keys()):
    print "adding " + k  
    print "adding " + k + " : " + ins['s'][k] + " to query " 
    fields += k + ","
    values += "'" + ins['s'][k] + "',"
  for k in list(ins['n'].keys()):
    print "adding " + k  
    print "adding " + k + " : " + str(ins['n'][k]) + " to query " 
    fields += k + ","
    values += str(ins['n'][k]) + ","
  fld = fields[:-1]
  val = values[:-1]
  sql = "INSERT INTO app_ldd.ns_base (" + fld + ") VALUES (" + val + ");"
  return sql

if __name__ == "__main__":
  db = connectToDb()
  tablefile = sys.argv[1]
  checkAndCreateTable("ns_base", tablefile, db)
  arglen = len(sys.argv)
  args = {}
  for a in sys.argv:
    mo = re.match(r"(.+):=(.*)", a, re.M|re.I)
    if mo:
      an = mo.group(1)
      av = mo.group(2)
      args[an] = av
  if "s" in args:
    updateUsingJson(args['s'], db, "permission_id") # update from json using permission_id as comparison field (when would I use this??)
  if "u" in args:
    updateUsingJson(args['u'], db, "borough_ref") # update from json using borough_ref as comparison field
  if "q" in args:
    runQuery(args['q'], db) # runs a stated query
  if "qd" in args:
    runQueryDirectory(args['qd'], db)

## Set of json inserts from scraped records
  if "am" in args:
    insertNewJsonRecords(args, db, "am", "major") # insert 'major' records
  if "at" in args:
    insertNewJsonRecords(args, db, "at", "tree")  # insert tree records
  if "ab" in args:
    insertNewJsonRecords(args, db, "ab", "bat") # insert bat related records
