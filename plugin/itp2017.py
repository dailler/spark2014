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

debug_mode = False

examine_root_project = 'ITP'

#TODO add a perspective

# This functions takes a Json object and a proof tree and treat it as a
# notification on the prooft tree
# TODO add exceptions
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
        tree.add_iter(node_id, parent_id, name, node_type, "Invalid")
        print "New_node"
    elif notif_type == "Node_change":
        node_id = j["node_ID"]
        update = j["update"]
        if update["update_info"] == "Proved":
            if update["proved"]:
                tree.update_iter(node_id, 4, "Proved")
            else:
                tree.update_iter(node_id, 4, "Not Proved")# TODO
        elif update["update_info"] == "Proof_status_change":
            proof_attempt = update["proof_attempt"]
            obsolete = update["obsolete"]
            limit = update["limit"]
            if obsolete:
                tree.update_iter(node_id, 4, "Obsolete")# TODO
            else:
                proof_attempt_result = proof_attempt["proof_attempt"]
                if proof_attempt_result == "Done":
                    prover_result = proof_attempt["prover_result"]
                    pr_answer = prover_result["pr_answer"]
                    if pr_answer == "Valid":
                        tree.update_iter(node_id, 4, "Valid")
                    else:
                        tree.update_iter(node_id, 4, "Not Valid")
                elif proof_attempt_result == "Uninstalled":
                    tree.update_iter(node_id, 4, "Not Installed")
                else: # In this case it is necessary just a string
                    tree.update_iter(node_id, 4, "proof_attempt")
        else:
            #TODO
            print "TODO"
        print "Node_change"
    elif notif_type == "Remove":
        node_id = j["node_ID"]
        tree.remove_iter(node_id)
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
        proof_task = GPS.Console("Proof Task")
        proof_task.clear()
        proof_task.write(j["task"])
        GPS.Console()
        print notif_type
    elif notif_type == "File_contents":
        print notif_type
    else:
        print("Else")

def command_request(command, node_id):
    return "{\"ide_request\": \"Command_req\", \"node_ID\":" + str(node_id) + ", \"command\" : \"" + command + "\" }"

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
        self.model = Gtk.TreeStore(str, str, str, str, str)
        # Create the view as a function of the model
        self.view = Gtk.TreeView(self.model)
        self.view.set_headers_visible(True)

        # Adding the tree to the scrollbar
        scroll.add(self.view)
        self.box.pack_start(scroll, True, True, 0)

        # TODO by default append this box to the GPS.MDI
        GPS.MDI.add(self.box, "Proof Tree", "Proof Tree")

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col2 = Gtk.TreeViewColumn("Name")
        col2.pack_start(cell, True)
        col2.add_attribute(cell, "text", 2)
        col2.set_expand(True)
        self.view.append_column(col2)


        # Populate with columns we want
        cell = Gtk.CellRendererText(xalign=0)
        self.close_col = Gtk.TreeViewColumn("ID")
        self.close_col.pack_start(cell, True)
        self.close_col.add_attribute(cell, "text", 0)
        self.view.append_column(self.close_col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("parent")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 1)
        col.set_expand(True)
        self.view.append_column(col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("Status")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 4)
        col.set_expand(True)
        self.view.append_column(col)

        # TODO reinitialize the map from node_id to row_ref
        self.node_id_to_row_ref = {}

        # Make the tree in an independant window of gps
        GPS.execute_action(action="Split horizontally")

    def add_iter(self, node, parent, name, node_type, proved):
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
        self.model[iter] = [str(node), str(parent), name, node_type, proved]
        path = self.model.get_path(iter)

        row = Gtk.TreeRowReference.new(self.model, path)
        self.node_id_to_row_ref[node] = row
        if self.model.iter_has_child(iter):
            print (True)
        else:
            print (False)
        self.view.expand_all()

    def update_iter(self, node_id, field, value):
        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        self.model[iter][field] = value

    def remove_iter(self, node_id):
        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        self.model.remove(iter)
        self.node_id_to_row_ref.remove(node_id)

    # TODO this is debug
    def print_notifications(self, notification):
        a = GPS.Console("Notifications")
        a.write(notification)
        GPS.Console()

    def check_notifications(self, unused, delimiter, notification):
        global nb_notif
        if debug_mode:
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



