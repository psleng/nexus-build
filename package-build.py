#!/usr/bin/env python3

import os
import subprocess
import argparse
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Set up argument parser
parser = argparse.ArgumentParser(description='Run build.py in subdirectories, with options to exclude or include specific directories.')
parser.add_argument('--exclude', nargs='*', default=[], help='List of directories to exclude')
parser.add_argument('--include', nargs='*', default=[], help='List of directories to only include')
parser.add_argument('--dir', required=True, help='Directory name "foo" in vyos-build/scripts/foo')
args = parser.parse_args()

# Change directory to the specified directory
try:
    os.chdir(f'vyos-build/scripts/{args.dir}')
except FileNotFoundError:
    logging.error(f"Directory 'vyos-build/scripts/{args.dir}' not found.")
    exit(1)

# Get the current working directory
current_dir = os.getcwd()

# List all items in the current directory and sort them alphabetically
items = sorted(os.listdir(current_dir))

# Combine exclude lists
exclude_list = set(args.exclude)

# Determine directories to process
if args.include:
    directories_to_process = set(args.include)
else:
    directories_to_process = {item for item in items if os.path.isdir(os.path.join(current_dir, item)) and item not in exclude_list}

for item in directories_to_process:
    item_path = os.path.join(current_dir, item)
    
    # Check if the item is a directory
    if os.path.isdir(item_path):
        # Change to the subdirectory
        os.chdir(item_path)
        
        # Construct the path to build.py
        build_script = os.path.join(item_path, 'build.py')
        
        # Check if build.py exists in the directory
        if os.path.isfile(build_script):
            # Run build.py and handle errors
            logging.info(f"Running build.py in {item_path}")
            try:
                subprocess.run(['python3', build_script], check=True)
                logging.info(f"Successfully ran build.py in {item_path}")
            except subprocess.CalledProcessError as e:
                logging.error(f"Error running build.py in {item_path}: {e}")
                exit(2)
        else:
            logging.warning(f"No build.py found in {item_path}")
        
        # Change back to the original directory
        os.chdir(current_dir)

