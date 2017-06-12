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

    # We have a dictionnary from node_id to row_references because we want an
    # "efficient" way to get/remove/etc a particular row and we are not going
    # to go through the whole tree each time (TODO find something that do
    # exactly this in Gtk).
    node_id_to_row_ref = {}

    def __init__(self):
        # Create a tree that can be appended anywhere
        self.box = Gtk.VBox()
        scroll = Gtk.ScrolledWindow()
        # TODO decide which data we want in this tree
        self.model = Gtk.TreeStore(str, str, str, str)
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
        self.close_col.add_attribute(cell, "text", 0)
        self.view.append_column(self.close_col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col2 = Gtk.TreeViewColumn("parent")
        col2.pack_start(cell, True)
        col2.add_attribute(cell, "text", 2)
        col2.set_expand(True)
        self.view.append_column(col2)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("Name")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 1)
        col.set_expand(True)
        self.view.append_column(col)

        # TODO reinitialize the map from node_id to row_ref
        self.node_id_to_row_ref = {}

    def add_iter(self, node, parent, name, node_type):
        if parent == 0:
            parent_iter = self.model.get_iter_first()
        else:
            try:
                parent_row = self.node_id_to_row_ref[parent]
                parent_path = parent_row.get_path()
                parent_iter = self.model.get_iter(parent_path)
            except:
                print ("TODO BAD remove this")
                parent_iter = self.model.get_iter_first()


        iter = self.model.append(parent_iter)
        self.model[iter] = [str(node), str(parent), name, node_type]
        path = self.model.get_path(iter)

        row = Gtk.TreeRowReference.new(self.model, path)
        self.node_id_to_row_ref[node] = row
        if self.model.iter_has_child(iter):
            print (True)
        else:
            print (False)
        self.view.expand_all()

    # TODO this is debug
    def print_notifications(self, notification):
        a = GPS.Console("Notifications")
        a.write(notification)
        GPS.Console()

    def check_notifications(self, unused, delimiter, notification):
        global nb_notif
        self.print_notifications(notification)
        nb_notif = nb_notif + 1
        try:
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
        tree.add_iter(node_id, parent_id, name, node_type)
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
    command = ["/home/sdailler/Projet/spark_env/spark2014/install/libexec/spark/bin/gnat_server", "--why3-conf", "/home/sdailler/Projet/spark_env/spark2014/why3.conf", "--standalone", "--debug", file]

    # TODO >>>> is temporary
    # TODO_test = "/home/sdailler/test/test_ocaml/test.byte"
    p = GPS.Process(gnat_server + options + file, regexp=">>>>", on_match=tree.check_notifications)

    # TODO generate real requests
    def send_request(p, timeout, node_id, command):
        global n
        # TODO
        # tree_selection = tree.view.get_selection()
        # tree_selection.selected_foreach (fun (tree_model, tree_path, tree_iter) -> node_id = tree_model [tree_iter][0])
        request = "{\"ide_request\": \"Command_req\", \"node_ID\":" + str(node_id) + ", \"command\" : \"" + command + "\" }"
        print (request)
        p.send(request)
        n = n + 1
        print("TODO" + str(n))

    # Send request automatically... TODO not necessary in the long term
    t = GPS.Timeout(15000, lambda t: send_request(p, t, 101, "case true"))
    # TODO test

def launch_console(tree):
    todo(tree)

# TODO never put extra_args because they cannot be removed
# TODO remove this function which comes from SPARK plugin
def generic_on_analyze(target, args=[]):
    #TODO remove
    print "Launched"
    GPS.Locations.remove_category("Builder results")
    #GPS.execute_action(action="Split horizontally")
    tree = Tree()
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


