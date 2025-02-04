#!/bin/bash
#
# Registers T1w <--> FUNC space using a nonlinear SyN method for a given SUBJECT & SES
#
# NOTE: specifically targeting problematic subjects: 08 11 13 18 18r 19 20 21r 26 27
#
# # INPUTS:
#       $1 : id  = num in (01..30)
# 	$2 : SES = num in 1, 2
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

  id="$1"
  SES="$2"

# ----------------------- SETUP ------------------------ #
# initialize necessary paths & dependencies
  source "/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh"
  export MICAPIPE=/data_/tardiflab/mwc/mwcpipe
  PATH=${PATH}:${MICAPIPE}:${MICAPIPE}/functions
  export PATH

  idBIDS=sub-${id}_ses-${SES}
  threads=6

# Directory to store outputs
  datadir="/data_/tardiflab/mwc/bids/derivatives/micapipe"
  testdir=${datadir}/tmp_micapipe/02_proc-func/sub-${id}/ses-${SES}/tmpregtest

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

# ANTs parameters
  RIGIDCONVERG="1000x500x250x0"
  RIGIDTOL="1e-6"
  RIGIDSHRINK="8x4x2x1"
  RIGIDSMOOTH="3x2x1x0vox"

  AFFINECONVERG="500x250x150x50"
  AFFINETOL="1e-6"
  AFFINESHRINK="4x2x1x1"
  AFFINESMOOTH="2x1x0x0vox"

  SYNCONVERG="100x70x50x20"
  SYNTOL="1e-6"
  SYNSHRINK="2x1x1x1"
  SYNSMOOTH="1x0x0x0vox"

# ------------------------ ANTs TESTING ---------------------------- #

# ANTs specific outputs
  meth="reg_1_affineOnly_MI"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm}  ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]] ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp}  ; fi


#--------- Compute FUNC --> T1w transform

# Settings
  moving="$func_brain"
  fixed1="$t1bold"                                                                                                                      	# Brain
  translation="[$fixed1,$moving,0]"                                                                                                             #0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1"                                                                                                                                 # weights for cost function
#  sample_fixed1="0.25"                                                                                                                          # Proportion of points to sample

# Affine only
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"
  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"

if [[ ! -f "$func_SyN_affine" ]]; then
    antsRegistration --dimensionality 3 \
    	--float 0 \
    	--output "$func_SyN_str" \
    	--interpolation Linear \
	--transform Rigid[0.1] \
        --metric MI["$fixed1","$moving","$w8_fixed1",32] \
        --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
        --shrink-factors "$RIGIDSHRINK" \
        --smoothing-sigmas "$RIGIDSMOOTH" \
    	--transform Affine[0.1] \
    	--metric MI["$fixed1","$moving","$w8_fixed1",32] \
    	--convergence ["$AFFINECONVERG","$AFFINETOL",10] \
    	--shrink-factors "$AFFINESHRINK" \
    	--smoothing-sigmas "$AFFINESMOOTH" \
    	--initial-moving-transform "$translation" \
    	--verbose 1 > "$log_syn"

else echo "---- AFFINE warp already computed at: ${func_SyN_affine}"; fi

if [[ ! -f "$fmri_in_T1nativepro" ]] || [[ ! -f "$T1nativepro_in_func" ]]; then
  	antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float --interpolation Linear
  	antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -t ["$func_SyN_affine",1] -o "$T1nativepro_in_func" -v --float --interpolation Linear
else echo "---- T1w-FUNC AFFINE reg already completed for ${idBIDS} in directory ${meth} "; fi




# ------------------------ ANTs TESTING 2 ---------------------------- #

# ANTs specific outputs
  meth="reg_2_affineOnly_CC"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm}  ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]] ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp}  ; fi


#--------- Compute FUNC --> T1w transform

# Settings
  moving="$func_brain"
  fixed1="$t1bold"                                                                                                                              # Brain
  translation="[$fixed1,$moving,0]"                                                                                                             #0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1"                                                                                                                                 # weights for cost function
#  sample_fixed1="0.25"                                                                                                                          # Proportion of points to sample

# Affine only
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"
  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"

