from test_support import *
import time

def launch_server(limit_line="", input_file=""):
    cmd = ["gnat_server"]
    cmd += ["--limit-line"]
    cmd += [limit_line]
    cmd += ["test.mlw"]
    read, write = os.pipe()
    process = Run (cmd, cwd="gnatprove", input=read, bg=True, timeout=20)
    with open ("test.in", "r") as in_file:
        for l in in_file:
            time.sleep(1)
            print(l)
            os.write(write, l)
            #write.flush()
    process.wait()
    s = process.out
    return s

prove_all(counterexample=False, prover=["cvc4"])
# Print the JSON result of the server

result = launch_server(limit_line="test.adb:11:16:VC_POSTCONDITION", input_file="test.in")
print(result)
