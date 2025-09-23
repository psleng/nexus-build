#!/usr/bin/python3
import time
from pathlib import Path
import sys
from subprocess import run


def main(img: str, dockerfile: str, entrypoint: str) -> int:
    '''
    Compare docker image "img" to dockerfile and entrypoint.
    Returns 0 if the image is newer than both, else 1.
    '''
    time.tzset()

    # Get timestamp of the docker image
    r = run(['docker', 'image', 'ls', '--format', '{{json .CreatedAt}}', img],
            capture_output=True, check=True)
    imgdate = r.stdout.decode().strip().replace('"', '')
    if not imgdate:
        # Apparently does not exist
        print(img, 'not found')
        img_mtime = 0.0
    else:
        imgst = time.strptime(imgdate, '%Y-%m-%d %H:%M:%S %z %Z')
        img_mtime = time.mktime(imgst)

    # Check paths up to date compared to image
    ret = 0
    needs = "does NOT need"
    for f in (dockerfile, entrypoint):
        # Get timestamp
        if (img_mtime - Path(f).stat().st_mtime) <= 0:
            print(f'{f} is newer than docker image')
            needs = "DOES need"
            ret = 1

    print(f'docker image {needs} to be rebuilt')

    return ret


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f'Usage: {sys.argv[0]} imgname Dockerfile entrypoint.sh',
              file=sys.stderr)
        exit(1)

    exit(main(sys.argv[1], sys.argv[2], sys.argv[3]))
