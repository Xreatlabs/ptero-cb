#!/usr/bin/env python3
"""
XreatLabs 24/7 File Loop Script
Author: Ahmadisog
"""

import os
import time
from datetime import datetime

DIR = "./xreatlabs_loop"
os.makedirs(DIR, exist_ok=True)

print(f"🔄 Starting 24/7 file loop in {DIR}...")

while True:
    filename = os.path.join(DIR, f"xreat_file_{int(time.time())}.txt")

    print(f"Creating {filename}")
    with open(filename, "w") as f:
        f.write(f"[CREATE] File created at {datetime.now()}\n")

    time.sleep(2)
    print(f"Editing {filename}")
    with open(filename, "a") as f:
        f.write(f"[EDIT] File edited at {datetime.now()}\n")

    time.sleep(2)
    print(f"Deleting {filename}")
    try:
        os.remove(filename)
    except FileNotFoundError:
        pass

    time.sleep(2)
