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



examine_root_project = 'ITP'

#TODO add a perspective

class Tree:

    def __init__(self):
        # Create a tree that can be appended anywhere
        self.box = Gtk.VBox()
        scroll = Gtk.ScrolledWindow()
        # TODO decide which data we want in this tree
        self.model = Gtk.ListStore(str, str)
        # Create the view as a function of the model
        self.view = Gtk.TreeView(self.model)
        self.view.set_headers_visible(False)

        # Adding the tree to the scrollbar
        scroll.add(self.view)
        self.box.pack_start(scroll, True, True, 0)

        # TODO by default append this box to the GPS.MDI
        GPS.MDI.add(self.box, "Proof Tree", "Proof Tree")

        # Populate with columns we want
        cell = Gtk.CellRendererText(xalign=0)
        self.close_col = Gtk.TreeViewColumn("ID")
        self.close_col.pack_start(cell, True)
        self.close_col.add_attribute(cell, "text", 1)
        self.view.append_column(self.close_col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("Name")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 0)
        col.set_expand(True)
        self.view.append_column(col)

        # TODO add random node for fun
        self.add_iter("a", "c")
        self.add_iter("jfk", "kjofdk")


    def add_iter(self, x, y):
        iter = self.model.append()
        self.model[iter] = [x, y]

    def check_notifications(self, p, delimiter, match):
        global nb_notif
        notification = match
        nb_notif = nb_notif + 1
        try:
            if nb_notif == 1:
                print notification
            p = json.loads(notification)
            parse_notif(p, self)
        except (ValueError):
            print ("Bad Json value")
        except (KeyError):
            print ("Bad Json key")
        except (TypeError):
            print ("Bad type")

n = 0
nb_notif = 0

# This functions takes a Json object and treat it as a notification
def parse_notif(j, tree):
    try:
        notif_type = j["notification"]
    except:
        if debug_mode:
            print("This is a valid json string but an invalid notification")
            #TODO
    if notif_type == "New_node":
        node_id = j["node_ID"]
        parent_id = j["parent_ID"]
        node_type = j["node_type"] # TODO further change this
        name = j["name"]
        detached = j["detached"]
        tree.add_iter(str(node_id), str(parent_id))
        print "New_node"
    elif notif_type == "Node_change":
        print "Node_change"
    elif notif_type == "Remove":
        print "Remove"
    elif notif_type == "Next_Unproven_Node_Id":
        print "Next_Unproven_Node_Id"
    elif notif_type == "Initialized":
        print notif_type
    elif notif_type == "Saved":
        print notif_type
    elif notif_type == "Message":
        print notif_type
    elif notif_type == "Dead":
        print notif_type
    elif notif_type == "Task":
        print notif_type
    elif notif_type == "File_contents":
        print notif_type
    else:
        print("Else")


def todo (tree):

    # Temporary arguments to be given to the gnat_server TODO
    gnat_server = "/home/sdailler/Projet/spark_env/spark2014/install/libexec/spark/bin/gnat_server "
    options = "--why3-conf " + "/home/sdailler/Projet/spark_env/spark2014/why3.conf " + "--standalone " + "--debug "
    file = "/home/sdailler/Projet/spark_env/spark2014/testsuite/gnatprove/temp/tmp-test-itp__example-26211/src/gnatprove/test.mlw"

    # TODO >>>> is temporary
    p = GPS.Process(gnat_server + options + file, regexp=">>>>", on_match=tree.check_notifications)

    # TODO generate real requests
    def send_request(p, timeout):
        global n
        p.send("request" + str(n))
        n = n + 1
        print("TODO" + str (n))

    # Send request automatically... TODO not necessary in the long term
    t = GPS.Timeout(30000, lambda t: send_request(p, t))
    # TODO test

def launch_console(tree):
    #input_itp = GPS.Console("ITP_input")
    #input_itp.write("ITP_input")  # Explicit redirection

    todo(tree)
    #p = GPS.Process("why3ide")
    #p.id = "ITP console"

# TODO never put extra_args because they cannot be removed
# TODO remove this function which comes from SPARK plugin
def generic_on_analyze(target, args=[]):
    #TODO remove
    print "Launched"
    GPS.Locations.remove_category("Builder results")
    #GPS.execute_action(action="Split horizontally")
    tree = Tree()
    tree.add_iter("jkhsqd","dhsfk")
    launch_console(tree)

def on_examine_root_project(self):
    generic_on_analyze(examine_root_project)

# TODO use this part of the tuto for interactivity. Not necessary right now.
def example1():
    def on_clicked(*args):
        GPS.Console().write("button was pressed\n")

    def create():
        button = Gtk.Button('press')
        button.connect('clicked', on_clicked)
        GPS.MDI.add(button, "From testgtk", "testgtk")


        for w in GPS.MDI.children():
            print "toto in MDI"
            a = w.name()
            print (a)

        hbox = Gtk.HBox()
        #add(widget, title='', short='', group=0, position=0, save_desktop=None)
        GPS.MDI.add (widget=hbox,
                    title="Interactive Theorem Proving",
                    short = "ITP",
                    group = 1,
                    position = 1)
        vbox = Gtk.VBox(parent=GPS.MDI.current().pywidget().get_toplevel())
        GPS.MDI.add (vbox, "Proof Tree", "ITPtree")


    create()


