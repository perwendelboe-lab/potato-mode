#!/usr/bin/env python3
# Send QEMU monitor commands: mon.py "screendump /tmp/s.ppm" "sendkey ret"
import socket,sys,time,os
s=socket.socket(socket.AF_UNIX); s.connect('/tmp/omarchy-mon.sock'); s.settimeout(1)
time.sleep(0.3)
try: s.recv(65536)
except socket.timeout: pass
for c in sys.argv[1:]:
    s.send((c+'\n').encode()); time.sleep(float(os.environ.get("KEYDELAY","0.15")))
    try: s.recv(65536)
    except socket.timeout: pass
