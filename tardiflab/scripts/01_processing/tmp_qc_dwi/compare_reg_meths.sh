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
  outdir=${testdir}

# Initialize file to store outputs with header
  cd ${outdir}
  echo "Original,ANTs_affine_trans,ANTs_SyN_trans,FSL_flirt,ANTs_SyN_final,ANTs_SyN_comboFOD" > tmpfile.csv


# loop over subjects for scan 1
  for ID in {01..30}; do

	SUB="sub-$ID"
  	SES="ses-1"
	echo ".. Running $SUB $SES .."
#        metric=$3

  	subdir_orig=${rootdir}/${SUB}/${SES}
  	subdir_test=${testdir}/${SUB}/${SES}/tmpregtest

  	dwi_b0=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-b0.nii.gz 		# better to use b0_brain computed in each method?

	## ----------------------------- Compute similarity --------------------------------------- ##

      # Original micapipe outputs
	dwi_b0=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-b0.nii.gz
	t1w_in_dwi_brain=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro-brain.nii.gz
        tmpvec=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])        			# Initialize vector to store all outputs for this sub

      # Linear AFFINE from improved ANTs method (+ translation step)
	t1w_in_dwi_brain=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro-brain.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1]) 				# tmp variable
  	tmpvec="$tmpvec,$tmpval" 												# concatenate

      # Nonlinear WARP from improved ANTs method (+ translation step used in AFFINE part)
	t1w_in_dwi_brain=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro-brain_SyN.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
	tmpvec="$tmpvec,$tmpval"

      # Linear AFFINE from FSL flirt
	t1w_in_dwi_brain=${subdir_test}/flirt/dwi/${SUB}_${SES}_t1w_brain_in_dwi.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
	tmpvec="$tmpvec,$tmpval"

      # Nonlinear WARP from FINAL version of ANTs
	t1w_in_dwi_brain=${subdir_test}/ants_final/dwi/${SUB}_${SES}_space-dwi_desc-syn-final_t1w_brain.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

      # Nonlinear WARP from COMBO version of ANTs (combined gm & wm FODs used as fixed image)
        t1w_in_dwi_brain=${subdir_test}/ants_comboFOD/dwi/${SUB}_${SES}_space-dwi_desc-syn-final_t1w_brain.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

      # Store measures
	{ cat tmpfile.csv; echo $tmpvec; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv; 			# Highly intelligent method to add newline to csv ;)
  done

  mv tmpfile.csv compare_reg_t1w_to_dwi_scan1.csv;



# Repeat for rescans

  echo "Original,ANTsmod_affine,ANTsmod_SyN,FSLflirt" > tmpfile.csv

  for ID in 18 {20..27} 29; do

        SUB="sub-$ID"
        SES="ses-2"
	echo ".. Running $SUB $SES .."
#        metric=$3

        subdir_orig=${rootdir}/${SUB}/${SES}
        subdir_test=${testdir}/${SUB}/${SES}/tmpregtest

        dwi_b0=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-b0.nii.gz
#        dwi_mask=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-brain_mask.nii.gz

        ## ----------------------------- Compute similarity --------------------------------------- ##

      # Original micapipe outputs
        t1w_in_dwi_brain=${subdir_orig}/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro-brain.nii.gz
        tmpvec=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])                                # Initialize vector to store all outputs for this sub

      # Linear AFFINE from improved ANTs method (+ translation step)
        t1w_in_dwi_brain=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro-brain.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])                                # tmp variable
        tmpvec="$tmpvec,$tmpval"                                                                                                # concatenate

      # Nonlinear WARP from improved ANTs method (+ translation step used in AFFINE part)
        t1w_in_dwi_brain=${subdir_test}/ants/dwi/${SUB}_${SES}_space-dwi_desc-t1w_nativepro-brain_SyN.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

      # Linear AFFINE from FSL flirt
        t1w_in_dwi_brain=${subdir_test}/flirt/dwi/${SUB}_${SES}_t1w_brain_in_dwi.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

      # Nonlinear WARP from FINAL version of ANTs
        t1w_in_dwi_brain=${subdir_test}/ants_final/dwi/${SUB}_${SES}_space-dwi_desc-syn-final_t1w_brain.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

      # Nonlinear WARP from COMBO version of ANTs (combined gm & wm FODs used as fixed image)
        t1w_in_dwi_brain=${subdir_test}/ants_comboFOD/dwi/${SUB}_${SES}_space-dwi_desc-syn-final_t1w_brain.nii.gz
        tmpval=$(MeasureImageSimilarity -d 3 -m MI[${dwi_b0},${t1w_in_dwi_brain},1,32,Regular,1])
        tmpvec="$tmpvec,$tmpval"

      # Store measures
        { cat tmpfile.csv; echo $tmpvec; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv;                        # Highly intelligent method to add newline to csv ;)
  done

  mv tmpfile.csv compare_reg_t1w_to_dwi_scan2.csv;
