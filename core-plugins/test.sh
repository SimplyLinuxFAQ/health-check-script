#!/bin/bash
# --------- required start--------#
function usage() {
    echo "----------"
    echo "Test usage"
    echo "----------"
    echo "Just a test usage concept! See test.sh in core-plugins for example!"        
}
if test "${HC_USAGE+x}"; then
    usage
    exit
fi
# --------- required end--------#

echo ===========
echo Test plugin
echo ===========
echo $0

if test "${HC_VERBOSE+x}"; then
  echo "VERBOSE is set, probably passed with -v"
else
  echo "VERBOSE not set, set it with -v"
fi

if test "${HC_USR_SBIN_PATH+x}"; then
  echo "HC_USR_SBIN_PATH is set to $HC_USR_SBIN_PATH, probably passed with -b"
else
  echo "HC_USR_SBIN_PATH not set, set it with -b"
fi

if [ "$HC_VERBOSE" == "y" ]; then
  echo "COLOR is set, default"
else
  echo "COLOR is not set, probably -e or -c passed"
fi
