#!/bin/bash
#
# DWI POST processing using COMMIT with bash:
#
# POST processing workflow for tract-specific results.
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
MTsat_in_dwi=${11}
<<comment
MTR-dual=TRUE/FALSE or location?
comment
PROC=${12}
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

# Check inputs: DWI post TRACTOGRAPHY
COMMIT2_tck=${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography_COMMIT2-filtered.tck
dwi_b0="${proc_dwi}/${idBIDS}_space-dwi_desc-b0.nii.gz"
tck_json=${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography.json
tracts=($(cat $tck_json | grep -oP '(?<="SeedingNumberMethod": ")[^"]*')) ### Could use jq in the future, but json file has a small bug

# Check inputs
if [ ! -f $dwi_b0  ]; then Error "Subject $id doesn't have b0 image:\n\t\tRUN -proc_dwi"; exit; fi
if [ ! -f $COMMIT2_tck  ]; then Error "Subject $id doesn't have a COMMIT2 filtered tck:\n\t\tRUN -SC"; exit; fi
if [[ ! -f $MVFalpha_list  ]] && [[ $MySD == "TRUE" || $gratio == "TRUE" ]]; then Warning "Subject $id has an alpha value to compute MVF from MTsat"; fi
if [[ ! -f $MTsat_in_dwi  ]] && [[ $MySD == "TRUE" || $gratio == "TRUE" ]]; then Error "Subject $id doesn't have a MTsat image registered in DWI space:\n\t\tRUN -SC with -tractometry"; exit; fi

#------------------------------------------------------------------------------#
Title "\tTract-specific processing\n\t\tmicapipe $Version, $PROC"
micapipe_software

#	Timer
aloita=$(date +%s)
Nparc=0

# Create script specific temp directory
tmp=${tmpDir}/04_COMMIT/${subject}/${SES}
Do_cmd mkdir -p "$tmp"

# TRAP in case the script fails
trap 'cleanup $tmp $nocleanup $here' SIGINT SIGTERM

# -----------------------------------------------------------------------------------------------


<<to_do
for micapipe - need to add the MTsat image, or find it
run MTR
to_do

# -----------------------------------------------------------------------------------------------
# Computing alpha for MVF
alpha=${tmpDir}/04_COMMIT/alpha.txt
if [[ ${MySD}  == "TRUE" || ${gratio}  == "TRUE" ]] && [[ ! -f "$alpha" ]]; then
    Info "Calculating alpha for MTsat to MVF scaling"
    if [[ ! -d "${tmpDir}/MVF_calc" ]]; then
        Do_cmd mkdir ${tmpDir}/MVF_calc
        cat $MVFalpha_list|while read line; do
            IFS='_' read -r -a array <<< "${line}"
            alpha_sub="${array[0]}"
            alpha_ses="${array[1]}"
            Do_cmd antsApplyTransforms -d 3 -n NearestNeighbor \
                   -i "${MICAPIPE}/tardiflab/scripts/01_processing/MVFcalc_scripts/splenium.nii.gz" \
                   -r "$out/$alpha_sub/$alpha_ses/dwi/${alpha_sub}_${alpha_ses}_space-dwi_desc-t1w_nativepro_SyN.nii.gz" \
                   -t "$out/$alpha_sub/$alpha_ses/xfm/${alpha_sub}_${alpha_ses}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_1Warp.nii.gz" \
                   -t "$out/$alpha_sub/$alpha_ses/xfm/${alpha_sub}_${alpha_ses}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_0GenericAffine.mat" \
                   -t ["$out/$alpha_sub/$alpha_ses/xfm/${alpha_sub}_${alpha_ses}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_0GenericAffine.mat",1] \
                   -t "$out/$alpha_sub/$alpha_ses/xfm/${alpha_sub}_${alpha_ses}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_1InverseWarp.nii.gz" \
                   -o "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/${alpha_sub}_${alpha_ses}_space-dwi_desc-MTsat_SyN.nii.gz" -nan "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MTsat_MNI152_1mm_splenium.nii.gz" #### MTsat file location for all subjects was hard-coded.
            Do_cmd fslmaths "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/COMMIT2/dict/Results_StickZeppelinBall_COMMIT2/compartment_IC.nii.gz" -nan "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_ICVF_MNI152_1mm_splenium.nii.gz"
            Do_cmd fslmaths "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/${alpha_sub}_${alpha_ses}_space-dwi_model-DTI_map-FA.nii.gz" -nan "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_FA_MNI152_1mm_splenium.nii.gz"
        done
        matlab -nodisplay -r "addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/MVFcalc_scripts')); alpha = get_alpha('$tmpDir','$MVFalpha_list'); save('$tmpDir/04_COMMIT/alpha.txt', 'alpha', '-ASCII'); exit"
        Do_cmd rm -r ${tmpDir}/MVF_calc
    else
        until [ -f $alpha ]; do Info "Alpha computation for MTsat to MVF scaling is already in progress, waiting 10 min for it to finish"; sleep 10m; done

    fi
else
    Info "Alpha has already been calculated for MTsat to MVF scaling"
fi

# -----------------------------------------------------------------------------------------------
# MySD filtering and weighting for tract-specific myelin volume 

MVF_in_dwi="${proc_dwi}/${idBIDS}_space-dwi_desc-MVFmap.nii.gz"
MySD_tck="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-filtered.tck"
MySD_length="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-filtered_length.txt"
MySD_weights="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-filtered_weights.txt"
MySD_weighttimeslength="$proc_dwi/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-filtered_volume.txt"

if [[ ${gratio}  == "TRUE" || ${MySD}  == "TRUE" ]] && [[ ! -f $MySD_weighttimeslength ]]; then Info "Prepping MySD inputs"

    MTsat_in_dwi=${proc_dwi}/${idBIDS}_space-dwi_desc-MTsat_SyN.nii.gz
    MySD=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/MySD.py
    weights_MySD=${proc_dwi}/MySD/Results_VolumeFractions/streamline_weights.txt

    f_5tt=${proc_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz
    wm_mask=${tmp}/${idBIDS}_dwi_wm_mask.nii.gz

 	Do_cmd mrconvert -coord 3 2 -axes 0,1,2 $f_5tt $wm_mask
    alpha=$(cat $tmpDir/04_COMMIT/alpha.txt)
    Do_cmd fslmaths $MTsat_in_dwi -mul $alpha $MVF_in_dwi

    while [[ ! -f $weights_MySD  ]] ; do
    Info "Running MySD"
 	/data_/tardiflab/wenda/programs/localpython/bin/python3.10 $MySD $idBIDS $proc_dwi $tmp $COMMIT2_tck
    # Removing streamlines whose weights are too low
  	Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_MySD -tck_weights_out $MySD_weights $COMMIT2_tck $MySD_tck -force
    # Testing if MySD ran into any issues
    tmptckcount=$(tckinfo $MySD_tck -count)
    if [[ "${tmptckcount##* }" -eq 0 ]]; then
        rm -r "${proc_dwi}/MySD"
    fi
    done

    Info "Getting DK85 parcellation"
    # Converting aparc+aseg parcellation  
    Do_cmd mri_convert ${dir_freesurfer}/mri/aparc+aseg.mgz $tmp/aparc+aseg.nii.gz --out_orientation LAS
    Do_cmd labelconvert $tmp/aparc+aseg.nii.gz $FREESURFER_HOME/FreeSurferColorLUT.txt $mrtrixDir/share/mrtrix3/labelconvert/fs_default_Bstem.txt $tmp/nodes.nii.gz
    # Getting necessary files for labelsgmfix
    Do_cmd mri_convert ${dir_freesurfer}/mri/brain.mgz $tmp/T1_brain_mask_FS.nii.gz --out_orientation LAS
    Do_cmd mri_convert ${dir_freesurfer}/mri/orig_nu.mgz $tmp/T1_nucorr_FS.nii.gz --out_orientation LAS
    Do_cmd fslmaths $tmp/T1_brain_mask_FS.nii.gz -bin $tmp/T1_brain_mask_FS.nii.gz
    Do_cmd fslmaths $tmp/T1_nucorr_FS.nii.gz -mul $tmp/T1_brain_mask_FS.nii.gz $tmp/T1_brain_FS.nii.gz
    # TEMPORARILY SET SUN GRID ENGINE (SGE_ROOT) ENV VARIABLE EMPTY TO OVERCOME LABELSGMFIX HANGING
    SGE_ROOT= 
    Do_cmd labelsgmfix $tmp/nodes.nii.gz $tmp/T1_brain_FS.nii.gz $mrtrixDir/share/mrtrix3/labelconvert/fs_default_Bstem.txt $tmp/nodes_fixSGM.nii.gz -sgm_amyg_hipp -premasked
    # RESTORE SGE_ROOT TO CURRENT VALUE... MIGHT NEED TO BE MODIFIED
    SGE_ROOT=/opt/sge
    # Move parcel from T1 space to diffusion space
    t1_fs_str="${tmp}/${idBIDS}_fs_to-nativepro_mode-image_desc_"
    t1_fs_affine="${t1_fs_str}0GenericAffine.mat"
    dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"
    dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
    dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
    dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"

    Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$tmp/T1_brain_FS.nii.gz" -o "$t1_fs_str" -t a -n "$threads" -p d
    Do_cmd antsApplyTransforms -d 3 -r $dwi_b0 -i $tmp/nodes_fixSGM.nii.gz -n GenericLabel -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_fs_affine" -o $tmp/${idBIDS}_DK-85-full_dwi.nii.gz -v 

    # Getting density statistics
	Do_cmd tck2connectome -nthreads $threads $MySD_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz $proc_dwi/nos_mysd.txt -symmetric -zero_diagonal -quiet -force
    # Getting streamline length
    Do_cmd tckstats $MySD_tck -dump $MySD_length -force
    # Getting streamline myelin volume
    matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT')); MySD_weighttimeslength = weight_times_length('$MySD_weights','$MySD_length'); save('$MySD_weighttimeslength', 'MySD_weighttimeslength', '-ASCII'); exit"

    if [ "$nocleanup" == "FALSE" ]; then
        # Cleaning up tmp files
        rm -r ${proc_dwi}/MySD/dict*
    fi

    else Info "MySD weights were already multiplied by length or this option was not selected"; 
fi

# -----------------------------------------------------------------------------------------------
# COMMIT refiltering and weighting for tract-specific axonal volume 

COMMIT_tck="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-COMMIT-filtered.tck"
COMMIT_length="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-COMMIT-filtered_length.txt"
COMMIT_weights="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-COMMIT-filtered_weights.txt"
COMMIT_weighttimeslength="$proc_dwi/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-MySD-COMMIT-filtered_volume.txt"

if [[ ${gratio}  == "TRUE" ]] && [[ ! -f $COMMIT_weighttimeslength ]]; then Info "Prepping COMMIT inputs"

    COMMIT=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/COMMIT.py
    weights_COMMIT=${proc_dwi}/COMMIT/dict/Results_StickZeppelinBall_AdvancedSolvers/streamline_weights.txt

    dwi_up_mif="${proc_dwi}/${idBIDS}_space-dwi_desc-dwi_preproc_upscaled.mif"
    wm_fod_mif="${proc_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.mif"
    wm_fod_json=${tmp}/${idBIDS}_wm_fod_norm.json
    wm_fod_nii=${tmp}/${idBIDS}_wm_fod_norm.nii.gz
    f_5tt=${proc_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz
    wm_mask=${tmp}/${idBIDS}_dwi_wm_mask.nii.gz
    dwi_up_nii=${tmp}/${idBIDS}_dwi_upscaled.nii.gz
    bvecs=${tmp}/${idBIDS}_bvecs.txt
    bvals=${tmp}/${idBIDS}_bvals.txt

 	Info "Getting NIFTI files for COMMIT"
 	Do_cmd mrconvert $wm_fod_mif -json_export $wm_fod_json $wm_fod_nii -force
 	Do_cmd mrconvert -coord 3 2 -axes 0,1,2 $f_5tt $wm_mask -force 
 	Do_cmd mrconvert $dwi_up_mif -export_grad_fsl $bvecs $bvals $dwi_up_nii -force

    while [[ ! -f $weights_COMMIT  ]] ; do
    Info "Running COMMIT"
 	/data_/tardiflab/wenda/programs/localpython/bin/python3.10 $COMMIT $idBIDS $proc_dwi $tmp $MySD_tck
    # Removing streamlines whose weights are too low
  	Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_COMMIT -tck_weights_out $COMMIT_weights $MySD_tck $COMMIT_tck -force
    # Testing if COMMIT ran into any issues
    tmptckcount=$(tckinfo $COMMIT_tck -count)
    if [[ "${tmptckcount##* }" -eq 0 ]]; then
        rm -r "${proc_dwi}/COMMIT"
    fi
    done

    if [[ ! -f $tmp/${idBIDS}_DK-85-full_dwi.nii.gz ]]; then Info "Getting DK85 parcellation"
        # Converting aparc+aseg parcellation  
        Do_cmd mri_convert ${dir_freesurfer}/mri/aparc+aseg.mgz $tmp/aparc+aseg.nii.gz --out_orientation LAS
        Do_cmd labelconvert $tmp/aparc+aseg.nii.gz $FREESURFER_HOME/FreeSurferColorLUT.txt $mrtrixDir/share/mrtrix3/labelconvert/fs_default_Bstem.txt $tmp/nodes.nii.gz
        # Getting necessary files for labelsgmfix
        Do_cmd mri_convert ${dir_freesurfer}/mri/brain.mgz $tmp/T1_brain_mask_FS.nii.gz --out_orientation LAS
        Do_cmd mri_convert ${dir_freesurfer}/mri/orig_nu.mgz $tmp/T1_nucorr_FS.nii.gz --out_orientation LAS
        Do_cmd fslmaths $tmp/T1_brain_mask_FS.nii.gz -bin $tmp/T1_brain_mask_FS.nii.gz
        Do_cmd fslmaths $tmp/T1_nucorr_FS.nii.gz -mul $tmp/T1_brain_mask_FS.nii.gz $tmp/T1_brain_FS.nii.gz
        # TEMPORARILY SET SUN GRID ENGINE (SGE_ROOT) ENV VARIABLE EMPTY TO OVERCOME LABELSGMFIX HANGING
        SGE_ROOT= 
        Do_cmd labelsgmfix $tmp/nodes.nii.gz $tmp/T1_brain_FS.nii.gz $mrtrixDir/share/mrtrix3/labelconvert/fs_default_Bstem.txt $tmp/nodes_fixSGM.nii.gz -sgm_amyg_hipp -premasked
        # RESTORE SGE_ROOT TO CURRENT VALUE... MIGHT NEED TO BE MODIFIED
        SGE_ROOT=/opt/sge
        # Move parcel from T1 space to diffusion space
        t1_fs_str="${tmp}/${idBIDS}_fs_to-nativepro_mode-image_desc_"
        t1_fs_affine="${t1_fs_str}0GenericAffine.mat"
        dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"
        dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
        dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
        dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"

        Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$tmp/T1_brain_FS.nii.gz" -o "$t1_fs_str" -t a -n "$threads" -p d
        Do_cmd antsApplyTransforms -d 3 -r $dwi_b0 -i $tmp/nodes_fixSGM.nii.gz -n GenericLabel -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_fs_affine" -o $tmp/${idBIDS}_DK-85-full_dwi.nii.gz -v 
    fi

    # Getting density statistics
	Do_cmd tck2connectome -nthreads $threads $COMMIT_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz $proc_dwi/nos_commit.txt -symmetric -zero_diagonal -quiet -force
    # Getting streamline length
    Do_cmd tckstats $COMMIT_tck -dump $COMMIT_length -force
    # Getting streamline myelin volume
    matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT')); COMMIT_weighttimeslength = weight_times_length('$COMMIT_weights','$COMMIT_length'); save('$COMMIT_weighttimeslength', 'COMMIT_weighttimeslength', '-ASCII'); exit"

    if [ "$nocleanup" == "FALSE" ]; then
        # Cleaning up tmp files
        rm -r ${proc_dwi}/COMMIT/dict/dict*
    fi

    else Info "COMMIT weights were already multiplied by length"; 
fi

# -----------------------------------------------------------------------------------------------
# MTR-DUAL_COMMIT filtering and weighting for tract-specific MTR



# -----------------------------------------------------------------------------------------------
# Connectomes generation 
parcellations=($(find "${dir_volum}" -name "*.nii.gz" ! -name "*cerebellum*" ! -name "*subcortical*"))
dwi_cere="${proc_dwi}/${idBIDS}_space-dwi_atlas-cerebellum.nii.gz"
dwi_subc="${proc_dwi}/${idBIDS}_space-dwi_atlas-subcortical.nii.gz"
lut_sc="${util_lut}/lut_subcortical-cerebellum_mics.csv"

if [[ ${MySD}  == "TRUE" ]] || [[ ${gratio}  == "TRUE" ]]; then
    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str_MySD="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}_desc-iFOD2-${tracts}-COMMIT2-MySD-filtered-"
        lut="${util_lut}/lut_${parc_name}_mics.csv"
        dwi_cortex="${tmp}/${id}_${parc_name}-cor_dwi.nii.gz" # Segmentation in dwi space

        if [[ ! -f "${connectome_str_MySD}myelin-cross-sectional-area_full-connectome.txt" ]] || [[ ! -f "${connectome_str_MySD}myelin-volume_full-connectome.txt" ]]; then

            dwi_all="${tmp}/${id}_${parc_name}-full_dwi.nii.gz"
            if [[ ! -f $dwi_all ]]; then Info "Building $parc_name cortical connectome"
                # Take parcellation into DWI space
                Do_cmd antsApplyTransforms -d 3 -e 3 -i "$seg" -r "$dwi_b0" -n GenericLabel "$trans_T12dwi" -o "$dwi_cortex" -v -u int
                # Remove the medial wall
                for i in 1000 2000; do Do_cmd fslmaths "$dwi_cortex" -thr "$i" -uthr "$i" -binv -mul "$dwi_cortex" "$dwi_cortex"; done
                Info "Building $parc_name cortical-subcortical connectome"
                dwi_cortexSub="${tmp}/${id}_${parc_name}-sub_dwi.nii.gz"
                Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_subc" -add "$dwi_cortex" "$dwi_cortexSub" -odt int #subcortical parcellation
                Info "Building $parc_name cortical-subcortical-cerebellum connectome"
                Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_cere" -add "$dwi_cortexSub" "$dwi_all" -odt int #cerebellar parcellation
            fi

            # Build the Cortical-Subcortical-Cerebellum connectomes
            Do_cmd tck2connectome -nthreads "$threads" "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-cross-sectional-area_full-connectome.txt" -tck_weights_in "$MySD_weights" -assignment_radial_search 2 -symmetric -zero_diagonal -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_MySD}myelin-cross-sectional-area_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

            Do_cmd tck2connectome -nthreads "$threads" "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-volume_full-connectome.txt" \
                -tck_weights_in "$MySD_weighttimeslength" -assignment_radial_search 2 -symmetric -zero_diagonal -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_MySD}myelin-volume_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

            Do_cmd tck2connectome -nthreads "$threads" "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-cross-sectional-area_node-norm_full-connectome.txt" -tck_weights_in "$MySD_weights" -assignment_radial_search 2 -symmetric -zero_diagonal -scale_invnodevol -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_MySD}myelin-cross-sectional-area_node-norm_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

            Do_cmd tck2connectome -nthreads "$threads" "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-volume_node-norm_full-connectome.txt" -tck_weights_in "$MySD_weighttimeslength" -assignment_radial_search 2 -symmetric -zero_diagonal -scale_invnodevol -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_MySD}myelin-volume_node-norm_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"
        else
              Info "Subject ${id} has myelin cross-sectional area/volume connectome in $parc_name";
        fi
    done
