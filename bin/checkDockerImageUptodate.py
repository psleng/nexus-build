#!/usr/bin/python3
import time
from pathlib import Path
import sys
from subprocess import run


def main(img: str, dockerfile: str) -> int:
    '''
    Compare docker image "img" to dockerfile "dockerfile".
    Returns 0 if the image is newer than the dockerfile, else 1.
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

    # Get timestamp of the Dockerfile-*
    df_mtime = Path(dockerfile).stat().st_mtime

    # print(time.ctime(img_mtime))
    # print(time.ctime(df_mtime))
    # print(img_mtime - df_mtime)

    if (img_mtime - df_mtime) > 0:
        needs = "does NOT need"
        ret = 0
    else:
        needs = "DOES need"
        ret = 1
    print(f'docker image {needs} to be rebuilt')

    return ret


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage {sys.argv[0]} imgname Dockerfile', file=sys.stderr)
        exit(1)

    exit(main(sys.argv[1], sys.argv[2]))
