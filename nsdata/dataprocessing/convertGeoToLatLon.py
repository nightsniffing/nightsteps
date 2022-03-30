#    CONVERTGEOTOLATLON --> conversion script to translate LDD from 
#    easting/northing to lat/lon 
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
#

import io
import sys
import pyproj
import psycopg2
import psycopg2.extras
import string
import re
import json

#Connect to the database and make the cursor

n = 'ldd'
u = raw_input("Username:")
pw = getpass.getpass("Password:")
dbConnect = psycopg2.connect("dbname='" + n + "' user='" + u + "' host='localhost' password='" + pw + "'")
#dbConnect = psycopg2.connect("dbname='ldd' user='ldd' host='localhost' password=''")
cursor = dbConnect.cursor(cursor_factory=psycopg2.extras.DictCursor)
scope = sys.argv[1]
bng = pyproj.Proj(init='epsg:27700')
wgs84 = pyproj.Proj(init='epsg:4326')


def checkTablePoint(cursor):
  checkTableSql = "SELECT EXISTS (  SELECT 1  FROM   pg_tables  WHERE  schemaname = 'app_ldd'  AND    tablename = 'ns_permlatlon' );"
  cursor.execute(checkTableSql)
  checkTable = cursor.fetchone()
  print str(checkTable[0]) + "\n"
  if not checkTable[0]:
    print "no table point"
    mkTableSql = "CREATE TABLE app_ldd.ns_permlatlon(id SERIAL PRIMARY KEY, permission_id INTEGER, lat DOUBLE PRECISION, lon DOUBLE PRECISION);"
    print mkTableSql
    cursor.execute(mkTableSql)

def checkTableGeopoint(cursor):
  checkTableSql = "SELECT EXISTS (  SELECT 1  FROM   pg_tables  WHERE  schemaname = 'app_ldd'  AND    tablename = 'nsll_ld_permissions_points' );"
  cursor.execute(checkTableSql)
  checkTable = cursor.fetchone()
  print str(checkTable[0]) + "\n"
  if not checkTable[0]:
    print "no table geopoint"
    mkTableSql = "CREATE TABLE app_ldd.nsll_ld_permissions_points(objectid INTEGER);"
    cursor.execute(mkTableSql)
    alterTableSql = "SELECT AddGeometryColumn('app_ldd', 'nsll_ld_permissions_points', 'the_geom', 4326, 'POLYGON', 2);"
    cursor.execute(alterTableSql)

def checkTableGeodata(cursor):
  checkTableSql = "SELECT EXISTS (  SELECT 1  FROM   pg_tables  WHERE  schemaname = 'app_ldd'  AND    tablename = 'nsll_ld_permissions_geo' );"
  cursor.execute(checkTableSql)
  checkTable = cursor.fetchone()
  print str(checkTable[0]) + "\n"
  if not checkTable[0]:
    print "no table geodata"
    mkTableSql = "CREATE TABLE app_ldd.nsll_ld_permissions_geo(objectid INTEGER);"
    cursor.execute(mkTableSql)
    alterTableSql = "SELECT AddGeometryColumn('app_ldd', 'nsll_ld_permissions_geo', 'the_geom', 4326, 'POLYGON', 2);"
    cursor.execute(alterTableSql)
    alterTableSql = "SELECT AddGeometryColumn('app_ldd', 'nsll_ld_permissions_geo', 'the_geom_pt', 4326, 'POINT', 2);"
    cursor.execute(alterTableSql)

def checkTablePoly(cursor):
  checkTableSql = "SELECT EXISTS (  SELECT 1  FROM   pg_tables  WHERE  schemaname = 'app_ldd'  AND    tablename = 'nsll_ld_permissions_polygons' );"
  cursor.execute(checkTableSql)
  checkTable = cursor.fetchone()
  print str(checkTable[0]) + "\n"
  if not checkTable[0]:
    print "no table poly"
    mkTableSql = "CREATE TABLE app_ldd.nsll_ld_permissions_polygons(objectid INTEGER);"
    cursor.execute(mkTableSql)
    alterTableSql = "SELECT AddGeometryColumn('app_ldd', 'nsll_ld_permissions_polygons', 'the_geom', 4326, 'POLYGON', 2);"
    cursor.execute(alterTableSql)

def sendSQLgetDict(sql, cursor):
  cursor.execute (sql)
  ans =cursor.fetchall()
  dict_result = []
  for row in ans:
    dict_result.append(dict(row))
  return dict_result

def sendSQLgetList(sql, cursor):
  cursor.execute(sql)
  ans = cursor.fetchall()
  return ans

def sendSQLgetVal(sql, cursor):
  cursor.execute(sql)
  ans = cursor.fetchone()
  return ans

# function to covert easting/northing to lat/lon xml
def convertENtoLatLon(easting, northing):
  if easting != "\N" and northing != "\N":
    lon,lat = pyproj.transform(bng, wgs84, easting, northing)
    ll = {'lat':lat, 'lon':lon}
    return ll
  else:
    ll = {'lat':"none", 'lon':"none"}
    return ll

def convertPolyCoords(polytext):
  out = "error"
#  print polytext
  if polytext is not None:
    m = re.match("POLYGON\(\((.*)\)\)", polytext, re.M|re.I)
    out = "POLYGON(("
    if m:
      pt = m.group(1)
      pa = pt.split(',')
      out += ""
      for coord in pa:
        ca = coord.split(' ')
        easting = float(ca[0])
        northing = float(ca[1])
        lon,lat = pyproj.transform(bng, wgs84, easting, northing)
        out += str(lon) + " " + str(lat) + ","
    out = out[:-1]
    out += "))"
  return out

