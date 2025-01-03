#!/bin/bash

#set -x
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
        echo source file: $file1
        # Search for the file in dir2 and its subdirectories
        found=false
        for file2 in $(find "$dir2" -name "$filename"); do
            # Compare the files
            if ! cmp -s "$file1" "$file2"; then
                # If the files differ, set the flag to true and stop further searching
                files_differ=true
                echo "Files $file1 and $file2 differ"
                break 2  # Break out of both loops
            fi
            found=true
        done

        # If the file from dir1 is not found in dir2, we can skip comparison
        if ! $found; then
            echo "File $filename not found in $dir2.  Mark as a difference to update the repository."
	    files_differ=true
        fi
    fi
done

# Output the result
if $files_differ; then
    echo "Files differ."
else
    echo "No differences found. Skip updating apt repository"
    touch "$REPO_NO_DIFF"       # apt repo has not been updated
    exit 0
fi

# usage of psleng.github.io may change to a jfrog account in which the git commands below need to be removed
cd psleng.github.io
git reset --hard base
cd -

echo "Removing current binary deb packages from local repository..."
rm -rf $REPO_NAME/db; rm -rf $REPO_NAME/dists; rm -rf $REPO_NAME/pool

# not needed because another script already moved to vyos-build/packages: copy everything to the package directory
#for a in $(find $ROOTDIR/vyos-build/scripts -type f -name "*.deb" | grep -v -e "-dbgsym_" -e "libnetfilter-conntrack3-dbg"); do
#    sudo cp -f $a $ROOTDIR/vyos-build/packages/
#done

# copy everything to the package directory
for b in $(find $ROOTDIR/vyos-build/packages -name "*.deb"); do
    echo "Adding package: $b to apt repo $REPO_NAME"
    echo "RenfrewDrive@60" | reprepro -b $REPO_NAME includedeb current $b
done

# usage of psleng.github.io may change to a jfrog account in which the git commands below need to be replacced with jfrog curl commands
cd psleng.github.io
git add .
git commit -a -m "Updating the Perle iGOS debian binary packages"
git push --force
cd -

touch "$REPO_DIFF"          # apt repo has been updated
