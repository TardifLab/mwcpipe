#!/bin/bash
#
# Quick function to QC func OR t1w brain masks
#
# Inputs:
# 	$1	: subject ID (01..30)
# 	$2 	: Session number (1 or 2)
# 	$3 	: Space (func, t1w)
#
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# Settings & inputs
  rootdir=/data_/tardiflab/mwc/bids/derivatives/micapipe
  SUB="sub-$1"
  SES="ses-$2"
#  SPACE="$3"

if [ "$3" == func ] ; then

  # Functional data files
    subdir=${rootdir}/${SUB}/${SES}/func/desc-se_task-rest_dir-AP_bold/volumetric
    mask=${subdir}/${SUB}_${SES}_space-func_desc-se_brain_mask.nii.gz
    image=${subdir}/${SUB}_${SES}_space-func_desc-se_mean.nii.gz

elif [ "$3" == t1w ] ; then

  # T1w data files
    subdir=${rootdir}/${SUB}/${SES}/anat
    mask=${subdir}/${SUB}_${SES}_space-nativepro_t1w_brain_mask.nii.gz
    image=${subdir}/${SUB}_${SES}_space-nativepro_t1w.nii.gz

fi

# QC that mofo
  mrview $image -overlay.load $mask -overlay.opacity .35 -overlay.colourmap 1 -colourmap 2 -fullscreen -mode 2
