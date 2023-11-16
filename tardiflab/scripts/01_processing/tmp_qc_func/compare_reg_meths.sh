#!/bin/bash
#
# Compares methods for T1w to FUNC registration using ANTs MeasureImageSimilarity
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
  testdir=${rootdir}/tmp_micapipe/02_proc-func
  outdir=${testdir}

# Initialize file to store outputs with header
  cd ${outdir}
  echo "Original,ANTs_SyN_trans,ANTs_SyN_upsample,ANTs_SyN_reversedir" > tmpfile.csv


# loop over subjects for scan 1
  for ID in {01..30}; do
#  for ID in 11; do

	SUB="sub-$ID"
  	SES="ses-1"
	idBIDS=${SUB}_${SES}
	echo ".. Running $SUB $SES .."
#        metric=$3

  	subdir_orig=${rootdir}/${SUB}/${SES}
  	subdir_test=${testdir}/${SUB}/${SES}/tmpregtest_testANTs

	acq="se"
	tagMRI="se_task-rest_dir-AP_bold"
  	func_lab="_space-func_desc-${acq}"
	func_volum="${subdir_orig}/func/desc-se_task-rest_dir-AP_bold/volumetric"
	t1bold="${subdir_orig}/anat/${idBIDS}_space-nativepro_desc-t1wbold.nii.gz"
  	func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"

	## ----------------------------- Compute similarity --------------------------------------- ##

      # (1) Original micapipe outputs
	T1nativepro_in_func="${func_volum}/${idBIDS}_space-func_desc-t1w.nii.gz"
        tmpvec=$(MeasureImageSimilarity -d 3 -m MI[${func_brain},${T1nativepro_in_func},1,32,Regular,1])        			# Initialize vector to store all outputs for this sub

#	fmri_in_T1nativepro="${subdir_orig}/anat/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
#        tmpvec=$(MeasureImageSimilarity -d 3 -m MI[${t1bold},${fmri_in_T1nativepro},1,32,Regular,1])



      # (2) Nonlinear WARP + translation step
	meth="ants_0_test"

	T1nativepro_in_func="${subdir_test}/${meth}/func/${idBIDS}_space-func_desc-t1w.nii.gz"
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${func_brain},${T1nativepro_in_func},1,32,Regular,1])
	tmpvec="$tmpvec,$tmpval"

#	fmri_in_T1nativepro="${subdir_test}/${meth}/anat/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
#        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${t1bold},${fmri_in_T1nativepro},1,32,Regular,1])
#        tmpvec="$tmpvec,$tmpval"



      # (3) Nonlinear WARP + translation & upsampling
        meth="ants_1_upsample"

       	T1nativepro_in_func="${subdir_test}/${meth}/func/${idBIDS}_space-func_desc-t1w.nii.gz"
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${func_brain},${T1nativepro_in_func},1,32,Regular,1])
       	tmpvec="$tmpvec,$tmpval"

#        fmri_in_T1nativepro="${subdir_test}/${meth}/anat/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
#        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${t1bold},${fmri_in_T1nativepro},1,32,Regular,1])
#        tmpvec="$tmpvec,$tmpval"



      # (4) Nonlinear WARP + translation & upsampling in REVERSE direction (T1w --> FUNC)
        meth="ants_2_reversedir"

        T1nativepro_in_func="${subdir_test}/${meth}/func/${idBIDS}_space-func_desc-t1w.nii.gz"
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${func_brain},${T1nativepro_in_func},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

#        fmri_in_T1nativepro="${subdir_test}/${meth}/anat/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
#        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${t1bold},${fmri_in_T1nativepro},1,32,Regular,1])
#        tmpvec="$tmpvec,$tmpval"



      # Store measures
	{ cat tmpfile.csv; echo $tmpvec; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv; 			# Highly intelligent method to add newline to csv ;)
  done

  mv tmpfile.csv compare_reg_t1w_to_func_scan1.csv;


