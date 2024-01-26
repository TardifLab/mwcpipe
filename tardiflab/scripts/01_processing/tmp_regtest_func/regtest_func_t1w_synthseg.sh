#!/bin/bash
#
# Registers T1w <--> FUNC space using the mri_synthseg function from newer freesurfer packages
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
  testdir=${datadir}/tmp_micapipe/02_proc-func/sub-${id}/ses-${SES}/tmpregtest_synthseg

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
  func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"
  T1nativepro_brain=${proc_anat}/${idBIDS}_space-nativepro_t1w_brain.nii.gz



## ----- SYNTHSEG test1: micapipe implementation ----- ##

# Dirs
#  tmp=/data_/tardiflab/mwc/bids/derivatives/micapipe/tmp_micapipe/02_proc-func/sub-10/ses-1/tmpregtest
  tmp=${testdir}
  if [[ ! -d ${tmp}/xfm ]]  ; then mkdir -p ${tmp}/xfm ; fi

# Files
  bold_synth="${tmp}/func_brain_synthsegGM.nii.gz"
  t1_synth="${tmp}/T1bold_synthsegGM.nii.gz"


  t1bold2="${tmp}/${idBIDS}_space-nativepro_desc-T1wbold.nii.gz"
  func_mean=${func_volum}/${idBIDS}_space-func_desc-se_mean.nii.gz

# Generating synthetic images
  voxels=$(mrinfo "${func_mean}" -spacing); voxels="${voxels// /,}"
  flirt -applyisoxfm "${voxels}" -in "${T1nativepro_brain}" -ref "${T1nativepro_brain}" -out "${t1bold2}"

  mri_synthseg --i "${t1bold2}" --o "${tmp}/T1bold_synthseg.nii.gz" --robust --threads "$threads" --cpu
  fslmaths "${tmp}/T1bold_synthseg.nii.gz" -uthr 42 -thr 42 -bin -mul -39 -add "${tmp}/T1bold_synthseg.nii.gz" "${t1_synth}"

  mri_synthseg --i "$func_brain" --o "${tmp}/func_brain_synthseg.nii.gz" --robust --threads "$threads" --cpu
  fslmaths "${tmp}/func_brain_synthseg.nii.gz" -uthr 42 -thr 42 -bin -mul -39 -add "${tmp}/func_brain_synthseg.nii.gz" "${bold_synth}"

# Define registration files
  func_in_T1nativepro="${tmp}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean-test1.nii.gz"
  T1nativepro_in_func="${tmp}/${idBIDS}_space-func_desc-T1w-test1.nii.gz"
  str_func_affine="${tmp}/xfm/${idBIDS}_from-${tagMRI}_to-nativepro_mode-image_desc-affine-test1_"
  mat_func_affine="${str_func_affine}0GenericAffine.mat"

  str_func_SyN="${tmp}/xfm/${idBIDS}_from-nativepro_func_to-${tagMRI}_mode-image_desc-SyN-test1_"
  SyN_func_affine="${str_func_SyN}0GenericAffine.mat"
  SyN_func_warp="${str_func_SyN}1Warp.nii.gz"
  SyN_func_Invwarp="${str_func_SyN}1InverseWarp.nii.gz"

  transformsInv="-t ${SyN_func_warp} -t ${SyN_func_affine} -t [${mat_func_affine},1]" 			# T1nativepro to func
#  transform="-t ${mat_func_affine} -t [${SyN_func_affine},1] -t ${SyN_func_Invwarp}"  			# func to T1nativepro
  xfmat="-t ${SyN_func_affine} -t [${mat_func_affine},1]" 						# T1nativepro to func only lineal for FIX


# Affine from func to t1-nativepro
  antsRegistrationSyN.sh -d 3 -f "$t1_synth" -m "$bold_synth" -o "$str_func_affine" -t a -n "$threads" -p d
  antsApplyTransforms -d 3 -i "$t1_synth" -r "$bold_synth" -t ["$mat_func_affine",1] -o "${tmp}/T1bold_in_func-test1.nii.gz" -v -u int

# SyN from T1_nativepro to t1-nativepro
  antsRegistrationSyN.sh -d 3 -m "${tmp}/T1bold_in_func-test1.nii.gz" -f "${bold_synth}" -o "$str_func_SyN" -t s -n "$threads" -p d

# func to t1-nativepro
#  antsApplyTransforms -d 3 -i "$func_brain" -r "$t1bold2" "$transform" -o "$func_in_T1nativepro" -v -u int
  antsApplyTransforms -d 3 -i "$func_brain" -r "$t1bold2" -t "$mat_func_affine" -t ["$SyN_func_affine",1] -t "$SyN_func_Invwarp" -o "$func_in_T1nativepro" -v -u int

# t1-nativepro to func
#  antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$func_brain" "$transformsInv" -o "${T1nativepro_in_func}" -v -u int
  antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$func_brain" -t "$SyN_func_warp" -t "$SyN_func_affine" -t ["$mat_func_affine",1] -o "${T1nativepro_in_func}" -v -u int



## ----- SYNTHSEG test2: tardiflab implementation ----- ##

  testtag="test2"
  func_in_T1nativepro="${tmp}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean-${testtag}.nii.gz"
  T1nativepro_in_func="${tmp}/${idBIDS}_space-func_desc-T1w-${testtag}.nii.gz"

  str_func_SyN="${tmp}/xfm/${idBIDS}_from-nativepro_func_to-${tagMRI}_mode-image_desc-SyN-${testtag}_"
  SyN_func_affine="${str_func_SyN}0GenericAffine.mat"
  SyN_func_warp="${str_func_SyN}1Warp.nii.gz"
  SyN_func_Invwarp="${str_func_SyN}1InverseWarp.nii.gz"

  log_syn="${tmp}/${idBIDS}_log_syn-${testtag}.txt"

  export reg="Affine+SyN"
  transformsInv="-t [${SyN_func_affine},1] -t ${SyN_func_Invwarp}"                        # T1w --> func space
  transform="-t ${SyN_func_warp} -t ${SyN_func_affine}"                                   # func --> T1w space
  xfmat="-t [${SyN_func_affine},1]"                                                       # T1nativepro to func only lineal for FIX


  REGSCRIPT="/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/t1w_func_registration_SyN.sh"           # Custom T1w-FUNC reg method
  moving="$bold_synth"
  fixed="$t1_synth"

# Compute transform
  $REGSCRIPT $moving $fixed $str_func_SyN $log_syn

# Apply transforms
#  antsApplyTransforms -d 3 -i "${func_brain}" -r "${t1bold2}" -n BSpline "$transform" -o "${func_in_T1nativepro}" -v --float
#  antsApplyTransforms -d 3 -i "${T1nativepro_brain}" -r "${func_brain}" -n BSpline "$transformsInv" -o "${T1nativepro_in_func}" -v --float
  antsApplyTransforms -d 3 -i "${func_brain}" -r "${t1bold2}" -n BSpline -t "$SyN_func_warp" -t "$SyN_func_affine" -o "${func_in_T1nativepro}" -v --float
  antsApplyTransforms -d 3 -i "${T1nativepro_brain}" -r "${func_brain}" -n BSpline -t ["$SyN_func_affine",1] -t "$SyN_func_Invwarp" -o "${T1nativepro_in_func}" -v --float

