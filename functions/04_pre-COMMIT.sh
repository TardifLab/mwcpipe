#!/bin/bash
#
# Setting up necessary images and registrations for COMMIT processing:
# 
# preprocessing workflow for tract-specific results.
#
# This workflow makes use of MRtrix3 and COMMIT framework (https://github.com/daducci/COMMIT)
#
# Atlas an templates are avaliable from:
#
# https://github.com/MICA-MNI/micaopen/templates
#
#   ARGUMENTS order:
#   $1 : BIDS directory
#   $2 : participant
#   $3 : Out parcDirectory
#
BIDS=$1
id=$2
out=$3
SES=$4
nocleanup=$5
threads=$6
tmpDir=$7
MVFalpha_list=$8
MySD=$9
gratio=${10}
gratiotractometry=${11}
MTsat=${12}
PROC=${13}
here=$(pwd)

#------------------------------------------------------------------------------#
# qsub configuration
if [ "$PROC" = "qsub-MICA" ] || [ "$PROC" = "qsub-all.q" ];then
    export MICAPIPE=/data_/mica1/01_programs/micapipe
    source "${MICAPIPE}/functions/init.sh" "$threads"
fi

# source utilities
source "$MICAPIPE/functions/utilities.sh"

# Assigns variables names
bids_variables "$BIDS" "$id" "$out" "$SES"

# Check inputs
dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"
dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"

if [[ ! -f $dwi_SyN_affine  ]] && [[ $MySD == "TRUE" || $gratio == "TRUE" || $gratiotractometry == "TRUE" ]]; then Error "Subject $id doesn't have a DWI to T1w registration:\n\t\tRUN -proc_DWI"; exit; fi
if [[ ! -f $MTsat  ]] && [[ $MySD == "TRUE" || $gratio == "TRUE" || $gratiotractometry == "TRUE" ]]; then Error "Subject $id's MTsat image does not exist:\n\t\tCheck -MTsat flag"; exit; fi
#------------------------------------------------------------------------------#
Title "\tTract-specific processing set up\n\t\tmicapipe $Version, $PROC"
micapipe_software

#	Timer
aloita=$(date +%s)
Nparc=0

# Create script specific temp directory
tmp=${tmpDir}/04_pre-COMMIT/${subject}/${SES}
Do_cmd mkdir -p "$tmp"

# TRAP in case the script fails
trap 'cleanup $tmp $nocleanup $here' SIGINT SIGTERM

#------------------------------------------------------------------------------#
# Registering MTsat to DWI space. MTsat_in_dwi and it's transform will be used
# in 04_proc-COMMIT.sh

MTsat_in_dwi="${proc_dwi}/${idBIDS}_space-dwi_desc-SyN_MTsat.nii.gz"
dwi_b0="${proc_dwi}/${idBIDS}_space-dwi_desc-b0.nii.gz"

if [[ ${gratio}  == "TRUE" || ${MySD}  == "TRUE" || ${gratiotractometry}  == "TRUE" ]] && [[ ! -f $MTsat_in_dwi ]]; then Info "Prepping MySD inputs"
    MTsat_nz="${tmp}/${idBIDS}_MTsat.nii.gz"
    MTsat_brain="${tmp}/${idBIDS}_MTsat_Brain.nii.gz"
    MTsat2T1w_str="${dir_warp}/${idBIDS}_MTsat_to-nativepro_mode-image_desc-affine_"
    MTsat2T1w_affine="${MTsat2T1w_str}0GenericAffine.mat"
    Do_cmd fslmaths $MTsat -nan -thr 0 -uthr 10 $MTsat_nz ###### Not sure how to deal with this line...
    Do_cmd bet $MTsat_nz $MTsat_brain -f 0.35
    Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$MTsat_brain" -o "$MTsat2T1w_str" -t a -n "$threads" -p d
    Do_cmd antsApplyTransforms -d 3 -i "$MTsat_nz" -r "$dwi_b0" -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$MTsat2T1w_affine" -o "$MTsat_in_dwi" -v
fi

#------------------------------------------------------------------------------#
# If the subject is used for MVF calibration through COMMIT, the splenium is 
# extracted to a folder for later computation in 04_proc-COMMIT.sh

alpha_COMMIT=${tmpDir}/04_proc-COMMIT/alpha_calibration_COMMIT.txt

if [[ ${MySD}  == "TRUE" || ${gratio}  == "TRUE" ]] && [[ ! -f "$alpha_COMMIT" ]]; then
    if [[ ! -d "${tmpDir}/MVF_calc" ]]; then
        Do_cmd mkdir ${tmpDir}/MVF_calc
    fi

    cat $MVFalpha_list|while read line; do
        if [[ ${idBIDS} == $line ]]; then  
            Do_cmd antsApplyTransforms -d 3 -n NearestNeighbor \
                -i "${MICAPIPE}/tardiflab/scripts/01_processing/MVFcalc_scripts/splenium.nii.gz" \
                -r "${proc_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro_SyN.nii.gz" \
                -t "${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_1Warp.nii.gz" \
                -t "${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_0GenericAffine.mat" \
                -t ["${dir_warp}/${idBIDS}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_0GenericAffine.mat",1] \
                -t "${dir_warp}/${idBIDS}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_1InverseWarp.nii.gz" \
                -o "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$MTsat_in_dwi" -nan "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_MTsat_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "${proc_dwi}/COMMIT_init/dict/Results_StickZeppelinBall_AdvancedSolvers/compartment_IC.nii.gz" -nan "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_ICVF_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "${proc_dwi}/${idBIDS}_space-dwi_model-DTI_map-FA.nii.gz" -nan "${tmpDir}/MVF_calc/${idBIDS}_space-dwi_FA_MNI152_1mm_splenium.nii.gz"
        fi
    done
