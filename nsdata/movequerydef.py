import json
import sys

infile = sys.argv[1]
outfile = sys.argv[2]
with open(infile) as f:
  dataIn = json.loads(f.read())
dataIn['databasePw'] = ""
jsonString = json.dumps(dataIn, indent=4)
with open(outfile, 'w') as f:
  f.write(jsonString)

