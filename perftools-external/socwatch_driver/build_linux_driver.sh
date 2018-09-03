#!/bin/sh

# Description: Script to build the SOCWatch driver
# Version: 1.0

# **********************************************************************************
#  This file is provided under a dual BSD/GPLv2 license.  When using or
#  redistributing this file, you may do so under either license.

#  GPL LICENSE SUMMARY

#  Copyright(c) 2017 Intel Corporation.

#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License as
#  published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.

#  Contact Information:
#  SoC Watch Developer Team <socwatchdevelopers@intel.com>
#  Intel Corporation,
#  1906 Fox Drive,
#  Champaign, IL 61820

#  BSD LICENSE

#  Copyright(c) 2017 Intel Corporation.

#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:

#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in
#      the documentation and/or other materials provided with the
#      distribution.
#    * Neither the name of Intel Corporation nor the names of its
#      contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.

#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# **********************************************************************************


MAKE="make"
MAKEFILE_NAME="Makefile"

KERNEL_BUILD_DIR=""
DEFAULT_KERNEL_BUILD_DIR="/lib/modules/`uname -r`/build"

DO_CLEAN=0;
DO_LINUX=0;
DO_SOC=0;
DO_SOCPERF="1";
DO_INTEL_INTERNAL=0;
DO_DEBUG_BUILD=0;
DEFAULT_FILE_NAME="sw_driver";
FILE_NAME=${DEFAULT_FILE_NAME};
DO_PROFILING=0;
COMMON_INC_DIR="";
DEFAULT_INC_DIR="${PWD}/../common/include"
DEFAULT_C_COMPILER=gcc

usage()
{
    echo "Usage: sh ./build_driver <options>";
    echo "Where options are:";
    echo -e "\t-k, --kernel-build-dir [dir-name]: specify the kernel build directory (defaults to $DEFAULT_KERNEL_BUILD_DIR if not specified)."
    echo -e "\t-h, --help: print this usage message";
    echo -e "\t-c, --c-compiler [Path to c compiler]: Specify an alternate compiler; default is $DEFAULT_C_COMPILER"
    echo -e "\t    --make-args: extra arguments to pass to make command"
    echo -e "\t-l, --linux: compile the driver for a device running Linux.";
    echo -e "\t-d, --debug: do a debug build, with \"-Werror\" turned ON";
    echo -e "\t-n, --no-socperf: remove socperf support from the driver. Use this option only if you're sure you won't collect bandwidth or DRAM Self Refresh metrics";
    echo -e "\t-s, --symvers [path to Module.symvers file]: specify a \"Module.symvers\" file to extract symbols from; MUST be FULL PATH!";
    echo -e "\t    --clean: Run a make clean"
    return 0;
}

while [ $# -gt 0 ] ; do
    case "$1" in
        -h | --help)
            usage; exit 0;;
        -k | --kernel-build-dir)
            KERNEL_BUILD_DIR=$2; shift;;
        -l | --linux)
            DO_LINUX=1;;
        -i | --internal)
            DO_INTEL_INTERNAL=1;;
        -d | --debug)
            DO_DEBUG_BUILD=1;;
        -n | --no-socperf)
            DO_SOCPERF="0";;
        -s | --symvers)
            MODULE_SYMVERS_FILE=$2; shift;;
        -c | --c-compiler)
            C_COMPILER=$2; shift;;
        --make-args)
            MAKE_ARGS=$2; shift;;
        --clean)
            DO_CLEAN=1;;
        -f | --file-name) # hidden option
            FILE_NAME=$2; shift;;
        -p | --profile) # hidden option
            DO_PROFILING=1;;
        --common-inc-dir) # hidden option
            COMMON_INC_DIR=$2; shift;;
        *) usage; exit 255;;
    esac
    shift
done

if [ "X$C_COMPILER" = "X" ]; then
    C_COMPILER=$DEFAULT_C_COMPILER;
