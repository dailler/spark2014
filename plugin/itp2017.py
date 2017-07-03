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

def print_error(message):
    console = GPS.Console("ITP_interactive")
    console.write(message, mode="error")
    console.write("\n> ")

def print_message(message):
    console = GPS.Console("ITP_interactive")
    console.write(message)
    console.write("\n> ")

# This function converts a string "Not proved" etc into a color for the background of the goal tree
def create_color(s):
    if s == "Proved":
        return (Gdk.RGBA(0, 10, 0, 5))
    elif s == "Invalid":
        return (Gdk.RGBA(10, 0, 0, 5))
    elif s == "Not Proved":
        return (Gdk.RGBA(10, 0, 0, 5))
    elif s == "Obsolete":
        return (Gdk.RGBA(10, 0, 0, 5))
    elif s == "Valid":
        return (Gdk.RGBA(0, 10, 0, 5))
    elif s == "Not Valid":
        return (Gdk.RGBA(10, 0, 0, 5))
    elif s == "Not Installed":
        return (Gdk.RGBA(10, 0, 0, 5))
    else:
        return (Gdk.RGBA(10, 0, 0, 5))

# This functions takes a Json object and a proof tree and treat it as a
# notification on the prooft tree
# TODO add exceptions
def parse_notif(j, tree, proof_task):
    print j
    # TODO rewrite this
    abs_tree = tree
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
        node_type = j["node_type"]  # TODO further change this
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
                tree.update_iter(node_id, 4, "Not Proved")  # TODO
        elif update["update_info"] == "Proof_status_change":
            proof_attempt = update["proof_attempt"]
            obsolete = update["obsolete"]
            limit = update["limit"]
            if obsolete:
                tree.update_iter(node_id, 4, "Obsolete")  # TODO
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
                else:  # In this case it is necessary just a string
                    tree.update_iter(node_id, 4, "proof_attempt")
        else:
            # TODO
            print "TODO"
        print "Node_change"
    elif notif_type == "Remove":
        node_id = j["node_ID"]
        tree.remove_iter(node_id)
        print "Remove"
    elif notif_type == "Next_Unproven_Node_Id":
        from_node = j["node_ID1"]
        to_node = j["node_ID2"]
        node_jump_select(tree, from_node, to_node)
    elif notif_type == "Initialized":
        print_message("Initialization done")
    elif notif_type == "Saved":
        print_message("Session saved")
    elif notif_type == "Message":
        parse_message(j)
    elif notif_type == "Dead":
        print_message("ITP server encountered a fatal error, please report !")
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
        print("Else")  # TODO

    # TODO next_unproven_node_ID is called too many times... Find a way to solve this
    if not (notif_type == "Next_Unproven_Node_Id" or notif_type == "Task"):
        get_next_id(abs_tree)


def parse_message(j):
    notif_type = j["notification"]
    message = j["message"]
    message_type = message["mess_notif"]
    if message_type == "Proof_error":
        print_error(message["error"])
    elif message_type == "Transf_error":
        print_error(message["error"])
    elif message_type == "Strat_error":
        print_error(message["error"])
    elif message_type == "Replay_Info":
        print_message(message["replay_info"])
    elif message_type == "Query_Info":
        print_message(message["qinfo"])
    elif message_type == "Query_Error":
        print_error(message["qerror"])
    elif message_type == "Help":
        print_message(message["qhelp"])
    elif message_type == "Information":
        print_message(message["information"])
    elif message_type == "Task_Monitor":
        print notif_type  # TODO
    elif message_type == "Parse_Or_Type_Error":
        print_error(message["error"])
    elif message_type == "Error":
        print_error(message["error"])
    elif message_type == "Open_File_Error":
        print_error(message["open_error"])
    elif message_type == "File_Saved":
        print_message(message["information"])
    else:
        print("Else")  # TODO


def node_jump_select(tree, from_node, to_node):
    # TODO this should be a function
    tree_selection = tree.view.get_selection()
    from_node_row = tree.node_id_to_row_ref[from_node]
    from_node_path = from_node_row.get_path()
    from_node_iter = tree.model.get_iter(from_node_path)
    if (tree_selection.path_is_selected(from_node_path)):
        tree_selection.unselect_all()
        to_node_row = tree.node_id_to_row_ref[to_node]
        to_node_path = to_node_row.get_path()
        to_node_iter = tree.model.get_iter(to_node_path)
        tree_selection.select_path(to_node_path)


def command_request(command, node_id):
    # TODO if remove do something els if save also do something else
    # TODO very ad hoc
    print_message("")
    if command == "Save":
        return "{\"ide_request\": \"Save_req\" " + " }"
    elif command == "Remove":
        return ("{\"ide_request\": \"Remove_subtree\", \"node_ID\":" +
        str(node_id) + " }")
    else:
        return ("{\"ide_request\": \"Command_req\", \"node_ID\":" +
        str(node_id) + ", \"command\" : " + json.dumps(command) + " }")

