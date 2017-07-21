#!/usr/bin/python
# -*- coding: utf-8 -*-

############################################################################
# No user customization below this line
############################################################################

"""
TODO
"""

import GPS, sys
import os_utils
import os.path
import tool_output
import json
import re
from os import *
# Import graphics Gtk libraries for proof interactive elements
from gi.repository import Gtk, Gdk, GLib, Pango
import pygps
from modules import Module
from gps_utils.console_process import Console_Process
import fnmatch


examine_root_project = 'ITP'

# TODO this is also contained in spark2014.py
# Path to this executable
cur_exec_path = os.path.dirname(os.path.abspath(__file__))

# The library for itp is under spark2014/
# TODO this is ugly to use module in python as there is no known form of
# static checking a.b("x") is always statically valid. Sigh !
spark2014_dir = os.path.join(cur_exec_path, "spark2014")
print(spark2014_dir)
sys.path.append(spark2014_dir)
import itp_lib

# TODO put this somewhere where it makes sense
tree = itp_lib.Tree_with_process()


# TODO this does not need to exists inside this class
# TODO never put extra_args because they cannot be removed
# TODO remove this function which comes from SPARK plugin
def start_ITP(tree, context, args=[]):
    itp_lib.print_debug("[ITP] Launched")
    # TODO what is this ????
    GPS.Locations.remove_category("Builder results")
    # GPS.execute_action(action="Split horizontally")

    # TODO all these options are already in spark2014.py
    gnat_server = os_utils.locate_exec_on_path("gnat_server")
    objdirs = GPS.Project.root().object_dirs()
    default_objdir = objdirs[0]
    obj_subdir_name = "gnatprove"
    dir_name = os.path.join(default_objdir, obj_subdir_name)
    os.chdir(dir_name)
    mlw_file = ""
    for dir_name, sub_dir_name, files in os.walk(dir_name):
        for file in files:
            if fnmatch.fnmatch(file, '*.mlw') and mlw_file == "":
                mlw_file = os.path.join(dir_name, file)
    if mlw_file == "":
        itp_lib.print_debug("TODO")

    # TODO this context stuff should be done in SPARK and better done...
    print (context)
    msg = context.location()
    print (msg)
    # TODO inside generic unit stuff ???
    # GPS.Locations.remove_category("Builder results")
    # GPS.BuildTarget(prove_check()).execute(extra_args=args,
    #                                       synchronous=False)
    options = ""
    # options = "--limit-line " +  str(msg) + ":VC_POSTCONDITION "
    # "test.adb:79:16:VC_POSTCONDITION "
    command = gnat_server + " " + options + mlw_file
    print(command)
    tree.start(command)


def interactive_proof(context):
    global tree
    # TODO use examine_root_project
    start_ITP(tree, context)


def exit_ITP():
    global tree
    tree.exit()
