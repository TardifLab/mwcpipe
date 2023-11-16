#!/bin/bash
#
# Quick function to QC T1w-dwi registrations
#
# Inputs:
# 	$1	: subject ID (01..30)
# 	$2 	: Session number (1 or 2)
# 	$3 	: Mode ("original"=main pipeline, "ants"=ANTs test, "flirt"=flirt test)
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# Settings & inputs
  rootdir=/data_/tardiflab/mwc/bids/derivatives/micapipe
  testdir=${rootdir}/tmp_micapipe/02_proc-dwi
#  ID=$1
#  NUM=$2
  SUB="sub-$1"
  SES="ses-$2"
  opacity=".3"

  subdir_orig=${rootdir}/${SUB}/${SES}
  subdir_test=${testdir}/${SUB}/${SES}/tmpregtest

  dwi_b0=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-b0.nii.gz;


# Select desired T1w image to QC
  if [ "$3" == original ] ; then

      # T1w registered to dwi space using original ANTs approach in micapipe
   	t1w_in_dwi=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro.nii.gz;

  elif [ "$3" == ants ] ; then

      # T1w registered to dwi space using test ANTs approach
	t1w_in_dwi=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro.nii.gz;

  elif [ "$3" == flirt ] ; then

      # T1w registered to dwi space using test flirt method
	t1w_in_dwi=${subdir_test}/flirt/dwi/${SUB}_${SES}_t1w_in_dwi.nii.gz

  fi

# QC that mofo
  mrview ${t1w_in_dwi} -overlay.load ${dwi_b0} -fullscreen -mode 2 -overlay.opacity ${opacity}

