#!/bin/bash
# Custom Git merge driver that always keeps "ours" version
# This is used for auto-generated index.md files to prevent merge conflicts
#
# Arguments: %O %A %B %L %P
#   %O = ancestor's version
#   %A = current version (ours)
#   %B = other branch's version (theirs)
#   %L = conflict marker size
#   %P = file path
#
# Exit code 0 = success, non-zero = failure

# Always use the current version (ours) - just copy %A to the final location
# The file at %A is already in place, so we just need to exit successfully
exit 0
