#!/bin/bash

set -x
set -e

# Check if the --repo parameter is provided
if [ "$#" -lt 2 ] || [ "$1" != "--repo" ]; then
    echo "Usage: $0 --repo <repository_url> [--clean]"
    exit 1
fi

REPPREFIX_URL="$2/"
REPO_NAME="psleng.github.io"
REPO_URL="$2/$REPO_NAME"
ROOTDIR=$(pwd)

REPO_NO_DIFF=_REPO_NOT_UPDATED
REPO_DIFF=_REPO_UPDATED
REPO_DIFF_FAILED=_REPO_UPDATE_FAILED

rm "$REPO_NO_DIFF"|true       # apt repo has not been updated
rm "$REPO_DIFF"|true          # apt repo has been updated
rm "$REPO_DIFF_FAILED"|true   # apt repo update has failed

# Check if the --clean parameter is provided
CLEAN=false
if [ "$#" -eq 3 ] && [ "$3" == "--clean" ]; then
    CLEAN=true
fi

# Delete the repository if it already exists and --clean is specified
if [ -d "$REPO_NAME" ]; then
    if [ "$CLEAN" = true ]; then
        echo "Cleaning up existing repository $REPO_NAME."
        rm -rf "$REPO_NAME"
    else
        echo "Repository $REPO_NAME already exists. Skipping clone."
    fi
fi

# Clone the repository if it doesn't exist or was cleaned, and remove the existing repo binaries for adding new ones
if [ ! -d "$REPO_NAME" ]; then
    git clone "$REPO_URL"
fi

# Directories to compare
dir1="$ROOTDIR/vyos-build/packages"
dir2="$ROOTDIR/psleng.github.io/pool/main"
# archname=`dpkg-architecture -qDEB_HOST_ARCH`

# Variable to track if a difference is found
files_differ=false

echo $dir1
echo $dir2

# Loop thru each .deb file in directory
for file1 in $(find $dir1 -name "*.deb"); do
    # Check if it's a regular file (skip directories)
    if [[ "$file1" ]]; then
        # Extract filename from the full path
        filename=$(basename "$file1")
        # Extract deb package name from the file
        pkgname=`dpkg-deb -f $file1 Package`
        echo source file: $file1
        archname=`dpkg-deb -I $file1 | grep "Architecture:" | awk '{print $2}'`
        echo architecture: $archname
        # Search for the file in dir2 and its subdirectories
        found=false
        for file2 in $(find "$dir2" -name "$filename"); do
            # Compare the files
            if ! ./debcmp "$file1" "$file2"; then
                # If the files differ, set the flag to true and stop further searching
                files_differ=true
                echo "Files $file1 and $file2 differ"
                echo "Removing package: $file1 from apt repo $REPO_NAME"
                if [ "$archname" = "all" ]; then
                    reprepro -b $REPO_NAME remove current $pkgname
                else
                    reprepro -A $archname -b $REPO_NAME remove current $pkgname
                fi
                echo "Adding package: $file1 to apt repo $REPO_NAME"
                reprepro -b $REPO_NAME includedeb current $file1
            fi
            found=true
        done

        # If the file from dir1 is not found in dir2, we can skip comparison
        if ! $found; then
            echo "File $filename not found in $dir2... "
            echo "Adding package: $file1 to apt repo $REPO_NAME"
            reprepro -b $REPO_NAME includedeb current $file1
	    files_differ=true
        fi
    fi
done

# Output the result
if $files_differ; then
    echo "Files differ. Local iGOS apt repository $REPO_NAME was updated."
else
    echo "No differences found. $REPO_NAME repository was not updated"
    touch "$REPO_NO_DIFF"       # apt repo has not been updated
    exit 0
fi

# usage of psleng.github.io may change to a jfrog account in which the git commands below need to be removed
# create a temp dir to hold the local repo changes/updates, reset the locla repo to just bare config, then
# copy back the updates, git add, git commit, git push --force the repo to the remote repo
rm -rf _psleng.github.io|true
mkdir _psleng.github.io
cd psleng.github.io
cp -rf db ../_psleng.github.io
cp -rf dists ../_psleng.github.io
cp -rf pool ../_psleng.github.io
git reset --hard base
rm -rf db dists pool
cp -rf ../_psleng.github.io/db .
cp -rf ../_psleng.github.io/dists .
cp -rf ../_psleng.github.io/pool .
git add .
git commit -a -m "Updating the Perle iGOS debian binary packages"
git push --force
cd -

touch "$REPO_DIFF"          # apt repo has been updated
