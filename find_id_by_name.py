#!/usr/bin/python

import sys
from json import loads

def jsonname (name):
    for entry in parsedJson:
        if name == entry ['name']:
            return entry ['id']

parsedJson = loads (sys.argv[2])

print (jsonname(str(sys.argv[1])))

