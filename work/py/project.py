#!/usr/bin/python3
import os
import sys
import time


# find project root dir
class Configs:
    def __init__(self, projectdir):
        self.rootdir = projectdir
        self.datadir = os.path.join(projectdir, "data")
        self.configdir = os.path.join(projectdir, "data", "config_sheets")
        self.outputdir = os.path.join(projectdir, "output")
        self.pydir = os.path.join(projectdir, "py")
        self.docdir = os.path.join(projectdir, "doc")


currentdir = os.getcwd()
dirlist = currentdir.split("/")

# Find the "work" directory
split_index = 1
for directory in dirlist:
    if directory == "work":
        break  # Exit the loop when we find the "work" directory
    split_index += 1  # Otherwise increment the index

# Unpack items in dirlist
# From: https://stackoverflow.com/questions/14826888
projectdir = os.path.join(*dirlist[0:split_index])

# Add leading "/", as it will not exist right now
projectdir = os.path.join("/", projectdir)
configs = Configs(projectdir)
