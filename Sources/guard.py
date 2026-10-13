#!/usr/bin/python3
"""Open Deskflow disconnected at login; stop its client after connection failure."""
import configparser
import os
from pathlib import Path
import re
import signal
import subprocess
import time

CONFIG = Path.home() / 'Library/Deskflow/Deskflow.conf'
CORE = '/Applications/Deskflow.app/Contents/MacOS/deskflow-core'

def disconnected_start():
    text = CONFIG.read_text()
    text = re.sub(r'^startCoreWithGui=.*$', 'startCoreWithGui=false', text, flags=re.M)
    CONFIG.write_text(text)

def stop_client():
    result = subprocess.run(['/bin/ps', '-axww', '-o', 'pid=,args='], capture_output=True, text=True, errors='replace')
    if result.returncode:
        return
    for line in result.stdout.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and (fields[1] == CORE + ' client' or fields[1].startswith(CORE + ' client ')):
            try:
                # A normal core exit is automatically restarted by Deskflow's GUI.
                # End only the failed client; the GUI treats a signal exit as stopped.
                os.kill(int(fields[0]), signal.SIGKILL)
                print('Stopped disconnected Deskflow client', flush=True)
            except ProcessLookupError:
                pass

def should_stop(text):
    return any(message in text for message in (
        'failed to connect to server:', 'server is dead', 'disconnected from server'
    ))

def main():
    disconnected_start()
    config = configparser.ConfigParser(interpolation=None)
    config.read(CONFIG)
    log = Path(config.get('log', 'file', fallback=str(Path.home() / 'deskflow.log')))
    if not config.getboolean('log', 'toFile', fallback=False):
        raise RuntimeError('Deskflow file logging must remain enabled for disconnect detection')
    inode = None
    offset = 0
    if log.exists():
        stat = log.stat()
        inode, offset = stat.st_ino, stat.st_size
    subprocess.run(['/usr/bin/open', '-g', '-a', '/Applications/Deskflow.app'], check=True)
    print('Deskflow login guard ready', flush=True)
    while True:
        try:
            stat = log.stat()
            if stat.st_ino != inode or stat.st_size < offset:
                inode, offset = stat.st_ino, 0
            with log.open('rb') as stream:
                stream.seek(offset)
                data = stream.read()
                offset = stream.tell()
            text = data.decode('utf-8', errors='replace')
            if should_stop(text):
                stop_client()
        except FileNotFoundError:
            pass
        time.sleep(0.25)

if __name__ == '__main__':
    main()
