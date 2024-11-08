#!/usr/bin/env python3

import sys
import os
import subprocess
import argparse
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, stream=sys.stdout,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# Set up argument parser
parser = argparse.ArgumentParser(description='Run build.py in subdirectories,'
    ' with options to exclude or include specific directories. If --include'
    ' not used, all directories in DIR are processed alphabetically.')
parser.add_argument('--exclude', nargs='*', default=[],
                    help='List of directories to exclude')
parser.add_argument('--include', nargs='*', default=[],
                    help='List of directories to only include (in order)')
parser.add_argument('--dir', required=True,
                    help='Directory name "foo" in vyos-build/scripts/foo')
args = parser.parse_args()

# Change directory to the specified directory
rootdir = os.getcwd()
try:
    os.chdir(f'vyos-build/scripts/{args.dir}')
except FileNotFoundError:
    logging.error(f"Directory 'vyos-build/scripts/{args.dir}' not found.")
    exit(1)

# Get the current working directory
basedir = os.getcwd()

# Determine directories to process
if args.include:
    # Only these (in listed order)
    directories_to_process = list(dict.fromkeys(args.include))
else:
    # Use all items in the current directory, alphabetically
    directories_to_process = sorted(os.listdir(basedir))

# Process
for item in directories_to_process:
    if item in args.exclude:
        logging.info(f"Skipping {item} because of --exclude")
        continue

    os.chdir(basedir)
    item_path = os.path.join(basedir, item)
    if not os.path.isdir(item_path):
        logging.warning(f"Skipping {item} because {item_path} missing")
        # It might be that is was added to git recently but the source
        # directory has not been copied by build_iGOS_TMDS64EVM_fs.sh
        # TODO: that copy/toml rewrite should probably be moved to here.
        # For now we will print a warning.
        igosdir = os.path.join(rootdir, 'package-build-iGOS', item)
        if os.access(igosdir, os.F_OK):
            logging.warning(igosdir + ' source directory exists though;'
                            ' try copying from there.')
        continue

    # Change to the subdirectory
    os.chdir(item_path)

    # Construct the path to build.py
    buildpy = 'build.py'
    build_script = os.path.join(item_path, buildpy)

    # Run build.py if it exists
    if os.path.isfile(build_script):
        # Run build.py and handle errors
        logging.info(f"Running {buildpy} in {item_path}")
        try:
            subprocess.run(f'python3 {build_script} 2>&1',
                           check=True, shell=True)
            logging.info(f"Successfully ran {buildpy} in {item_path}")
        except subprocess.CalledProcessError as e:
            logging.error(f"Error running {buildpy} in {item_path}: {e}")
            exit(2)
    else:
        logging.warning(f"No {buildpy} found in {item_path}; skipping")
