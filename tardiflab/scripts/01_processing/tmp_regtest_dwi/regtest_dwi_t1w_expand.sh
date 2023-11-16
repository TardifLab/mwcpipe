#!/bin/bash
#
# Registers T1w & dwi images using multiple methods / parameter combinations in ANTs (flirt also compared)
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
  testdir=${datadir}/tmp_micapipe/02_proc-dwi/sub-${id}/ses-${SES}/tmpregtest_expand

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



#-------------------------------------------------------------------------------------------------------------#

# ------------------ ANTs REGISTRATION 1: no masks ---------------- #
# ANTs specific outputs
  meth="ants_1_nomask"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_dwi=${testdir}/${meth}/dwi
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_dwi} ]]  ; then mkdir -p ${testdir_dwi} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi


# Output files
  str_dwi_affine="${testdir_xfm}/${idBIDS}_space-dwi_from-dwi_to-nativepro_mode-image_desc-affine_"
  mat_dwi_affine="${str_dwi_affine}0GenericAffine.mat"

  dwi_SyN_str="${testdir_xfm}/${idBIDS}_space-dwi_from-dwi_to-dwi_mode-image_desc-SyN_"
  dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
  dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
  dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"

  T1nativepro_in_dwi="${testdir_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro.nii.gz"
  dwi_mask="${testdir_dwi}/${idBIDS}_space-dwi_desc-brain_mask.nii.gz"
  dwi_5tt="${testdir_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz"
  dwi_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-dwi.nii.gz" # Only for QC
  T1nativepro_in_dwi_brain="${testdir_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro-brain.nii.gz"
  T1nativepro_in_dwi_NL="${testdir_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro_SyN.nii.gz"

# ------------ LINEAR TRANSFORM ----------- #
  if [[ ! -f ${T1nativepro_in_dwi} ]] | [[ ! -f ${dwi_mask} ]] | [[ ! -f ${dwi_in_T1nativepro} ]] | [[ ! -f ${T1nativepro_in_dwi_brain} ]] | [[ ! -f ${T1nativepro_in_dwi_NL} ]] ; then

      # Options
    	centeralign="[${T1nativepro_brain},${dwi_b0},0]"           								# initializes registration by first aligning images by geometric center
      # AFFINE: dwi to T1w
	if [[ ! -f ${mat_dwi_affine} ]]  ; then
 	 	antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$dwi_b0" -o "$str_dwi_affine" -t a -n "$threads" -p d -i ${centeralign}
      	      # Apply T1w to dwi affine transformation
		antsApplyTransforms -d 3 -i "$T1nativepro" -r "$dwi_b0" -t ["$mat_dwi_affine",1] -o "$T1nativepro_in_dwi" -v -u int
	else
		echo "Subject ${id} already has a dwi to T1w affine"
	fi


      # Compute dwi binary mask
	if [[ ! -f ${dwi_mask} ]]  ; then
		antsApplyTransforms -d 3 -i "$MNI152_mask" -r "$dwi_b0" -n GenericLabel -t ["$mat_dwi_affine",1] -t ["$T1_MNI152_affine",1] -t "$T1_MNI152_InvWarp" -o ${testdir_tmp}/dwi_mask.nii.gz -v
        	maskfilter ${testdir_tmp}/dwi_mask.nii.gz erode -npass 1 "$dwi_mask"
	else
		echo "Subject ${id} already has a dwi mask"
	fi

# ------------- MSMT_CSD -------------- #
      # Recompute FODs using new dwi_mask (wmFOD used to compute SyN affine & warp)
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
            		mtnormalise "$fod_wm" "$fod_wmN" "$fod_gm" "$fod_gmN" "$fod_csf" "$fod_csfN" -nthreads "$threads" -mask "$dwi_mask"
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



# ------------------- NONLINEAR WARP ------------------- #
      # Apply brain mask to T1w in dwi space
	if [[ ! -f ${T1nativepro_in_dwi_brain} ]]  ; then
	        fslmaths "$T1nativepro_in_dwi" -mul "$dwi_mask" "$T1nativepro_in_dwi_brain"
	else
		echo "Subject ${id} already has a dwi brain"
	fi

      # Compute Syn warp & affine
	if [[ ! -f ${dwi_SyN_warp} ]]  ; then
		fod="${testdir_tmp}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.nii.gz"
		mrconvert -coord 3 0 "$fod_wmN" "$fod"
        	antsRegistrationSyN.sh -d 3 -m "$T1nativepro_in_dwi_brain" -f "$fod" -o "$dwi_SyN_str" -t s -n "$threads"
	else
		echo "Subject ${id} already has a Syn warp & affine transform"
	fi

      # Apply transformation DWI-b0 space to T1nativepro
        antsApplyTransforms -d 3 -r "$T1nativepro_brain" -i "$dwi_b0" -t ${mat_dwi_affine} -t [${dwi_SyN_affine},1] -t ${dwi_SyN_Invwarp} -o "$dwi_in_T1nativepro" -v -u int
      # Apply transformation T1nativepro to DWI space
        antsApplyTransforms -d 3 -r "$fod" -i "$T1nativepro" -t ${dwi_SyN_warp} -t ${dwi_SyN_affine} -t [${mat_dwi_affine},1] -o "$T1nativepro_in_dwi_NL" -v -u int
      # Apply transformation 5TT to DWI space
        antsApplyTransforms -d 3 -r "$fod" -i "$T15ttgen" -t ${dwi_SyN_warp} -t ${dwi_SyN_affine} -t [${mat_dwi_affine},1] -o "$dwi_5tt" -v -e 3 -n linear

  else
    	echo "Subject ${id} has already completed registration with ANTs"
  fi



