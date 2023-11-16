#!/bin/bash
#
# Registers T1w --> dwi space using a rigid approach applying the parameters given as input
#
#
# # INPUTS:
#       $1 : id  = num in (01..30)
# 	$2 : SES = num in 1, 2
#
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# ----------------------- SETUP ------------------------ #
# initialize necessary paths & dependencies
  source "/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh"
  export MICAPIPE=/data_/tardiflab/mwc/mwcpipe
  PATH=${PATH}:${MICAPIPE}:${MICAPIPE}/functions
  export PATH

# options
  SES="$2"
  id="$1"
  idBIDS=sub-${id}_ses-${SES}
  threads=6

# Directory to store outputs
  datadir="/data_/tardiflab/mwc/bids/derivatives/micapipe"
  testdir=${datadir}/tmp_micapipe/02_proc-dwi/sub-${id}/ses-${SES}/tmpregtest_testANTs

# Subject data dirs
  sub_dir=${datadir}/sub-${id}/ses-${SES}
  proc_anat=${sub_dir}/anat
  proc_dwi=${sub_dir}/dwi
  dir_warp=${sub_dir}/xfm

# Subject data Files
  export util_MNIvolumes=${MICAPIPE}/MNI152Volumes
  export MNI152_mask=${util_MNIvolumes}/MNI152_T1_1mm_brain_mask.nii.gz

  export mat_MNI152_SyN=${dir_warp}/${idBIDS}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_
  export T1_MNI152_affine=${mat_MNI152_SyN}0GenericAffine.mat
  export T1_MNI152_InvWarp=${mat_MNI152_SyN}1InverseWarp.nii.gz

  export T15ttgen=${proc_anat}/${idBIDS}_space-nativepro_t1w_5TT.nii.gz

  T1nativepro=${proc_anat}/${idBIDS}_space-nativepro_t1w.nii.gz
  T1nativepro_brain=${proc_anat}/${idBIDS}_space-nativepro_t1w_brain.nii.gz
  dwi_b0=${proc_dwi}/${idBIDS}_space-dwi_desc-b0.nii.gz
  dwi_corr="${proc_dwi}/${idBIDS}_space-dwi_desc-dwi_preproc.mif"
#  fod="${datadir}/tmp_micapipe/02_proc-dwi/sub-${id}/ses-${SES}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.nii.gz" # This original file is faulty if T1w-dwi affine was not accurate

#  dwi_dns="${datadir}/tmp_micapipe/02_proc-dwi/sub-${id}/ses-${SES}/MP-PCA_degibbs.mif"
  shells=($(mrinfo "$dwi_corr" -shell_bvalues))


# ------------------------ ANTs TESTING ---------------------------- #

# ANTs specific outputs
  meth="ants_0_test_rigid"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_dwi=${testdir}/${meth}/dwi
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_dwi} ]]  ; then mkdir -p ${testdir_dwi} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi

#--------- Compute dwi mask
  dwi_b0_brain=${testdir_dwi}/${idBIDS}_space-dwi_desc-b0_brain_bet.nii.gz
  dwi_mask_tmp="${testdir_dwi}/${idBIDS}_space-dwi_desc-b0_brain_bet_mask.nii.gz"
  dwi_mask="${testdir_dwi}/${idBIDS}_space-dwi_desc-b0_brain_bet_mask_erode.nii.gz"

  if [[ ! -f ${dwi_mask} ]]  ; then

      # Test fsl Bet mask option
	bet "$dwi_b0" "$dwi_b0_brain" -m -v # -B -f 0.25
	maskfilter "$dwi_mask_tmp" erode -npass 1 "$dwi_mask"
  else
    	echo "Subject ${id} already has a dwi mask"
  fi


#---------- compute wm fod (MSMT_CSD)
# Response function and Fiber Orientation Distribution
  fod_wmN="${testdir_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.mif"
  fod_gmN="${testdir_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-gmNorm.mif"
  fod_csfN="${testdir_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-csfNorm.mif"
  if [[ ! -f "$fod_wmN" ]]; then
  	echo "Calculating Multi-Shell Multi-Tissue, Response function and Fiber Orientation Distribution"
        rf=dhollander
      # Response function
        rf_wm="${testdir_tmp}/${id}_response_wm_${rf}.txt"
        rf_gm="${testdir_tmp}/${id}_response_gm_${rf}.txt"
        rf_csf="${testdir_tmp}/${id}_response_csf_${rf}.txt"

      # Fiber Orientation Distriution
        fod_wm="${testdir_tmp}/${id}_wm_fod.mif"
        fod_gm="${testdir_tmp}/${id}_gm_fod.mif"
        fod_csf="${testdir_tmp}/${id}_csf_fod.mif"

        dwi2response "$rf" -nthreads "$threads" "$dwi_corr" "$rf_wm" "$rf_gm" "$rf_csf" -mask "$dwi_mask"
        dwi2fod -nthreads "$threads" msmt_csd "$dwi_corr" \
        	"$rf_wm" "$fod_wm" \
                "$rf_gm" "$fod_gm" \
                "$rf_csf" "$fod_csf" \
                -mask "$dwi_mask"
        if [ "${#shells[@]}" -ge 2 ]; then
        	mtnormalise "$fod_wm" "$fod_wmN" "$fod_gm" "$fod_gmN" "$fod_csf" "$fod_csfN" \
			    -nthreads "$threads" -mask "$dwi_mask"
                mrinfo "$fod_wmN" -json_all "${fod_wmN/mif/json}"
                mrinfo "$fod_gmN" -json_all "${fod_gmN/mif/json}"
                mrinfo "$fod_csfN" -json_all "${fod_csfN/mif/json}"
        else
                mtnormalise -nthreads "$threads" -mask "$dwi_mask" "$fod_wm" "$fod_wmN"
                mrinfo "$fod_wmN" -json_all "${fod_wmN/mif/json}"
        fi
  else
        echo "Subject ${id} has Fiber Orientation Distribution file";
  fi


