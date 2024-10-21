#!/usr/bin/env python3

import os

from pathlib import Path
from subprocess import run

# copy patches
pkg_dir = Path('vyos-build/packages')
current_dir: str = Path.cwd().as_posix()
if pkg_dir.exists():
    pkg_list = list(pkg_dir.iterdir())
    pkg_list.sort()
    for pkg_file in pkg_list:
        if Path(pkg_file.name).suffix == '.deb':
            print(f'Adding package to psleng repository: {pkg_file.name}')
            pkg_cmd: list[str] = ['reprepro', '-b', 'psleng.github.io', 'includedeb', 'bookworm', pkg_dir/pkg_file.name]
            print(f'Command: {pkg_cmd}')
            pkg_status: int = run(pkg_cmd).returncode
            if pkg_status:
                print(f'Error adding package to psleng repository: {pkg_file.name} !!!')
                exit(1)
exit()