if [[ ! -f "$func_SyN_affine" ]]; then
    antsRegistration --dimensionality 3 \
        --float 0 \
        --output "$func_SyN_str" \
        --interpolation Linear \
	--transform Rigid[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
        --shrink-factors "$RIGIDSHRINK" \
        --smoothing-sigmas "$RIGIDSMOOTH" \
        --transform Affine[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
        --shrink-factors "$AFFINESHRINK" \
        --smoothing-sigmas "$AFFINESMOOTH" \
        --initial-moving-transform "$translation" \
        --verbose 1 > "$log_syn"

else echo "---- AFFINE warp already computed at: ${func_SyN_affine}"; fi

if [[ ! -f "$fmri_in_T1nativepro" ]] || [[ ! -f "$T1nativepro_in_func" ]]; then
        antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float --interpolation Linear
        antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -t ["$func_SyN_affine",1]  -o "$T1nativepro_in_func" -v --float --interpolation Linear
else echo "---- T1w-FUNC AFFINE reg already completed for ${idBIDS} in directory ${meth} "; fi



# ------------------------ ANTs TESTING 4 ---------------------------- #

# ANTs specific outputs
  meth="reg_4_SyN_CC"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm}  ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]] ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp}  ; fi


#--------- Compute FUNC --> T1w transform
# Settings
  moving="$func_brain"
  fixed1="$t1bold"                                                                                                                              # Brain
  translation="[$fixed1,$moving,0]"                                                                                                             #0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1"                                                                                                                                 # weights for cost function
  sample_fixed1="0.25"                                                                                                                          # Proportion of points to sample

# Affine only
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_warp="${func_SyN_str}1Warp.nii.gz"
  func_SyN_Invwarp="${func_SyN_str}1InverseWarp.nii.gz"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"
  fmri_in_T1nativepro_bspline="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}-bspline_mean.nii.gz"
  T1nativepro_in_func_bspline="${testdir_func}/${idBIDS}_space-func_desc-t1w-bspline.nii.gz"

  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"


if [[ ! -f "$func_SyN_warp" ]]; then
    antsRegistration --dimensionality 3 \
        --float 0 \
        --output "$func_SyN_str" \
        --interpolation Linear \
        --transform Affine[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
        --shrink-factors "$AFFINESHRINK" \
        --smoothing-sigmas "$AFFINESMOOTH" \
        --transform SyN[0.1,3,0] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$SYNCONVERG","$SYNTOL",10] \
        --shrink-factors "$SYNSHRINK" \
        --smoothing-sigmas "$SYNSMOOTH" \
        --initial-moving-transform "$translation" \
        --verbose 1 > "$log_syn"

else echo "---- SyN warp already computed at: ${func_SyN_warp}"; fi

if [[ ! -f "$fmri_in_T1nativepro" ]] || [[ ! -f "$T1nativepro_in_func" ]]; then
        antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -t "$func_SyN_warp" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float --interpolation Linear
        antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -t ["$func_SyN_affine",1] -t "$func_SyN_Invwarp" -o "$T1nativepro_in_func" -v --float --interpolation Linear
else echo "---- T1w-FUNC SyN reg already completed for ${idBIDS} in directory ${meth} "; fi

if [[ ! -f "$fmri_in_T1nativepro_bspline" ]] || [[ ! -f "$T1nativepro_in_func_bspline" ]]; then
        antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline  -t "$func_SyN_warp" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro_bspline" -v --float
        antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -n BSpline -t ["$func_SyN_affine",1] -t "$func_SyN_Invwarp" -o "$T1nativepro_in_func_bspline" -v --float
else echo "---- T1w-FUNC SyN reg already completed for ${idBIDS} in directory ${meth} "; fi


# ------------------------ ANTs TESTING 5 ---------------------------- #

# ANTs specific outputs
  meth="reg_5_SyN_CC_allLevels_newparams"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm}  ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]] ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp}  ; fi

#--------- Compute FUNC --> T1w transform
# Settings
  moving="$func_brain"
  fixed1="$t1bold"                                                                                                                              # Brain
  translation="[$fixed1,$moving,0]"                                                                                                             #0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1"                                                                                                                                 # weights for cost function
  sample_fixed1="0.25"                                                                                                                          # Proportion of points to sample

# Affine only
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_warp="${func_SyN_str}1Warp.nii.gz"
  func_SyN_Invwarp="${func_SyN_str}1InverseWarp.nii.gz"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"

  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"

