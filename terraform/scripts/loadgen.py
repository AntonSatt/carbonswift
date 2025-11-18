#!/usr/bin/env python3
import os
import time
import math
import random
import subprocess
import logging
import datetime

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("loadgen")

ROLE = os.environ.get("INSTANCE_ROLE", "unknown")
ENABLED = os.environ.get("ENABLE_DYNAMIC_LOAD", "true").lower() == "true"

def target_load(role):
    now = datetime.datetime.utcnow()
    minute_of_day = (now.hour * 60) + now.minute
    hour = now.hour
    
    base = 32.5 + 27.5 * math.sin(2 * math.pi * minute_of_day / 1440)
    noise = random.gauss(0, 6)
    target = base + noise
    
    if "api" in role.lower():
        if 8 <= hour <= 20:
            target += 5
        else:
            target -= 2
        target = max(7, min(45, target))
    elif "web" in role.lower():
        if 9 <= hour <= 22:
            target += 10
        else:
            target -= 5
        target = max(10, min(60, target))
    elif "compute" in role.lower():
        if hour >= 21 or hour <= 2:
            target += 15
        else:
            target -= 10
        target = max(10, min(85, target))
    
    if random.random() < 0.15:
        burst = random.uniform(10, 25)
        target = min(95, target + burst)
        logger.info(f"BURST: +{burst:.1f}% for {ROLE}")
    
    return float(max(5, min(95, target)))

def run_cycle():
    load = round(target_load(ROLE), 1)
    logger.info(f"[{ROLE}] Target load: {load}% for 60s")
    
    p = subprocess.Popen([
        "/usr/bin/stress-ng",
        "--cpu", "0",
        "--cpu-load", str(load),
        "--timeout", "60s",
        "--metrics-brief"
    ])
    
    try:
        p.wait(timeout=75)
    except subprocess.TimeoutExpired:
        logger.warning("stress-ng timeout, terminating")
        p.terminate()
        p.wait()

if __name__ == "__main__":
    if not ENABLED:
        logger.info(f"Dynamic load disabled for {ROLE}. Exiting.")
        exit(0)
    
    logger.info(f"Starting dynamic workload simulator for {ROLE}")
    while True:
        run_cycle()
