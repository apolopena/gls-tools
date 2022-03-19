#!/bin/bash

name1=${BASH_SOURCE[0]}
name2=$(readlink /proc/$$/fd/255)
echo "name1=$name1"
echo "name1b=$(basename "$name1")"
echo "name2=$name2"
echo "name2b=$(basename "$name2")"