if [[ ! -f "$func_SyN_warp" ]]; then
    antsRegistration --dimensionality 3 \
        --float 0 \
        --output "$func_SyN_str" \
        --interpolation BSpline[3] \
	--transform Rigid[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
        --shrink-factors "$RIGIDSHRINK" \
        --smoothing-sigmas "$RIGIDSMOOTH" \
        --transform Affine[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
        --shrink-factors "$AFFINESHRINK" \
        --smoothing-sigmas "$AFFINESMOOTH" \
        --transform SyN[0.1,3,0] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$SYNCONVERG","$SYNTOL",10] \
        --shrink-factors "$SYNSHRINK" \
        --smoothing-sigmas "$SYNSMOOTH" \
        --initial-moving-transform "$translation" \
        --verbose 1 > "$log_syn"

else echo "---- SyN warp already computed at: ${func_SyN_warp}"; fi

if [[ ! -f "$fmri_in_T1nativepro" ]] || [[ ! -f "$T1nativepro_in_func" ]]; then
        antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$func_SyN_warp" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float
        antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -n BSpline -t ["$func_SyN_affine",1] -t "$func_SyN_Invwarp" -o "$T1nativepro_in_func" -v --float
else echo "---- T1w-FUNC SyN reg already completed for ${idBIDS} in directory ${meth} "; fi


# ------------------------ ANTs TESTING 6 ---------------------------- #

# ANTs specific outputs
  meth="reg_6_SyN_CC_lowerRegulariz"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_func=${testdir}/${meth}/func
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm}  ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_func} ]] ; then mkdir -p ${testdir_func} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp}  ; fi

#--------- Compute FUNC --> T1w transform
# Settings
  moving="$func_brain"
  fixed1="$t1bold"                                                                                                                              # Brain
  translation="[$fixed1,$moving,0]"                                                                                                             #0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1"                                                                                                                                 # weights for cost function
  sample_fixed1="0.25"                                                                                                                          # Proportion of points to sample
  SyN_regularize="0.05" 															# decreases smoothing, higher risk of overfitting
#  SyN_regularize="0.01"                                                                                                                         # decreases smoothing, higher risk of overfitting

# Affine only
  func_SyN_str="${testdir_xfm}/${idBIDS}_space-nativepro_from-func_to-t1w_mode-image_desc-SyN_"
  func_SyN_warp="${func_SyN_str}1Warp.nii.gz"
  func_SyN_Invwarp="${func_SyN_str}1InverseWarp.nii.gz"
  func_SyN_affine="${func_SyN_str}0GenericAffine.mat"
  fmri_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${testdir_func}/${idBIDS}_space-func_desc-t1w.nii.gz"

  log_syn="${testdir_xfm}/${idBIDS}_log_syn.txt"

if [[ ! -f "$func_SyN_warp" ]]; then
    antsRegistration --dimensionality 3 \
        --float 0 \
        --output "$func_SyN_str" \
        --interpolation BSpline[3] \
        --transform Rigid[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
        --shrink-factors "$RIGIDSHRINK" \
        --smoothing-sigmas "$RIGIDSMOOTH" \
        --transform Affine[0.1] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
        --shrink-factors "$AFFINESHRINK" \
        --smoothing-sigmas "$AFFINESMOOTH" \
        --transform SyN["$SyN_regularize",3,0] \
        --metric CC["$fixed1","$moving","$w8_fixed1",4] \
        --convergence ["$SYNCONVERG","$SYNTOL",10] \
        --shrink-factors "$SYNSHRINK" \
        --smoothing-sigmas "$SYNSMOOTH" \
        --initial-moving-transform "$translation" \
        --verbose 1 > "$log_syn"

else echo "---- SyN warp already computed at: ${func_SyN_warp}"; fi

if [[ ! -f "$fmri_in_T1nativepro" ]] || [[ ! -f "$T1nativepro_in_func" ]]; then
        antsApplyTransforms -d 3 -i "$moving" -r "$fixed1" -n BSpline -t "$func_SyN_warp" -t "$func_SyN_affine" -o "$fmri_in_T1nativepro" -v --float
        antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$moving" -n BSpline -t ["$func_SyN_affine",1] -t "$func_SyN_Invwarp" -o "$T1nativepro_in_func" -v --float
else echo "---- T1w-FUNC SyN reg already completed for ${idBIDS} in directory ${meth} "; fi