else Info "MySD annotated connectomes have already generated"; 
fi

if [[ ${gratio}  == "TRUE" ]]; then

    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str_COMMIT="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}_desc-iFOD2-${tracts}-COMMIT2-MySD-COMMIT-filtered-"
        connectome_str_MySD="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}_desc-iFOD2-${tracts}-COMMIT2-MySD-filtered-"
        lut="${util_lut}/lut_${parc_name}_mics.csv"
        dwi_cortex="${tmp}/${id}_${parc_name}-cor_dwi.nii.gz" # Segmentation in dwi space

        if [[ ! -f "${connectome_str_COMMIT}axonal-cross-sectional-area_full-connectome.txt" ]] || [[ ! -f "${connectome_str_COMMIT}axonal-volume_full-connectome.txt" ]] || [[ ! -f "${connectome_str_COMMIT}gratio_full-connectome.txt" ]]; then

            dwi_all="${tmp}/${id}_${parc_name}-full_dwi.nii.gz"
            if [[ ! -f $dwi_all ]]; then Info "Building $parc_name cortical connectome"
                # Take parcellation into DWI space
                Do_cmd antsApplyTransforms -d 3 -e 3 -i "$seg" -r "$dwi_b0" -n GenericLabel "$trans_T12dwi" -o "$dwi_cortex" -v -u int
                # Remove the medial wall
                for i in 1000 2000; do Do_cmd fslmaths "$dwi_cortex" -thr "$i" -uthr "$i" -binv -mul "$dwi_cortex" "$dwi_cortex"; done
                Info "Building $parc_name cortical-subcortical connectome"
                dwi_cortexSub="${tmp}/${id}_${parc_name}-sub_dwi.nii.gz"
                Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_subc" -add "$dwi_cortex" "$dwi_cortexSub" -odt int #subcortical parcellation
                Info "Building $parc_name cortical-subcortical-cerebellum connectome"
                Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_cere" -add "$dwi_cortexSub" "$dwi_all" -odt int #cerebellar parcellation
            fi

            # Build the Cortical-Subcortical-Cerebellum connectomes
            Do_cmd tck2connectome -nthreads "$threads" "$COMMIT_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-cross-sectional-area_full-connectome.txt" -tck_weights_in "$COMMIT_weights" -assignment_radial_search 2 -symmetric -zero_diagonal -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_COMMIT}axonal-cross-sectional-area_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

            Do_cmd tck2connectome -nthreads "$threads" "$COMMIT_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-volume_full-connectome.txt" \
                -tck_weights_in "$COMMIT_weighttimeslength" -assignment_radial_search 2 -symmetric -zero_diagonal -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_COMMIT}axonal-volume_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

            Do_cmd tck2connectome -nthreads "$threads" "$COMMIT_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-cross-sectional-area_node-norm_full-connectome.txt" -tck_weights_in "$COMMIT_weights" -assignment_radial_search 2 -symmetric -zero_diagonal -scale_invnodevol -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_COMMIT}axonal-cross-sectional-area_node-norm_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

            Do_cmd tck2connectome -nthreads "$threads" "$COMMIT_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-volume_node-norm_full-connectome.txt" -tck_weights_in "$COMMIT_weighttimeslength" -assignment_radial_search 2 -symmetric -zero_diagonal -scale_invnodevol -quiet
            Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${connectome_str_COMMIT}axonal-volume_node-norm_full-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

    		matlab -nodisplay -r "MVF = dlmread('${connectome_str_MySD}myelin-volume_full-connectome.txt'); AVF = dlmread('${connectome_str_COMMIT}axonal-volume_full-connectome.txt'); gratio = sqrt(1-MVF./(MVF+AVF)); gratio(isnan(gratio)) = 0; save('${connectome_str_COMMIT}gratio_full-connectome.txt', 'gratio', '-ASCII'); exit"

        else
              Info "Subject ${id} has tract-specific g-ratio-annotated connectome in $parc_name";
        fi
    done
