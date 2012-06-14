
import readers
from tools import *

# Build sketch of inputs

m = Merge()

subp = m.new_entity("SUBPROGRAM")
s    = subp.states

proved    = s.new_value("PROVED")
not_p     = s.new_value("NOT PROVED")
partial_p = s.name_meet("PARTIALLY PROVED", {proved, not_p})

vcs = subp.new_input(reader=readers.ErrorListing("VC"),
                     maps={"OK" : proved,
                           "KO" : not_p,
                           "PARTIAL OK" : partial_p})
vcs.load("proofs.out")
m.loads("program.json")

# Output results

# set_goal(ok)

for i in vcs.object.content():
    print i + " - SUBPROGRAM : " + str(vcs.object.follow("SUBPROGRAM", i))

for name in ["VC.STATUS", "SUBPROGRAM.STATUS"]:
    for i in vcs.object.content():
        print i + " - " + name + " : " + str(vcs.object.follow(name, i))

for i in subp.object.content():
    name = "SUBPROGRAM.STATUS"
    print i + " - " + name + " : " + str(subp.object.follow(name, i))

