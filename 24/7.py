#!/usr/bin/env python3
import os
import time
from datetime import datetime

DIR = "./loop_test"
os.makedirs(DIR, exist_ok=True)

print(f"🔄 Starting 24/7 file loop in {DIR}...")

while True:
    filename = os.path.join(DIR, f"file_{int(time.time())}.txt")

    # Create
    print(f"Creating {filename}")
    with open(filename, "w") as f:
        f.write(f"This is a test file created at {datetime.now()}\n")

    # Edit after 2s
    time.sleep(2)
    print(f"Editing {filename}")
    with open(filename, "a") as f:
        f.write(f"Edited at {datetime.now()}\n")

    # Delete after 2s
    time.sleep(2)
    print(f"Deleting {filename}")
    try:
        os.remove(filename)
    except FileNotFoundError:
        pass

    # Wait 2s before next cycle
    time.sleep(2)