else
    # User specified a compiler to use. Check validity:
    # 1. File should exist
    # 2. File should be executable
    C_COMPILER_FULL=`which $C_COMPILER`
    if [ ! -f "$C_COMPILER_FULL" ]; then
        echo "Invalid c-compiler specified: ${C_COMPILER} is not a valid path!";
        exit 255;
    fi
    # OK, file exists, but is it an executable?
    if [ ! -x "$C_COMPILER_FULL" ]; then
        echo "Invalid c-compiler specified: ${C_COMPILER} is not executable!";
        exit 255;
    fi
fi
export CC=${C_COMPILER}
echo "Using C compiler = ${CC}";

if [ "X$KERNEL_BUILD_DIR" = "X" ]; then
    KERNEL_BUILD_DIR=$DEFAULT_KERNEL_BUILD_DIR;
fi

echo "Using kernel build dir = $KERNEL_BUILD_DIR"

if [ "X$MODULE_SYMVERS_FILE" = "X" ] ; then
    echo "No module symvers file found";
else
    echo "Using symvers file = $MODULE_SYMVERS_FILE"
fi

echo "Using common_inc_dir=${COMMON_INC_DIR}s"

if [ "X$COMMON_INC_DIR" = "X" ]; then
    COMMON_INC_DIR="$DEFAULT_INC_DIR"
fi

echo "Using common inc dir = $COMMON_INC_DIR"

APWR_RED_HAT="0"

# check which distro
# taken from the 'boot-script'
if [ -e "/etc/issue" ]; then
    is_redhat=`cat /etc/issue | grep -i "red hat"`;
    if [ "$is_redhat" != "" ]; then
		APWR_RED_HAT=1
		echo "Using RedHat-specific hack for kernel version number..."
    fi
fi

WAKELOCK_SAMPLE="0"
wakelock_file=${KERNEL_BUILD_DIR}/source/include/trace/events/wakelock.h
if [ -f $wakelock_file ] ; then
  echo "\"$wakelock_file\" exists!"
  WAKELOCK_SAMPLE=1
else
  echo "\"$wakelock_file\" does NOT exist!"
  pm_wakeup_file=${KERNEL_BUILD_DIR}/source/include/linux/pm_wakeup.h
  if [ -f $pm_wakeup_file ] ; then
    echo "\"$pm_wakeup_file\" exists!"
    WAKELOCK_SAMPLE=1
  else
    echo "\"$pm_wakeup_file\" does NOT exist!"
  fi
fi

DO_ANDROID="1"
if [ $DO_LINUX -eq 1 ]; then
    DO_ANDROID="0"
fi

#DO_SOCPERF="0"

PW_DO_DEBUG_BUILD="0"
if [ $DO_DEBUG_BUILD -eq 1 ]; then
    PW_DO_DEBUG_BUILD="1"
fi

echo "Using file name ${FILE_NAME}"

MAKE_ARGS="KERNEL_SRC_DIR=$KERNEL_BUILD_DIR APWR_RED_HAT=$APWR_RED_HAT WAKELOCK_SAMPLE=$WAKELOCK_SAMPLE DO_ANDROID=$DO_ANDROID DO_SOCPERF=$DO_SOCPERF DO_INTEL_INTERNAL=$DO_INTEL_INTERNAL DO_DEBUG_BUILD=$PW_DO_DEBUG_BUILD DO_PROFILING=$DO_PROFILING COMMON_INC_DIR=$COMMON_INC_DIR MODULE_SYMVERS_FILE=$MODULE_SYMVERS_FILE FILE_NAME=${FILE_NAME} $MAKE_ARGS"
echo "Make args = $MAKE_ARGS"
if [ $DO_CLEAN -eq 1 ]; then
    ${MAKE} -f ${MAKEFILE_NAME} $MAKE_ARGS clean
else
    ${MAKE} CC=$CC -f ${MAKEFILE_NAME} $MAKE_ARGS clean default
fi