fi
<<moretodo
if [[ ${MTR-dual}  == "TRUE" ]]; then

fi
moretodo
# -----------------------------------------------------------------------------------------------
# QC notification of completition
QC_SC
lopuu=$(date +%s)
eri=$(echo "$lopuu - $aloita" | bc)
eri=$(echo print "$eri"/60 | perl)

# Notification of completition
N="$(( 3 + ${#parcellations[*]} * 3))" ##### Need to update number of steps
if [ "$Nparc" -eq "$N" ]; then status="COMPLETED"; else status="INCOMPLETE"; fi
Title "Tract-specific COMMIT processing ended in \033[38;5;220m $(printf "%0.3f\n" "$eri") minutes \033[38;5;141m:
\tSteps completed : $(printf "%02d" "$Nparc")/$(printf "%02d" "$N")
\tStatus          : ${status}
\tCheck logs      : $(ls "$dir_logs"/SC_*.txt)"
# Print QC stamp
grep -v "${id}, ${SES/ses-/}, COMMIT" "${out}/micapipe_processed_sub.csv" > "${tmp}/tmpfile" && mv "${tmp}/tmpfile" "${out}/micapipe_processed_sub.csv"
echo "${id}, ${SES/ses-/}, COMMIT, ${status}, $(printf "%02d" "$Nparc")/$(printf "%02d" "$N"), $(whoami), $(uname -n), $(date), $(printf "%0.3f\n" "$eri"), ${PROC}, ${Version}" >> "${out}/micapipe_processed_sub.csv"
cleanup "$tmp" "$nocleanup" "$here"
