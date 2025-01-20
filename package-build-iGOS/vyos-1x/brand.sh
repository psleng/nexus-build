#!/bin/bash

# Define the base filename
base_filename="config.boot.default"

# Define the brand text filename
brand_filename="brand.txt"

# Check if the file exists
if [ -f ../$brand_filename ]; then
  # Read the text string from the file (e.g., base_filename)
  text_string=$(cat ../$brand_filename)

  # Append the text string to the base filename
  new_filename="${base_filename}.${text_string}"

  # Check if the new file already exists
  if [ -f "../$new_filename" ]; then
    echo "Branding default config file exists: $new_filename, rebranding using this file."
    # copy to base file to use
    cp ../$new_filename data/$base_filename
  else
    echo "Branding default config file does not exist: $new_filename, leaving as is"
    exit 1
  fi
else
  echo "Branding text file $brand_filename does not exist. No rebranding done. Default to VyOS branding"
  cp ../$base_filename.vyos data/$base_filename
  exit 1
fi
