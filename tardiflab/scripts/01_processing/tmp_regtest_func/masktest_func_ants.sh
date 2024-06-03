#!/bin/bash
#
# Computes a brian mask using a few different methods:
# 	1. mri_synthstrip from freesurfer
# 	2. FSL BET with default params
# 	3. FSL BET with lower value for -f (mor liberal fractional intensity threshold, larger brain outline estimates)
# 	4. ANTs antsBrainExtraction.sh (maybe not intended for func data??)
#
# # INPUTS:
#       $1 : id  = num in (01..30)
# 	$2 : SES = num in 1, 2
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

  id="$1"
  SES="$2"

# ----------------------- SETUP ------------------------ #
# initialize necessary paths & dependencies
  source "/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh"
  export FREESURFER_HOME=/data_/tardiflab/01_programs/freesurfer_v7-4-1/ && source $FREESURFER_HOME/FreeSurferEnv.sh
  export MICAPIPE=/data_/tardiflab/mwc/mwcpipe
  PATH=${PATH}:${MICAPIPE}:${MICAPIPE}/functions:${FREESURFER_HOME}/bin
  export PATH


  idBIDS=sub-${id}_ses-${SES}
  threads=6

# Directory to store outputs
  datadir="/data_/tardiflab/mwc/bids/derivatives/micapipe"
  testdir=${datadir}/tmp_micapipe/02_proc-func/sub-${id}/ses-${SES}/tmpmasktest

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
#  t1bold="${proc_anat}/${idBIDS}_space-nativepro_desc-t1wbold.nii.gz"
#  func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"
  T1nativepro_brain=${proc_anat}/${idBIDS}_space-nativepro_t1w_brain.nii.gz
  fmri_mean="${func_volum}/${idBIDS}${func_lab}_mean.nii.gz"


### ------------------ METHOD 1: mri_synthstrip
  meth="synthstrip"

# Setup
  tmp="${testdir}/1_${meth}"
  if [[ ! -d ${tmp}/xfm ]]  ; then mkdir -p ${tmp}/xfm ; fi
  fmri_brain="${tmp}/${idBIDS}${func_lab}_brain.nii.gz"
  fmri_mask="${tmp}/${idBIDS}${func_lab}_brain_mask.nii.gz"

# Function
  mri_synthstrip -i "$fmri_mean" -o "$fmri_brain" -m "$fmri_mask"




### ------------------ METHOD 2: FSL BET with default params (-f .5)
  meth="bet_default"

# Setup
  tmp="${testdir}/2_${meth}"
  if [[ ! -d ${tmp}/xfm ]]  ; then mkdir -p ${tmp}/xfm ; fi
  fmri_brain="${tmp}/${idBIDS}${func_lab}_brain.nii.gz"
  fmri_mask="${tmp}/${idBIDS}${func_lab}_brain_mask.nii.gz"

# Function
  bet "$fmri_mean" "$fmri_brain" -m -n
  fslmaths "$fmri_mean" -mul "$fmri_mask" "$fmri_brain"



### ------------------ METHOD 3: FSL BET -f .4 (lower values for -f --> larger brain outlines)
  meth="bet_f_4"

# Setup
  tmp="${testdir}/3_${meth}"
  if [[ ! -d ${tmp}/xfm ]]  ; then mkdir -p ${tmp}/xfm ; fi
  fmri_brain="${tmp}/${idBIDS}${func_lab}_brain.nii.gz"
  fmri_mask="${tmp}/${idBIDS}${func_lab}_brain_mask.nii.gz"

# Function
  bet "$fmri_mean" "$fmri_brain" -m -n -f .4
  fslmaths "$fmri_mean" -mul "$fmri_mask" "$fmri_brain"


### ------------------ METHOD 4: FSL BET -f .3 (lower values for -f --> larger brain outlines)
  meth="bet_f_3"

# Setup
  tmp="${testdir}/4_${meth}"
  if [[ ! -d ${tmp}/xfm ]]  ; then mkdir -p ${tmp}/xfm ; fi
  fmri_brain="${tmp}/${idBIDS}${func_lab}_brain.nii.gz"
  fmri_mask="${tmp}/${idBIDS}${func_lab}_brain_mask.nii.gz"

# Function
  bet "$fmri_mean" "$fmri_brain" -m -n -f .3
  fslmaths "$fmri_mean" -mul "$fmri_mask" "$fmri_brain"


#  fmri_mask_erode="${tmp}/${idBIDS}${func_lab}_brain_mask_erode.nii.gz"
#  maskfilter "$fmri_mask" erode -npass 1 "$fmri_mask_erode"


### ------------------ METHOD 5: FSL BET -f .2 (lower values for -f --> larger brain outlines)
#  meth="bet_f_2"

# Setup
#  tmp="${testdir}/5_${meth}"
#  if [[ ! -d ${tmp}/xfm ]]  ; then mkdir -p ${tmp}/xfm ; fi
#  fmri_brain="${tmp}/${idBIDS}${func_lab}_brain.nii.gz"
#  fmri_mask="${tmp}/${idBIDS}${func_lab}_brain_mask.nii.gz"

# Function
#  bet "$fmri_mean" "$fmri_brain" -m -n -f .2
#  fslmaths "$fmri_mean" -mul "$fmri_mask" "$fmri_brain"




# Compute mask on mean func image
#  antsBrainExtraction.sh -d 3 -a <anatomical image> \
#  -e <brainWithSkullTemplate> -m <brainPrior> -o <output>