#-------------------------------------------------------------------------------------------------------------#

# ------------------ ANTs REGISTRATION 2: + translation step ---------------- #
# ANTs specific outputs
  meth="ants_2_trans"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_dwi=${testdir}/${meth}/dwi
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_dwi} ]]  ; then mkdir -p ${testdir_dwi} ; fi
  if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi


# Output files
  str_dwi_affine="${testdir_xfm}/${idBIDS}_space-dwi_from-dwi_to-nativepro_mode-image_desc-affine_"
  mat_dwi_affine="${str_dwi_affine}0GenericAffine.mat"

  dwi_SyN_str="${testdir_xfm}/${idBIDS}_space-dwi_from-dwi_to-dwi_mode-image_desc-SyN_"
  dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
  dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
  dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"

  T1nativepro_in_dwi="${testdir_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro.nii.gz"
  dwi_mask="${testdir_dwi}/${idBIDS}_space-dwi_desc-brain_mask.nii.gz"
  dwi_5tt="${testdir_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz"
  dwi_in_T1nativepro="${testdir_anat}/${idBIDS}_space-nativepro_desc-dwi.nii.gz" # Only for QC
  T1nativepro_in_dwi_brain="${testdir_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro-brain.nii.gz"
  T1nativepro_in_dwi_NL="${testdir_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro_SyN.nii.gz"

# ------------ LINEAR TRANSFORM ----------- #
  if [[ ! -f ${T1nativepro_in_dwi} ]] | [[ ! -f ${dwi_mask} ]] | [[ ! -f ${dwi_in_T1nativepro} ]] | [[ ! -f ${T1nativepro_in_dwi_brain} ]] | [[ ! -f ${T1nativepro_in_dwi_NL} ]] ; then

      # Options
        centeralign="[${T1nativepro_brain},${dwi_b0},0]"                                                                        # initializes registration by first aligning images by geometric center
      # AFFINE: dwi to T1w
        if [[ ! -f ${mat_dwi_affine} ]]  ; then
                antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$dwi_b0" -o "$str_dwi_affine" -t a -n "$threads" -p d -i ${centeralign}
              # Apply T1w to dwi affine transformation
                antsApplyTransforms -d 3 -i "$T1nativepro" -r "$dwi_b0" -t ["$mat_dwi_affine",1] -o "$T1nativepro_in_dwi" -v -u int
        else
                echo "Subject ${id} already has a dwi to T1w affine"
        fi


      # Compute dwi binary mask
        if [[ ! -f ${dwi_mask} ]]  ; then
                antsApplyTransforms -d 3 -i "$MNI152_mask" -r "$dwi_b0" -n GenericLabel -t ["$mat_dwi_affine",1] -t ["$T1_MNI152_affine",1] -t "$T1_MNI152_InvWarp" -o ${testdir_tmp}/dwi_mask.nii.gz -v
                maskfilter ${testdir_tmp}/dwi_mask.nii.gz erode -npass 1 "$dwi_mask"
        else
                echo "Subject ${id} already has a dwi mask"
        fi

# ------------- MSMT_CSD -------------- #
      # Recompute FODs using new dwi_mask (wmFOD used to compute SyN affine & warp)
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
                        mtnormalise "$fod_wm" "$fod_wmN" "$fod_gm" "$fod_gmN" "$fod_csf" "$fod_csfN" -nthreads "$threads" -mask "$dwi_mask"
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


