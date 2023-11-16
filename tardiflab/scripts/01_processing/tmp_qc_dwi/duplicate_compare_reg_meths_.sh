#!/bin/bash
#
# Compares methods for T1w to dwi registration using ANTs MeasureImageSimilarity
# Uses Mattes Mutual Information by default (larger negative values means better registration)
# Runs for all subjects and stores values in a .csv of shape subjects x methods
#
# See $ MeasureImageSimilarity --help for more info
#
# Inputs:
# 	$1	: 
# 	$2 	: 
# *** 	$3 	: Similarity metric ("CC", "MI", "Mattes", "MeanSquares", "Demons", "GC", "ICP", "PSE", "JHCT")  *** NOT YET USED
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# Settings & inputs
  rootdir=/data_/tardiflab/mwc/bids/derivatives/micapipe
  testdir=${rootdir}/tmp_micapipe/02_proc-dwi

for ID
  SUB="sub-$1"
  SES="ses-$2"
#  metric=$3

  subdir_orig=${rootdir}/${SUB}/${SES}
  subdir_test=${testdir}/${SUB}/${SES}/tmpregtest

  dwi_b0=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-b0.nii.gz
  dwi_mask=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-brain_mask.nii.gz

## ----------------------------- Compute similarity --------------------------------------- ##

# Original micapipe outputs
  echo "Original outputs MI: "
  t1w_in_dwi=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro.nii.gz
  MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi},1,32,Regular,1] -x [${dwi_mask},${dwi_mask}]  # -v

# Linear AFFINE from improved ANTs method (+ translation step)
  echo "Improved ANTs linear AFFINE MI: "
  t1w_in_dwi=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro.nii.gz
  MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi},1,32,Regular,1] -x [${dwi_mask},${dwi_mask}]  # -v

# Nonlinear WARP from improved ANTs method (+ translation step used in AFFINE part)
  echo "Improved ANTs nonlinear WARP MI: "
  t1w_in_dwi=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro_SyN.nii.gz
  MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi},1,32,Regular,1] -x [${dwi_mask},${dwi_mask}]  # -v

# Linear AFFINE from FSL flirt
  echo "FSL flirt linear AFFINE MI: "
  t1w_in_dwi=${subdir_test}/flirt/dwi/${SUB}_${SES}_t1w_in_dwi.nii.gz
  MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi},1,32,Regular,1] -x [${dwi_mask},${dwi_mask}]  # -v


