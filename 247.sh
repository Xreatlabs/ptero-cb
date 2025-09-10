#!/usr/bin/env python3
"""
XreatLabs 24/7 File Loop Script
Author: Ahmadisog
Purpose: Continuously create → edit → delete files in a loop
"""

import os
import time
from datetime import datetime

# Directory where the files will be created
DIR = "./xreatlabs_loop"
os.makedirs(DIR, exist_ok=True)

print(f"🔄 Starting 24/7 file loop in {DIR}...")

while True:
    # Create a unique filename based on timestamp
    filename = os.path.join(DIR, f"xreat_file_{int(time.time())}.txt")

    # 1️⃣ Create file
    print(f"Creating {filename}")
    with open(filename, "w") as f:
        f.write(f"[CREATE] File created at {datetime.now()}\n")

    # 2️⃣ Edit file after 2 seconds
    time.sleep(2)
    print(f"Editing {filename}")
    with open(filename, "a") as f:
        f.write(f"[EDIT] File edited at {datetime.now()}\n")

    # 3️⃣ Delete file after 2 seconds
    time.sleep(2)
    print(f"Deleting {filename}")
    try:
        os.remove(filename)
    except FileNotFoundError:
        pass

    # Wait 2 seconds before next cycle
    time.sleep(2)
