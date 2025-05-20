import subprocess
import time
import psutil

SCRIPT_KEYWORD = "sth.py"

def is_worker_running():
    for proc in psutil.process_iter(attrs=['pid', 'name', 'cmdline']):
        try:
            cmdline = proc.info['cmdline']
            if cmdline and any(SCRIPT_KEYWORD in part for part in cmdline):
                return True
        except (psutil.AccessDenied, psutil.ZombieProcess, psutil.NoSuchProcess):
            continue
    return False

while True:
    if not is_worker_running():
        print("Worker not running. Restarting...")
        subprocess.Popen(["python", SCRIPT_KEYWORD], creationflags=subprocess.CREATE_NEW_CONSOLE)
    time.sleep(3)
