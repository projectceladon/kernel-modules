#!/bin/sh
# ##################################################################################
# Copyright 2014 - 2017 Intel Corporation

# The source code contained or described herein and all documents related
# to the source code ("Material") are owned by Intel Corporation or its
# suppliers or licensors. Title to the Material remains with Intel Corporation
# or its suppliers and licensors. The Material contains trade secrets and
# proprietary and confidential information of Intel or its suppliers and
# licensors. The Material is protected by worldwide copyright and trade secret
# laws and treaty provisions. No part of the Material may be used, copied,
# reproduced, modified, published, uploaded, posted, transmitted, distributed,
# or disclosed in any way without Intel's prior express written permission.

# No license under any patent, copyright, trade secret or other intellectual
# property right is granted to or conferred upon you by disclosure or delivery
# of the Materials, either expressly, by implication, inducement, estoppel or
# otherwise. Any license under such intellectual property rights must be express
# and approved by Intel in writing.
# #################################################################################

# Remove driver debug sections. Execute this script if
# "insmod" fails with the following error:
# "ERROR: could not insert module socwatch2_4.ko: Cannot allocate memory"

DRIVER_MAJOR=2
DRIVER_MINOR=4
DRIVER_NAME=socwatch
FULL_NAME="${DRIVER_NAME}${DRIVER_MAJOR}_${DRIVER_MINOR}.ko"
STRIPPED_NAME="tmp"

INPUT_FILE_NAME=${FULL_NAME}
OUTPUT_FILE_NAME=${FULL_NAME}

usage()
{
    echo "Usage: ./strip_debug_sections.sh [ -i path to input file ] [ -o path to output file ]"
    echo "Where input and output paths are optional and default to $INPUT_FILE_NAME and $OUTPUT_FILE_NAME, respectively";
}

get_args()
{
    while [ $# -gt 0 ]; do
        case $1 in
            -h)
                usage;
                exit 0;;
            -i)
                INPUT_FILE_NAME=$2;
                shift;;
            -o)
                OUTPUT_FILE_NAME=$2;
                shift;;
            *) usage; exit 255;;
        esac
        shift;
    done
}

run()
{
    echo "Input file name is ${INPUT_FILE_NAME}";
    echo "Output file name is ${OUTPUT_FILE_NAME}";
    objcopy -R .debug_aranges \
        -R .debug_info \
        -R .debug_abbrev \
        -R .debug_line \
        -R .debug_frame \
        -R .debug_str \
        -R .debug_loc \
        -R .debug_ranges \
        ${INPUT_FILE_NAME} ${STRIPPED_NAME}

    if [ $? -ne 0 ]; then
        echo "Failed";
    else
        mv ${STRIPPED_NAME} ${OUTPUT_FILE_NAME}
    fi
}

get_args $*
run