class Tree:

    def __init__(self):
        # Create a tree that can be appended anywhere
        self.box = Gtk.VBox()
        scroll = Gtk.ScrolledWindow()
        # TODO decide which data we want in this tree
        self.model = Gtk.TreeStore(str, str, str, str, str, Gdk.RGBA)
        # Create the view as a function of the model
        self.view = Gtk.TreeView(self.model)
        self.view.set_headers_visible(True)

        # Adding the tree to the scrollbar
        scroll.add(self.view)
        self.box.pack_start(scroll, True, True, 0)

        # TODO by default append this box to the GPS.MDI
        GPS.MDI.add(self.box, "Proof Tree", "Proof Tree", group=101, position=4) # TODO find the correct group

        cell = Gtk.CellRendererText(xalign=0)
        col2 = Gtk.TreeViewColumn("Name")
        col2.pack_start(cell, True)
        col2.add_attribute(cell, "text", 2)
        # TODO test
        col2.add_attribute(cell, "background_rgba", 5)
        col2.set_expand(True)
        self.view.append_column(col2)

        # Populate with columns we want
        cell = Gtk.CellRendererText(xalign=0)
        self.close_col = Gtk.TreeViewColumn("ID")
        self.close_col.pack_start(cell, True)
        self.close_col.add_attribute(cell, "text", 0)
        self.close_col.add_attribute(cell, "background_rgba", 5)
        self.view.append_column(self.close_col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("parent")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 1)
        col.set_expand(True)
        col.add_attribute(cell, "background_rgba", 5)
        self.view.append_column(col)

        # TODO ???
        cell = Gtk.CellRendererText(xalign=0)
        col = Gtk.TreeViewColumn("Status")
        col.pack_start(cell, True)
        col.add_attribute(cell, "text", 4)
        col.add_attribute(cell, "background_rgba", 5)
        col.set_expand(True)
        self.view.append_column(col)

        # TODO reinitialize the map from node_id to row_ref
        # We have a dictionnary from node_id to row_references because we want an
        # "efficient" way to get/remove/etc a particular row and we are not going
        # to go through the whole tree each time: O(n) vs O (ln n)
        # TODO find something that do exactly this in Gtk).
        # TODO unused node_id_to_row_ref = {}
        self.node_id_to_row_ref = {}

        # Make the tree in an independant window of gps
        # TODO not needed anymore. Should not use it in python and prefer group
        # GPS.execute_action(action="Split horizontally")

    def get_iter(self, node):
        try:
            row = self.node_id_to_row_ref[node]
            path = row.get_path()
            return (self.model.get_iter(path))
        except:
            if debug_mode:
                print ("get_iter error: node does not exists %d", node)
            return None

    #  Associate the corresponding row of an iter to its node in node_id_to_row_ref
    def set_iter(self, new_iter, node):
        path = self.model.get_path(new_iter)
        row = Gtk.TreeRowReference.new(self.model, path)
        self.node_id_to_row_ref[node] = row

    def add_iter(self, node, parent, name, node_type, proved):
        if parent == 0:
            parent_iter = self.model.get_iter_first()
        else:
            parent_iter = self.get_iter(parent)
            if parent_iter is None:
                if debug_mode:
                    print ("add_iter error: parent does not exists %d", parent)
                parent_iter = self.model.get_iter_first()

        # Append as a child of parent_iter
        new_iter = self.model.append(parent_iter)
        color = create_color (proved)
        self.model[new_iter] = [str(node), str(parent), name, node_type, proved, color]
        self.set_iter(new_iter, node)
        # TODO expand all at the end ???
        self.view.expand_all()

    def update_iter(self, node_id, field, value):
        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        if field == 4:
            color = create_color (value)
            self.model[iter][5] = color
        self.model[iter][field] = value

    def remove_iter(self, node_id):
        row = self.node_id_to_row_ref[node_id]
        path = row.get_path()
        iter = self.model.get_iter(path)
        self.model.remove(iter)
        self.node_id_to_row_ref.remove(node_id)

n = 0
nb_notif = 0

# TODO this is also a send_request
def get_task(p, node_id):
    global n
    request = "{\"ide_request\": \"Get_task\", \"node_ID\":" + str(node_id) + "}"
    p.send(request)
    n= n + 1
    print("TODO" + str(n))

def get_next_id(tree):
    p = tree.process
    selection = tree.tree.view.get_selection()
    model, paths = selection.get_selected_rows ()
    print (paths)
    if len(paths) == 1:
        for i in paths:
            cur_iter = model.get_iter(i)
            it = model[cur_iter][0]
            p.send("{\"ide_request\": \"Get_first_unproven_node\", \"node_ID\":" + it + "}")

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
        self.console = GPS.Console("ITP_interactive", on_input=self.interactive_console_input)
        self.console.write("> ")
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

    def interactive_console_input(self, console, command):
        # TODO
        tree_selection = self.tree.view.get_selection()
        node_id = 0
        tree_selection.selected_foreach (lambda tree_model, tree_path, tree_iter:
            self.send_request(self.process, tree_model[tree_iter][0], command))
        print (node_id)

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
    print "[ITP] Launched"
    GPS.Locations.remove_category("Builder results")
    #GPS.execute_action(action="Split horizontally")

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
                mlw_file = os.path.join (dir_name, file)
    if mlw_file == "":
        print "TODO error"

    options = "--limit-line test.adb:79:16:VC_POSTCONDITION "
    command = gnat_server + " " + options + mlw_file
    print(command)
    tree = Tree_with_process(command)

def interactive_proof(self):
    # TODO use examine_root_project
    start_ITP(examine_root_project)

# TODO use this part of the tuto for interactivity. Not necessary right now.
"""def example1():
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
"""

