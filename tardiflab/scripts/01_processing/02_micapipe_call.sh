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
                -dwi_upscale \
              	-proc_dwi

elif [ "$2" == SC ] ; then
      # SC processing
   	${MICAPIPE}/micapipe \
              	-sub $1 \
              	-out $OUT_DIR \
              	-bids $RAW_DIR \
              	-ses $SESSION \
        		-tracts 3M \
                -filter COMMIT \
                -reg_lambda 15e-1 \
              	-tractometry "${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_MTsat.nii" \
              	-SC

elif [ "$2" == pre_COMMIT ] ; then
      # Setting up for COMMIT processing
   	${MICAPIPE}/micapipe \
              	-sub $1 \
              	-out $OUT_DIR \
              	-bids $RAW_DIR \
              	-ses $SESSION \
              	-MTsat "${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_MTsat.nii" \
              	-MVFalpha_list $MVFlist \
              	-gratio \
              	-gratiotractometry \
              	-pre_COMMIT

elif [ "$2" == proc_COMMIT ] ; then
      # tract-specific MySD/COMMIT/gratio processing
        ${MICAPIPE}/micapipe \
                -sub $1 \
                -out $OUT_DIR \
                -bids $RAW_DIR \
                -ses $SESSION \
                -MTsat "${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_MTsat.nii" \
		        -gratio \
                -gratiotractometry \
		        -MVFalpha_list $MVFlist \
                -tractometry "${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_MTsat.nii ${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_R1map.nii.gz" \
                -tck_imaging \
                -proc_COMMIT

#                -Dual_MTON "/data_/tardiflab/mwc/hc${1}r/Diffusion/preprocessing/dwi_MT_on_dn_dw_db.nii.gz" \
#                -Dual_MTOFF "/data_/tardiflab/mwc/hc${1}r/Diffusion/preprocessing/dwi_MT_off_dn_dw_db.nii.gz" \
#                -Dual_bvals "/data_/tardiflab/mwc/hc${1}r/Diffusion/dwi_preproc.bvals" \
#                -Dual_bvecs "/data_/tardiflab/mwc/hc${1}r/Diffusion/dwi_preproc.bvecs" \

#                -MTsat_DWI "${OUT_DIR}/micapipe/sub-${1}/${SESSION}/dwi/sub-${1}_${SESSION}_space-dwi_desc-MTsat_SyN.nii.gz" \
#		        -gratio \
#                -gratiotractometry \
#		        -MVFalpha_list $MVFlist \
#                -tractometry "${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_MTsat.nii ${OUT_DIR}/matlab/sub-${1}/${SESSION}/anat/sub-${1}_${SESSION}_R1map.nii.gz" \
#                -tck_imaging \

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
		-trainClassifier \
                -proc_func
fi