def convertPointCoords(pointtext):
  out = "error"
#  print pointtext
  if pointtext is not None:
    m = re.match("POINT\((.*)\)", pointtext, re.M|re.I)
    out = "POINT("
    if m:
      pt = m.group(1)
      pa = pt.split(',')
      out += ""
      for coord in pa:
        ca = coord.split(' ')
        easting = float(ca[0])
        northing = float(ca[1])
        lon,lat = pyproj.transform(bng, wgs84, easting, northing)
        out += str(lon) + " " + str(lat) + ","
    out = out[:-1]
    out += ")"
  return out

#set up points
if (scope == "points") or (scope == "all"):
  checkTablePoint(cursor)
  permENsql = "SELECT p.permission_id, p.easting, p.northing FROM app_ldd.ld_permissions AS p WHERE p.easting IS NOT NULL AND p.northing IS NOT NULL;"
  cursor.execute(permENsql)
  permEN = cursor.fetchall()
  ttlForPoints = len(permEN)
  c = 0
  for en in permEN:
    print "processing " + str(c) + " of " + str(ttlForPoints) + " basic points"
    perm_id = str(en[0])
    easting = str(en[1])
    northing = str(en[2])
  #  print perm_id, easting, northing
    checkSQL = "SELECT COUNT(permission_id) FROM app_ldd.ns_permlatlon WHERE permission_id = " + str(perm_id);
    cursor.execute(checkSQL)
    existingRecord = cursor.fetchone()
    lon,lat = pyproj.transform(bng, wgs84, easting, northing)
    slon = str(lon)
    slat = str(lat)
    print existingRecord[0]
    if existingRecord[0] == 0:
      insSql = "INSERT INTO app_ldd.ns_permlatlon(permission_id, lat, lon) VALUES(" + perm_id + ", " + slat + ", " + slon + ");"
      print "inserting..."
      cursor.execute(insSql)
    elif existingRecord[0] > 0:
      updSql = "UPDATE app_ldd.ns_permlatlon SET lat = " + slat + ", lon = " + slon + " WHERE permission_id = " + perm_id + ";"
      print "updating..."
      cursor.execute(updSql)
    c += 1
    if c % 500 == 0:
      dbConnect.commit()
  dbConnect.commit()

#set up polys
if (scope == "geopolys") or (scope == "all") or (scope == "geo"): 
  checkTableGeodata(cursor)
  sql = "SELECT mi_prinx, ST_AsText(the_geom) AS poly FROM app_ldd.mi_ld_permissions_polygons WHERE the_geom Is Not Null;"
  polys = sendSQLgetDict(sql, cursor)
  c = 0
  ttlForPolys = len(polys)
  for g in polys:
    print "processing " + str(c) + " of " + str(ttlForPolys) + " polys"
    c += 1
    if c%25 == 0:
      with open("log_geopoly.txt","w") as f: 
        f.write(str(c) + " polys done")
        f.close()
    newPoly = convertPolyCoords(g['poly'])
    sqlchk = "SELECT objectid FROM app_ldd.nsll_ld_permissions_geo WHERE objectid = " + str(g['mi_prinx']) + ";"
    o = sendSQLgetVal(sqlchk, cursor)
    sqladd = ""
    if (o != None):
      sqladd = "UPDATE app_ldd.nsll_ld_permissions_geo SET the_geom=ST_GeomFromText('" + newPoly + "', 4326) WHERE objectid = " + str(g['mi_prinx']) + ";"
    else:
      sqladd = "INSERT INTO app_ldd.nsll_ld_permissions_geo (objectid, the_geom) VALUES (" + str(g['mi_prinx']) + ", ST_GeomFromText('" + newPoly + "', 4326));"
    cursor.execute(sqladd)
    if c%500 == 0:
      dbConnect.commit()
  dbConnect.commit()

if (scope == "geopoints") or (scope == "all") or (scope == "geo"):
  sql = "SELECT pt.mi_prinx, ST_AsText(pt.the_geom) AS point FROM app_ldd.mi_ld_permissions_points AS pt WHERE pt.the_geom Is Not Null ORDER BY pt.mi_prinx ASC;"
  points = sendSQLgetDict(sql, cursor)
  c = 0
  ttlForGeopoints = len(points)
  for p in points:
    print "processing " + str(c) + " of " + str(ttlForGeopoints) + " geopointss"
    c += 1
    if c%25 == 0:
      with open("log_geopoint.txt","w") as f: 
        f.write(str(c) + " points done")
        f.close()
    newPoint = convertPointCoords(p['point'])
    sqlchk = "SELECT objectid FROM app_ldd.nsll_ld_permissions_geo WHERE objectid = " + str(p['mi_prinx']) + ";"
    o = sendSQLgetVal(sqlchk, cursor)
    sqladd = ""
    if (o != None):
      sqladd = "UPDATE app_ldd.nsll_ld_permissions_geo SET the_geom_pt=ST_GeomFromText('" + newPoint + "', 4326) WHERE objectid = " + str(p['mi_prinx']) + ";"
    else:
      sqladd = "INSERT INTO app_ldd.nsll_ld_permissions_geo (objectid, the_geom_pt) VALUES (" + str(p['mi_prinx']) + ", ST_GeomFromText('" + newPoint + "', 4326));"
    cursor.execute(sqladd)
    if c%500 == 0:
      dbConnect.commit()
  dbConnect.commit()

dbConnect.close()