# ------------------- NONLINEAR WARP ------------------- #
      # Apply brain mask to T1w in dwi space
        if [[ ! -f ${T1nativepro_in_dwi_brain} ]]  ; then
                fslmaths "$T1nativepro_in_dwi" -mul "$dwi_mask" "$T1nativepro_in_dwi_brain"
        else
                echo "Subject ${id} already has a dwi brain"
        fi

      # Compute Syn warp & affine
        if [[ ! -f ${dwi_SyN_warp} ]]  ; then
                fod="${testdir_tmp}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.nii.gz"
                mrconvert -coord 3 0 "$fod_wmN" "$fod"
                antsRegistrationSyN.sh -d 3 -m "$T1nativepro_in_dwi_brain" -f "$fod" -o "$dwi_SyN_str" -t s -n "$threads"
        else
                echo "Subject ${id} already has a Syn warp & affine transform"
        fi

      # Apply transformation DWI-b0 space to T1nativepro
        antsApplyTransforms -d 3 -r "$T1nativepro_brain" -i "$dwi_b0" -t ${mat_dwi_affine} -t [${dwi_SyN_affine},1] -t ${dwi_SyN_Invwarp} -o "$dwi_in_T1nativepro" -v -u int
      # Apply transformation T1nativepro to DWI space
        antsApplyTransforms -d 3 -r "$fod" -i "$T1nativepro" -t ${dwi_SyN_warp} -t ${dwi_SyN_affine} -t [${mat_dwi_affine},1] -o "$T1nativepro_in_dwi_NL" -v -u int
      # Apply transformation 5TT to DWI space
        antsApplyTransforms -d 3 -r "$fod" -i "$T15ttgen" -t ${dwi_SyN_warp} -t ${dwi_SyN_affine} -t [${mat_dwi_affine},1] -o "$dwi_5tt" -v -e 3 -n linear

  else
        echo "Subject ${id} has already completed registration with ANTs"
  fi
















#----------------------------------------------------------------------------------------------#

## --------------  FLIRT AFFINE ----------------- #

# Flirt specific dirs
  meth="flirt_affine"
  testdir_xfm=${testdir}/${meth}/xfms
  testdir_anat=${testdir}/${meth}/anat
  testdir_dwi=${testdir}/${meth}/dwi
  testdir_tmp=${testdir}/${meth}/tmp

  if [[ ! -d ${testdir_xfm} ]] ; then mkdir -p ${testdir_xfm} ; fi
  if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  if [[ ! -d ${testdir_dwi} ]] ; then mkdir -p ${testdir_dwi} ; fi
  if [[ ! -d ${testdir_tmp} ]] ; then mkdir -p ${testdir_tmp} ; fi

  # Transforms and necessary derivatives
    affine_flirt_dwi_to_t1w_initial=${testdir_xfm}/${idBIDS}_initial.mat
    affine_flirt_dwi_to_t1w=${testdir_xfm}/${idBIDS}_dwi_to_t1w_bbr.mat
    affine_flirt_t1w_to_dwi=${testdir_xfm}/${idBIDS}_t1w_to_dwi_bbr.mat
    tmp_wmseg=${testdir_anat}/${idBIDS}_wm.nii.gz

  # Output files
    tmp_dwi_in_t1w=${testdir_anat}/${idBIDS}_dwi_in_t1w.nii.gz
    tmp_t1w_in_dwi=${testdir_dwi}/${idBIDS}_t1w_in_dwi.nii.gz
    tmp_t1w_brain_in_dwi=${testdir_dwi}/${idBIDS}_t1w_brain_in_dwi.nii.gz
    tmp_5tt_in_dwi=${testdir_dwi}/${idBIDS}_5TT_in_dwi.nii.gz

  if [[ ! -f ${tmp_dwi_in_t1w} ]] | [[ ! -f ${tmp_t1w_in_dwi} ]]; then

      # Affine dwi to T1w using flirt
        flirt -v -dof 6 -in "$dwi_b0" -ref "$T1nativepro_brain" -omat $affine_flirt_dwi_to_t1w_initial
        mrconvert $T15ttgen $tmp_wmseg -coord 3 2 -force

        flirt -v -dof 6 -in $dwi_b0 -ref $T1nativepro_brain -omat $affine_flirt_dwi_to_t1w \
                     -cost bbr \
                     -wmseg $tmp_wmseg \
                     -init $affine_flirt_dwi_to_t1w_initial \
                     -out $tmp_dwi_in_t1w \
                     -schedule $FSLDIR/etc/flirtsch/bbr.sch

      # Compute inverse to use for T1w to dwi space
        convert_xfm -omat $affine_flirt_t1w_to_dwi -inverse $affine_flirt_dwi_to_t1w
        flirt -v -applyxfm -init $affine_flirt_t1w_to_dwi -in $T1nativepro_brain -ref $dwi_b0 -out $tmp_t1w_brain_in_dwi
	flirt -v -applyxfm -init $affine_flirt_t1w_to_dwi -in $T1nativepro -ref $dwi_b0 -out $tmp_t1w_in_dwi
	flirt -v -applyxfm -init $affine_flirt_t1w_to_dwi -in $T15ttgen -ref $dwi_b0 -out $tmp_5tt_in_dwi

  else
        echo "FLIRT AFFINE registration already completed for ${id}"
  fi

