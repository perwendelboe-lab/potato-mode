#!/bin/bash
# screenshot the VM to PNG (default /tmp/s.png)
sudo rm -f /tmp/s.ppm
python3 "$(dirname "$0")/mon.py" "screendump /tmp/s.ppm"
sleep 1; sudo chmod 644 /tmp/s.ppm
python3 -c "from PIL import Image; Image.open('/tmp/s.ppm').save('${1:-/tmp/s.png}')"
