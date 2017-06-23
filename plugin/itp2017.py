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

debug_mode = False

examine_root_project = 'ITP'

#TODO add a perspective

def print_to_console(message):
    console = GPS.Console("ITP_interactive")
    console.write(message)
    console.write("\n> ")


# This functions takes a Json object and a proof tree and treat it as a
# notification on the prooft tree
# TODO add exceptions
def parse_notif(j, tree, proof_task):
    print j
    tree = tree.tree
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
        message = j["message"]
        message_type = message["mess_notif"]
        if message_type == "Help":
            print_to_console (message["qhelp"])
        print notif_type
    elif notif_type == "Dead":
        print notif_type
    elif notif_type == "Task":
        proof_task.set_read_only(read_only=False)
        proof_task.delete()
        proof_task.insert(j["task"])
        proof_task.save(interactive=False)
        proof_task.set_read_only(read_only=True)
        GPS.Console()
        print notif_type
    elif notif_type == "File_contents":
        print notif_type
    else:
        print("Else") # TODO

def parse_message(j):
    notif_type = j["notification"]
    message = j["message"]
    message_type = message["mess_notif"]
    if message_type == "Proof_error":
        print notif_type
    elif message_type == "Transf_error":
        print notif_type
    elif message_type == "Strat_error":
        print notif_type
    elif message_type == "Replay_Info":
        print notif_type
    elif message_type == "Query_Info":
        print notif_type
    elif message_type == "Query_Error":
        print notif_type
    elif message_type == "Help":
        print_to_console (message["qhelp"])
    elif message_type == "Information":
        print_to_console (message["information"])
    elif message_type == "Task_Monitor":
        print notif_type
    elif message_type == "Parse_Or_Type_Error":
        print notif_type
    elif message_type == "Error":
        print notif_type
    elif message_type == "Open_File_Error":
        print notif_type
    elif message_type == "File_Saved":
        print notif_type
    else:
        print("Else") # TODO


def command_request(command, node_id):
    # TODO if remove do something els if save also do something else
    # TODO very ad hoc
    if command == "Save":
        return "{\"ide_request\": \"Save_req\" " + " }"
    elif command == "Remove":
        return "{\"ide_request\": \"Remove_subtree\", \"node_ID\":" + str(node_id) + " }"
    else:
        return "{\"ide_request\": \"Command_req\", \"node_ID\":" + str(node_id) + ", \"command\" : " + json.dumps(command) + " }"

class Tree:

    # We have a dictionnary from node_id to row_references because we want an
    # "efficient" way to get/remove/etc a particular row and we are not going
    # to go through the whole tree each time: O(n) vs O (ln n)
    # TODO find something that do exactly this in Gtk).
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
        GPS.MDI.add(self.box, "Proof Tree", "Proof Tree", group=101, position=4) # TODO find the correct group

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
        # TODO not needed anymore. Should not use it in python and prefer group
        #GPS.execute_action(action="Split horizontally")

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

n = 0
nb_notif = 0


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

class Tree_with_process:
    def __init__(self, command):

        #init the tree
        self.tree = Tree()
        self.process = GPS.Process(command, regexp=">>>>", on_match=self.check_notifications)
        self.console = GPS.Console("ITP_interactive", on_input=self.interactive_console_input2)
        #Back to the Messages console
        GPS.Console()

        # Query task each time something is clicked TODO see if it is more efficient to save task in GPS
        tree_selection = self.tree.view.get_selection()
        tree_selection.set_select_function(self.select_function)

        # Define a proof task
        proof_task_file = GPS.File ("Proof Task", local=True)
        self.proof_task = GPS.EditorBuffer.get(proof_task_file, force=True, open=True)
        self.proof_task.set_read_only()
        # TODO should prefer using group and position
        #GPS.execute_action(action="Split horizontally")

    def check_notifications(self, unused, delimiter, notification):
        global nb_notif
        if debug_mode:
            self.print_notifications(notification)
        nb_notif = nb_notif + 1
        try:
            # Remove remaining stderr output (stderr and stdout are mixed) by
            # looking for the beginning of the notification (begins with {).
            i = notification.find("{")
            p = json.loads(notification[i:])
            parse_notif(p, self, self.proof_task)
        except (ValueError):
            print ("Bad Json value")
        except (KeyError):
            print ("Bad Json key")
        except (TypeError):
            print ("Bad type")

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

# TODO never put extra_args because they cannot be removed
# TODO remove this function which comes from SPARK plugin
def start_ITP(target, args=[]):
    #TODO remove
    print "Launched"
    GPS.Locations.remove_category("Builder results")
    #GPS.execute_action(action="Split horizontally")

    # TODO all these options are already in spark2014.py
    gnat_server = os_utils.locate_exec_on_path("gnat_server")
    objdirs = GPS.Project.root().object_dirs()
    default_objdir = objdirs[0]
    obj_subdir_name = "gnatprove"
    dir_name = os.path.join(default_objdir, obj_subdir_name)
    mlw_file = ""
    for dir_name, sub_dir_name, files in os.walk(dir_name):
        for file in files:
            if fnmatch.fnmatch(file, '*.mlw') and mlw_file == "":
                mlw_file = os.path.join (dir_name, file)
    if mlw_file == "":
        print "TODO error"

    command = gnat_server + " " + mlw_file
    print(command)
    tree = Tree_with_process(command)

def interactive_proof(self):
    # TODO use examine_root_project
    start_ITP(examine_root_project)

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


