#!/bin/bash
#
# A Test script which registers T1w & FUNC images using ANTS to facilitate fine tuning of the registration method
#
# NOTE: FUNCTION IS NOT MEANT TO BE CALLED,
# 	CURRENTLY THIS CODE IS BEING DEVELOPED AND TESTED MANUALLY.
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

id="11"; SES="1"; # TESTING

# ----------------------- SETUP ------------------------ #
# initialize necessary paths & dependencies
  source "/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh"
  export MICAPIPE=/data_/tardiflab/mwc/mwcpipe
  PATH=${PATH}:${MICAPIPE}:${MICAPIPE}/functions
  export PATH

# options
#  SES="$2"
#  id="$1"
  idBIDS=sub-${id}_ses-${SES}
  threads=6

# Directory to store outputs
  datadir="/data_/tardiflab/mwc/bids/derivatives/micapipe"
  testdir=${datadir}/tmp_micapipe/02_proc-func/sub-${id}/ses-${SES}/tmpregtest_testANTs

# Subject data dirs
  sub_dir=${datadir}/sub-${id}/ses-${SES}
  proc_anat=${sub_dir}/anat
  proc_func=${sub_dir}/func
  dir_warp=${sub_dir}/xfm

  acq="se"
  tagMRI="se_task-rest_dir-AP_bold"
  func_lab="_space-func_desc-${acq}"

  func_volum="${proc_func}/desc-se_task-rest_dir-AP_bold/volumetric"
  func_surf="${proc_func}/desc-se_task-rest_dir-AP_bold/surfaces"
  t1bold="${proc_anat}/${idBIDS}_space-nativepro_desc-t1wbold.nii.gz"
  func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"
  T1nativepro_brain=${proc_anat}/${idBIDS}_space-nativepro_t1w_brain.nii.gz


# ------------------------ ANTs TESTING ---------------------------- #

# ANTs specific outputs
  meth="ants_0_test"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]]  ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi


#--------- Compute FUNC --> T1w transform

# Settings
  moving="$func_brain"
  fixed1="$t1bold"                                                                            						# Brain
  translation="[$fixed1,$moving,1]"														#0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1" 																# weights for cost function
  sample_fixed1="0.25"																# Proportion of points to sample

  RIGIDCONVERG="1000x500x250x100"
  RIGIDTOL="1e-6"
  RIGIDSHRINK="8x4x2x1"
  RIGIDSMOOTH="3x2x1x0"

  AFFINECONVERG="1000x500x250x100"
  AFFINETOL="1e-6"
  AFFINESHRINK="8x4x2x1"
  AFFINESMOOTH="3x2x1x0"


# Rigid + Affine + SyN
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_warp="${func_SyN_str}1Warp.nii.gz"
  func_SyN_Invwarp="${func_SyN_str}1InverseWarp.nii.gz"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"
  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"

  SYNCONVERG="100x100x100"
  SYNTOL="1e-6"
  SYNSHRINK="3x2x1"
  SYNSMOOTH="2x1x0"

  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$func_SyN_str" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --transform Affine[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
    --shrink-factors "$AFFINESHRINK" \
    --smoothing-sigmas "$AFFINESMOOTH" \
    --transform SyN[0.1,3,0] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --convergence ["$SYNCONVERG","$SYNTOL",10] \
    --shrink-factors "$SYNSHRINK" \
    --smoothing-sigmas "$SYNSMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1 > "$log_syn"

  antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$func_SyN_warp" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float
  antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -n BSpline -t "$func_SyN_affine" -t "$func_SyN_Invwarp" -o "$T1nativepro_in_func" -v --float

  MeasureImageSimilarity -d 3 -m MI["$moving","$T1nativepro_in_func",1,32,Regular,1]
  MeasureImageSimilarity -d 3 -m MI["$fixed1","$fmri_in_T1nativepro",1,32,Regular,1]



# ------------------------ ANTs TESTING 2 ---------------------------- #

# ANTs specific outputs
  meth="ants_1_upsample"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]]  ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi

#--------- Compute FUNC --> T1w transform

# Upsample to T1w resolution
  func_brain_hires="${testdir_tmp}/${idBIDS}${func_lab}_brain_upsampled.nii.gz"
  mrgrid "$func_brain" regrid -vox 1.0 "$func_brain_hires"

# Settings
  moving="$func_brain_hires"
  fixed1="$t1bold"                                                                                                                      # Brain
  translation="[$fixed1,$moving,1]"                                                                                                             #0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1"                                                                                                                                 # weights for cost function
  sample_fixed1="0.25"                                                                                                                          # Proportion of points to sample

  RIGIDCONVERG="1000x500x250x100"
  RIGIDTOL="1e-6"
  RIGIDSHRINK="8x4x2x1"
  RIGIDSMOOTH="3x2x1x0"

  AFFINECONVERG="1000x500x250x100"
  AFFINETOL="1e-6"
  AFFINESHRINK="8x4x2x1"
  AFFINESMOOTH="3x2x1x0"

  # Rigid + Affine + SyN
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_warp="${func_SyN_str}1Warp.nii.gz"
  func_SyN_Invwarp="${func_SyN_str}1InverseWarp.nii.gz"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"
  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"

  SYNCONVERG="100x100x100"
  SYNTOL="1e-6"
  SYNSHRINK="3x2x1"
  SYNSMOOTH="2x1x0"

  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$func_SyN_str" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --transform Affine[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
    --shrink-factors "$AFFINESHRINK" \
    --smoothing-sigmas "$AFFINESMOOTH" \
    --transform SyN[0.1,3,0] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --convergence ["$SYNCONVERG","$SYNTOL",10] \
    --shrink-factors "$SYNSHRINK" \
    --smoothing-sigmas "$SYNSMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1 > "$log_syn"

  antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$func_SyN_warp" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float
  antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -n BSpline -t "$func_SyN_affine" -t "$func_SyN_Invwarp" -o "$T1nativepro_in_func" -v --float

  MeasureImageSimilarity -d 3 -m MI["$moving","$T1nativepro_in_func",1,32,Regular,1]
  MeasureImageSimilarity -d 3 -m MI["$fixed1","$fmri_in_T1nativepro",1,32,Regular,1]




