#!/usr/bin/env python3
# send a line to the VM serial console and print output for N seconds
import socket,sys,time
s=socket.socket(socket.AF_UNIX); s.connect('/tmp/potato-serial.sock'); s.settimeout(0.5)
for line in sys.argv[2:]:
    s.send((line+'\n').encode()); time.sleep(2)
end=time.time()+float(sys.argv[1]); out=b''
while time.time()<end:
    try: out+=s.recv(65536)
    except socket.timeout: pass
print(out.decode(errors='replace')[-3000:])
