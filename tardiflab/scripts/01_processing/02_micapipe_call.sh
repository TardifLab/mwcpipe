#!/bin/bash
# called by main routing function (see 01_qbatch_subcall.sh)
# Calls individual functions in micapipe ($MICAPIPE/functions)
#
# Inputs:
# 	$1 : subject tag {01, 02, ..., 30}
# 	$2 : FUNC_ID indicating which function from micapipe to call
# 	$3 : Session #
#
# NOTES:
# 	1. nocleanup flag may not be desireable in some cases
# 	2. 01_proc-struc_freesurfer.sh  was not run, as this processing was done manually
# 	3. Modify input to -sub tag to fit your need
#
# 2021 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# initialize necessary paths & dependencies
source /data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh

#options
SESSION="ses-$3"

# Script call
if [ "$2" == volumetric ] ; then
      # volumetric structural processing
	${MICAPIPE}/micapipe \
              	-sub $1 \
              	-out $OUT_DIR \
              	-bids $RAW_DIR \
              	-ses $SESSION \
              	-proc_structural

elif [ "$2" == post_structural ] ; then
      # POST-structural processing
  	${MICAPIPE}/micapipe \
        	-sub $1 \
              	-out $OUT_DIR \
              	-bids $RAW_DIR \
              	-ses $SESSION \
              	-post_structural

elif [ "$2" == dwi ] ; then
      # DWI processing
   	${MICAPIPE}/micapipe \
              	-sub $1 \
              	-out $OUT_DIR \
              	-bids $RAW_DIR \
              	-ses $SESSION \
		-nocleanup \
              	-proc_dwi

elif [ "$2" == SC ] ; then
      # SC processing
   	${MICAPIPE}/micapipe \
              	-sub $1 \
              	-out $OUT_DIR \
              	-bids $RAW_DIR \
              	-ses $SESSION \
		-tracts 5M \
              	-nocleanup \
              	-SC

elif [ "$2" == FC ] ; then
      # resting state fMRI & FC processing
        ${MICAPIPE}/micapipe \
                -sub $1 \
                -out $OUT_DIR \
                -bids $RAW_DIR \
                -ses $SESSION \
		-nocleanup \
		-NSR \
		-dropTR \
                -proc_func
fi
