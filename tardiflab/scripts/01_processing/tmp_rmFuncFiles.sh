#!/bin/bash
#
# Removes processed func files from subs with poor registration
#
#
# INPUTS:
#       $1 : subject directory
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# Settings
  ID=$1
  SES=$2

  subdir="/data_/tardiflab/mwc/bids/derivatives/micapipe/sub-${ID}/ses-${SES}"

  echo "Removing func files for sub-${ID}_ses-${SES}"

  rm ${subdir}/xfm/*_from-se_task-rest_dir-AP_bold_to-nativepro_mode-image_desc-SyN_*

  tmpdir="${subdir}/func/desc-se_task-rest_dir-AP_bold/surfaces"
  rm ${tmpdir}/*_func_space-fsnative_atlas*  ${tmpdir}/*_func_space-conte69-32k_atlas*  ${tmpdir}/*_func_space-conte69-32k_desc-timeseries_clean.txt

  tmpdir="${subdir}/func/desc-se_task-rest_dir-AP_bold/volumetric"
  rm ${tmpdir}/*tSNR.txt  ${tmpdir}/*framewiseDisplacement.png  ${tmpdir}/*cerebellum*  ${tmpdir}/*timeseries*  ${tmpdir}/*subcortical.nii.gz  ${tmpdir}/*global.txt  ${tmpdir}/*pve*  ${tmpdir}/*t1w*

  rm ${subdir}/anat/*se_task-rest_dir-AP_bold_mean*

  tmpdir="/data_/tardiflab/mwc/bids/derivatives/micapipe/tmp_micapipe/02_proc-func/sub-${ID}/ses-${SES}/"
  mv "${tmpdir}/sub-${ID}_ses-${SES}_log_syn.txt"  "${tmpdir}/${RANDOM}_sub-${ID}_ses-${SES}_log_syn.txt"

