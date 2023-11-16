#!/bin/bash
#
# Assesses T1w to FUNC registration using ANTs MeasureImageSimilarity
# Uses Mattes Mutual Information by default (larger negative values means better registration)
# Runs for all subjects and stores values in a .csv
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
  testdir=${rootdir}/tmp_micapipe/02_proc-func
  outdir=${testdir}
  cd ${outdir}


# Session 1
  echo "funcspace,t1wspace" > tmpfile.csv 							# Initialize file to store outputs with header
  for ID in {01..30}; do
#  for ID in 11; do

	SUB="sub-$ID"
  	SES="ses-1"
	idBIDS=${SUB}_${SES}
	echo ".. Running $SUB $SES .."
#        metric=$3

  	subdir_orig=${rootdir}/${SUB}/${SES}

	acq="se"
	tagMRI="se_task-rest_dir-AP_bold"
  	func_lab="_space-func_desc-${acq}"
	func_volum="${subdir_orig}/func/desc-se_task-rest_dir-AP_bold/volumetric"
	t1bold="${subdir_orig}/anat/${idBIDS}_space-nativepro_desc-t1wbold.nii.gz"
  	func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"

	## ----------------------------- Compute similarity --------------------------------------- ##

      # Func space
	T1nativepro_in_func="${func_volum}/${idBIDS}_space-func_desc-t1w.nii.gz"
        tmpvec=$(MeasureImageSimilarity -d 3 -m MI[${func_brain},${T1nativepro_in_func},1,32,Regular,1])        			# Initialize vector to store all outputs for this sub

      # T1w space
	fmri_in_T1nativepro="${subdir_orig}/anat/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${t1bold},${fmri_in_T1nativepro},1,32,Regular,1])
	tmpvec="$tmpvec,$tmpval"


      # Store measures
	{ cat tmpfile.csv; echo $tmpvec; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv; 			# Highly intelligent method to add newline to csv ;)
  done

  mv tmpfile.csv reg_check_t1w_func_scan1.csv;


# ----------------------------------------------------------------------------------------------------
# Session 2
  echo "funcspace,t1wspace" > tmpfile.csv 											# Initialize file to store outputs with header
  for ID in 18 {20..27} 29; do
#  for ID in 11; do

        SUB="sub-$ID"
        SES="ses-2"
        idBIDS=${SUB}_${SES}
        echo ".. Running $SUB $SES .."
#        metric=$3

        subdir_orig=${rootdir}/${SUB}/${SES}

        acq="se"
        tagMRI="se_task-rest_dir-AP_bold"
        func_lab="_space-func_desc-${acq}"
        func_volum="${subdir_orig}/func/desc-se_task-rest_dir-AP_bold/volumetric"
        t1bold="${subdir_orig}/anat/${idBIDS}_space-nativepro_desc-t1wbold.nii.gz"
        func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"

        ## ----------------------------- Compute similarity --------------------------------------- ##

      # Func space
        T1nativepro_in_func="${func_volum}/${idBIDS}_space-func_desc-t1w.nii.gz"
        tmpvec=$(MeasureImageSimilarity -d 3 -m MI[${func_brain},${T1nativepro_in_func},1,32,Regular,1])                                # Initialize vector to store all outputs for this sub

      # T1w space
        fmri_in_T1nativepro="${subdir_orig}/anat/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${t1bold},${fmri_in_T1nativepro},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"


      # Store measures
        { cat tmpfile.csv; echo $tmpvec; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv;                        # Highly intelligent method to add newline to csv ;)
  done

  mv tmpfile.csv reg_check_t1w_func_scan2.csv;

