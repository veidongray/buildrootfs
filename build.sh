#!/bin/bash
#
# This script can build U-Boot, the Kernle, the RootFS, or all of above.

function main()
{
	case "$1" in
		"-U" | "-u")
			echo "Building U-Boot..."
			;;
		"-K" | "-k")
			echo "Building Kernel..."
			;;
		"-R" | "-r")
			echo "Building RootFS..."
			;;
		*)
			echo "Usage: $0 -U|-K|-R"
			;;
	esac
}

main $1