#---------- Upsample b0 and wmfod to T1w resolution

  dwi_b0_hires="${testdir_tmp}/${idBIDS}_space-dwi_desc-b0_brain_upsampled.nii.gz"
  fod_hires="${testdir_tmp}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm_upsampled.nii.gz"
  fod="${testdir_tmp}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.nii.gz"

  if [[ ! -f "$fod" ]]; then
      # Extract 1st volume from wm FOD & convert to nifti
  	mrconvert -coord 3 0 "$fod_wmN" "$fod"
  fi

  if [[ ! -f "$fod_hires" ]] | [[ ! -f "$dwi_b0_hires" ]]; then
      # Upsample b0 & wm fod
  	mrgrid "$dwi_b0_brain" regrid -vox 1.0 "$dwi_b0_hires"
  	mrgrid "$fod" regrid -vox 1.0 "$fod_hires"
  fi


#--------- Compute T1w --> DWI transforms using both b0 & wmfod as fixed images

# Settings
  moving="$T1nativepro_brain"
  fixed1="$dwi_b0_hires"                                                                            						# Brain
  fixed2="$fod_hires"
  translation="[$fixed1,$moving,1]"
  w8_fixed1="0.5" 																# weights for cost function
  w8_fixed2="0.5"
  sample_fixed1="0.25"																# Proportion of points to sample
  sample_fixed2="0.25"

  RIGIDCONVERG="1000x500x250x100"
  RIGIDSHRINK="8x4x2x1"
  RIGIDSMOOTH="3x2x1x0"

  AFFINECONVERG="1000x500x250x100"
  AFFINESHRINK="8x4x2x1"
  AFFINESMOOTH="3x2x1x0"

  SYNCONVERG="100x70x50x20"
  SYNSHRINK="8x4x2x1"
  SYNSMOOTH="3x2x1x0"


# Rigid only
  str_t1w_to_dwi_rigid="${testdir_xfm}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-rigid_"
  mat_t1w_to_dwi_rigid="${str_t1w_to_dwi_rigid}0GenericAffine.mat"
  T1nativepro_brain_in_dwi_rigid=${testdir_dwi}/${idBIDS}_space-dwi_desc-rigid_t1w_brain.nii.gz
  T1nativepro_in_dwi_rigid=${testdir_dwi}/${idBIDS}_space-dwi_desc-rigid_t1w.nii.gz

  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$str_t1w_to_dwi_rigid" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$RIGIDCONVERG",1e-6,10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1

  antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$mat_t1w_to_dwi_rigid" -o "$T1nativepro_brain_in_dwi_rigid" -v --float
  antsApplyTransforms -d 3 -i "$T1nativepro" -r "$fixed1" -n BSpline -t "$mat_t1w_to_dwi_rigid" -o "$T1nativepro_in_dwi_rigid" -v --float



# Rigid & Affine combined
  str_t1w_to_dwi_affine="${testdir_xfm}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-affine_"
  mat_t1w_to_dwi_affine="${str_t1w_to_dwi_affine}0GenericAffine.mat"
  T1nativepro_brain_in_dwi_affine=${testdir_dwi}/${idBIDS}_space-dwi_desc-affine_t1w_brain.nii.gz
  T1nativepro_in_dwi_affine=${testdir_dwi}/${idBIDS}_space-dwi_desc-affine_t1w.nii.gz


  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$str_t1w_to_dwi_affine" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$RIGIDCONVERG",1e-6,10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --transform Affine[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$AFFINECONVERG",1e-6,10] \
    --shrink-factors "$AFFINESHRINK" \
    --smoothing-sigmas "$AFFINESMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1

  antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$mat_t1w_to_dwi_affine" -o "$T1nativepro_brain_in_dwi_affine" -v --float
  antsApplyTransforms -d 3 -i "$T1nativepro" -r "$fixed1" -n BSpline -t "$mat_t1w_to_dwi_affine" -o "$T1nativepro_in_dwi_affine" -v --float


# Rigid + Affine + SyN
  dwi_SyN_str="${testdir_xfm}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"
  dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
  dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
  dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"
  T1nativepro_brain_in_dwi_syn=${testdir_dwi}/${idBIDS}_space-dwi_desc-syn_t1w_brain.nii.gz
  T1nativepro_in_dwi_syn=${testdir_dwi}/${idBIDS}_space-dwi_desc-syn_t1w.nii.gz


  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$dwi_SyN_str" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$RIGIDCONVERG",1e-6,10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --transform Affine[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$AFFINECONVERG",1e-6,10] \
    --shrink-factors "$AFFINESHRINK" \
    --smoothing-sigmas "$AFFINESMOOTH" \
    --transform SyN[0.1,3,0] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$SYNCONVERG",1e-6,10] \
    --shrink-factors "$SYNSHRINK" \
    --smoothing-sigmas "$SYNSMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1

  antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$dwi_SyN_warp" -o "$T1nativepro_brain_in_dwi_syn" -v --float     # -t "$dwi_SyN_warp" -t "$dwi_SyN_affine"
  antsApplyTransforms -d 3 -i "$T1nativepro" -r "$fixed1" -n BSpline -t "$dwi_SyN_warp" -o "$T1nativepro_in_dwi_syn" -v --float


  antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -o "$T1nativepro_brain_in_dwi_syn" -v --float     # -t "$dwi_SyN_warp" -t "$dwi_SyN_affine"
  antsApplyTransforms -d 3 -i "$T1nativepro" -r "$fixed1" -n BSpline -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -o "$T1nativepro_in_dwi_syn" -v --float


