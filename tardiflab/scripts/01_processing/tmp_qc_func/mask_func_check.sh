#!/bin/bash
#
# Quick function to QC func masks
#
# Inputs:
# 	$1	: subject ID (01..30)
# 	$2 	: Session number (1 or 2)
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# Settings & inputs
  rootdir=/data_/tardiflab/mwc/bids/derivatives/micapipe
  SUB="sub-$1"
  SES="ses-$2"
  subdir=${rootdir}/${SUB}/${SES}/func/desc-se_task-rest_dir-AP_bold/volumetric

# Files
  mask=${subdir}/${SUB}_${SES}_space-func_desc-se_brain_mask.nii.gz
  func=${subdir}/${SUB}_${SES}_space-func_desc-se.nii.gz

# QC that mofo
  mrview $func -overlay.load $mask -overlay.opacity .3 -overlay.colourmap 1 -colourmap 7 -fullscreen -mode 2