fi

# -----------------------------------------------------------------------------#
# NODDI is required to compute voxel-wise g-ratio maps and to perform 
# tractometry

if [[ "$gratiotractometry" == "TRUE" ]]; then

    NODDI_dir="${proc_dwi}/NODDI_AMICO"
    NODDI_NDI=$NODDI_dir/AMICO/NODDI/fit_NDI_up.nii.gz
    dwi_COR="${proc_dwi}/${idBIDS}_space-dwi_desc-dwi_preproc.mif"
    dwi_COR_nii="${tmp}/${idBIDS}_space-dwi_desc-dwi_preproc.nii.gz"
    dwi_COR_mask="${tmp}/${idBIDS}_space-dwi_desc-b0_brain_mask.nii.gz"
    bvecs=${tmp}/${idBIDS}_bvecs.txt 
    bvals=${tmp}/${idBIDS}_bvals.txt

    if [[ ! -f "$NODDI_NDI" ]]; then
        Info "Calculating NODDI metrics"
        AMICO_py=${MICAPIPE}/tardiflab/scripts/01_processing/AMICO/NODDI.py
        dwi_mif=${proc_dwi}/${idBIDS}_space-dwi_desc-dwi_preproc.mif
        dwi_nii=${tmp}/${idBIDS}_dwi.nii.gz
        bvecs=${tmp}/${idBIDS}_bvecs.txt
        bvals=${tmp}/${idBIDS}_bvals.txt
     	Do_cmd mrconvert $dwi_mif -export_grad_fsl $bvecs $bvals $dwi_nii -force
        Do_cmd dwi2mask $dwi_mif ${tmp}/${idBIDS}_brain_mask.nii.gz -force

        /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $AMICO_py $idBIDS $proc_dwi $tmp

        voxel=($(mrinfo $MTsat_in_dwi -spacing))
        Do_cmd mrgrid $NODDI_dir/AMICO/NODDI/fit_NDI.nii.gz regrid -voxel $voxel $NODDI_dir/AMICO/NODDI/fit_NDI_up.nii.gz
        Do_cmd mrgrid $NODDI_dir/AMICO/NODDI/fit_FWF.nii.gz regrid -voxel $voxel $NODDI_dir/AMICO/NODDI/fit_FWF_up.nii.gz
    else
        Info "Subject ${id} has NODDI metrics"; ((Nsteps++))
    fi

fi

#------------------------------------------------------------------------------#
# If the subject is used for MVF calibration through NODDI, the splenium is 
# extracted to a folder for later computation in 04_proc-COMMIT.sh

alpha_NODDI=${tmpDir}/04_proc-COMMIT/alpha_calibration_NODDI.txt

if [[ ${gratiotractometry}  == "TRUE" ]] && [[ ! -f "$alpha_NODDI" ]]; then
    if [[ ! -d "${tmpDir}/MVFNODDI_calc" ]]; then
        Do_cmd mkdir ${tmpDir}/MVFNODDI_calc
    fi

    cat $MVFalpha_list|while read line; do
        if [[ ${idBIDS} == $line ]]; then 
            Do_cmd antsApplyTransforms -d 3 -n NearestNeighbor \
                -i "${MICAPIPE}/tardiflab/scripts/01_processing/MVFcalc_scripts/splenium.nii.gz" \
                -r "${proc_dwi}/${idBIDS}_space-dwi_desc-t1w_nativepro_SyN.nii.gz" \
                -t "${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_1Warp.nii.gz" \
                -t "${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_0GenericAffine.mat" \
                -t ["${dir_warp}/${idBIDS}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_0GenericAffine.mat",1] \
                -t "${dir_warp}/${idBIDS}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_1InverseWarp.nii.gz" \
                -o "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$MTsat_in_dwi" -nan "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_MTsat_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "${proc_dwi}/NODDI_AMICO/AMICO/NODDI/fit_NDI_up.nii.gz" -nan "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_ICVF_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "${proc_dwi}/NODDI_AMICO/AMICO/NODDI/fit_FWF_up.nii.gz" -nan "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_FWF_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "${proc_dwi}/${idBIDS}_space-dwi_model-DTI_map-FA.nii.gz" -nan "${tmpDir}/MVFNODDI_calc/${idBIDS}_space-dwi_FA_MNI152_1mm_splenium.nii.gz"



        fi
    done
fi

# -----------------------------------------------------------------------------------------------
# QC notification of completition
lopuu=$(date +%s)
eri=$(echo "$lopuu - $aloita" | bc)
eri=$(echo print "$eri"/60 | perl)

# Notification of completition
Title "Tract-specific pre-COMMIT processing ended in \033[38;5;220m $(printf "%0.3f\n" "$eri") minutes \033[38;5;141m:
\tSteps completed : $(printf "%02d" "$Nparc")/$(printf "%02d" "$N")
\tStatus          : Finished
\tCheck logs      : $(ls "$dir_logs"/pre_COMMIT_*.txt)"
# Print QC stamp
grep -v "${id}, ${SES/ses-/}, pre_COMMIT" "${out}/micapipe_processed_sub.csv" > "${tmp}/tmpfile" && mv "${tmp}/tmpfile" "${out}/micapipe_processed_sub.csv"
echo "${id}, ${SES/ses-/}, pre_COMMIT, ${status}, $(printf "%02d" "$Nparc")/$(printf "%02d" "$N"), $(whoami), $(uname -n), $(date), $(printf "%0.3f\n" "$eri"), ${PROC}, ${Version}" >> "${out}/micapipe_processed_sub.csv"
cleanup "$tmp" "$nocleanup" "$here"
