#!/bin/bash

set -ex

sudo sed -i 's/Werror/Wno-address -Wno-stringop-truncation/' configure.ac