# TODO DOUBLON
#def send_request(p, node_id, command):
#    global n
#    request = "{\"ide_request\": \"Command_req\", \"node_ID\":" + str(node_id) + ", \"command\" : \"" + command + "\" }"
#    print (request)
#    p.send(request)
#    n = n + 1
#    print("TODO" + str(n))

# TODO this is also a send_request
def get_task (p, node_id):
    global n
    request = "{\"ide_request\": \"Get_task\", \"node_ID\":" + str(node_id) + "}"
    p.send(request)
    n= n + 1
    print("TODO" + str(n))

# TODO replaced by the stuff in the class Tree_with_process
def interactive_console_input(process, tree, console, command):
    # TODO
    tree_selection = tree.view.get_selection()
    node_id = 0
    tree_selection.selected_foreach (lambda tree_model, tree_path, tree_iter:
                                        send_request(process, tree_model[tree_iter][0], command))
    print (node_id)
#    tree.send_request(process, 0, node_id, command)

class Tree_with_process:
    def __init__(self, command):
        # TODO
        gnat_server = "/home/sdailler/Projet/spark_env/spark2014/install/libexec/spark/bin/gnat_server "
        options = "--why3-conf " + "/home/sdailler/Projet/spark_env/spark2014/why3.conf " + "--standalone " + "--debug "
        file = "/home/sdailler/Projet/spark_env/spark2014/testsuite/gnatprove/temp/tmp-test-itp__example-26211/src/gnatprove/test.mlw"

        #init the tree
        self.tree = Tree()
        self.process = GPS.Process(gnat_server + options + file, regexp=">>>>", on_match=self.tree.check_notifications)
        self.console = GPS.Console("ITP_interactive", on_input=self.interactive_console_input2)
        #Back to the Messages console
        GPS.Console()

        # Query task each time something is clicked TODO see if it is more efficient to save task in GPS
        tree_selection = self.tree.view.get_selection()
        tree_selection.set_select_function(self.select_function)

        # Define a proof task
        proof_task = GPS.Console("Proof Task")
        GPS.execute_action(action="Split horizontally")

    def select_function (self, select, model, path, currently_selected):
        tree_iter = model.get_iter(path)
        #TODO get task instead
        get_task(self.process, model[tree_iter][0])
        return True

    def interactive_console_input2(self, console, command):
        # TODO
        tree_selection = self.tree.view.get_selection()
        node_id = 0
        tree_selection.selected_foreach (lambda tree_model, tree_path, tree_iter:
            self.send_request(self.process, tree_model[tree_iter][0], command))
        print (node_id)

        #interactive_console_input(self.process, self.tree, console, command)


    def send_request(self, timeout, node_id, command):
        global n
        request = command_request (command, node_id)
        print (request)
        self.process.send(request)
        n = n + 1
        print("TODO" + str(n))



def todo (tree):

    # Temporary arguments to be given to the gnat_server TODO
    gnat_server = "/home/sdailler/Projet/spark_env/spark2014/install/libexec/spark/bin/gnat_server "
    options = "--why3-conf " + "/home/sdailler/Projet/spark_env/spark2014/why3.conf " + "--standalone " + "--debug "
    file = "/home/sdailler/Projet/spark_env/spark2014/testsuite/gnatprove/temp/tmp-test-itp__example-26211/src/gnatprove/test.mlw"
    command = ["/home/sdailler/Projet/spark_env/spark2014/install/libexec/spark/bin/gnat_server", "--why3-conf", "/home/sdailler/Projet/spark_env/spark2014/why3.conf", "--standalone", "--debug", file]

    # TODO >>>> is temporary
    # TODO_test = "/home/sdailler/test/test_ocaml/test.byte"
    p = GPS.Process(gnat_server + options + file, regexp=">>>>", on_match=tree.check_notifications)

    def interactive_console_input2(console, command):
        interactive_console_input(p, tree, console, command)

    command_interface = GPS.Console("ITP_interactive", on_input=interactive_console_input2)
    GPS.Console()

    # TODO generate real requests
    def send_request(p, timeout, node_id, command):
        global n
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
    file = "/home/sdailler/Projet/spark_env/spark2014/testsuite/gnatprove/temp/tmp-test-itp__example-26211/src/gnatprove/test.mlw"
    tree = Tree_with_process(["/home/sdailler/Projet/spark_env/spark2014/install/libexec/spark/bin/gnat_server", "--why3-conf", "/home/sdailler/Projet/spark_env/spark2014/why3.conf", "--standalone", "--debug", file])
    #tree = Tree()
    #launch_console(tree)

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


