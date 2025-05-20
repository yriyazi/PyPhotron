import time
import setproctitle

def main():
    setproctitle.setproctitle("my_python_worker")
    while True:
        print("Running function...")
        time.sleep(5)

if __name__ == "__main__":
    main()

# This script runs indefinitely, printing "Running function..." every 5 seconds.
# To stop the script, you can use Ctrl+C in the terminal.