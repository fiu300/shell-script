#!/usr/bin/env python

import os, sys

# Check the script is being run by root user
if not os.geteuid()==0:
    sys.exit("%s must be run as sudo user or root!" % str(sys.argv[0]))
