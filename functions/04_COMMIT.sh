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
gratiotractometry=${11}
MTsat_in_dwi=${12}
Dual_MTON=${13}
Dual_MTOFF=${14}
Dual_bvals=${15}
Dual_bvecs=${16}
tractometry=${17}
tck_imaging=${18}
tractometry_input=${19}
PROC=${20}
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
if [ -e ${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography_COMMIT-filtered.tck ]; then
    init_tck=$(ls ${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography_COMMIT-filtered.tck)
elif [ -e ${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography_COMMIT2-filtered.tck ]; then
    init_tck=$( ${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography_COMMIT2-filtered.tck)
else
    Error "Subject $id doesn't have a COMMIT filtered tck:\n\t\tRUN -SC"; exit;
fi
init_tck_str=$(basename "$init_tck" | cut -d. -f1) #Get only the basename of the file without extension
init_tck_str=${init_tck_str/"${idBIDS}_"/}
init_tck_str=${init_tck_str/"-filtered"/}
tck_str=${init_tck_str/"space-dwi"/}
dwi_b0="${proc_dwi}/${idBIDS}_space-dwi_desc-b0.nii.gz"
tck_json=${proc_dwi}/${idBIDS}_space-dwi_desc-*_tractography.json
tracts=($(cat $tck_json | grep -oP '(?<="SeedingNumberMethod": ")[^"]*')) ### Could use jq in the future, but json file has a small bug

# Check inputs
if [ ! -f $dwi_b0  ]; then Error "Subject $id doesn't have b0 image:\n\t\tRUN -proc_dwi"; exit; fi
if [[ ! -f $MVFalpha_list  ]] && [[ $MySD == "TRUE" || $gratio == "TRUE" ]]; then Warning "Subject $id has an alpha value to compute MVF from MTsat"; fi
if [[ ! -f $MTsat_in_dwi  ]] && [[ $MySD == "TRUE" || $gratio == "TRUE" ]]; then Error "Subject $id doesn't have a MTsat image registered in DWI space:\n\t\tRUN -SC with -tractometry"; exit; fi

#------------------------------------------------------------------------------#
Title "\tTract-specific processing\n\t\tmicapipe $Version, $PROC"
micapipe_software

#	Timer
aloita=$(date +%s)
Nparc=0

# Create script specific temp directory
tmpDir=/data/tardiflab2/wenda/tmp
tmp=${tmpDir}/04_COMMIT/${subject}/${SES}
Do_cmd mkdir -p "$tmp"

# TRAP in case the script fails
trap 'cleanup $tmp $nocleanup $here' SIGINT SIGTERM

# -----------------------------------------------------------------------------------------------
# Calibrating g-ratio through COMMIT
alpha=${tmpDir}/04_COMMIT/alpha.txt
MVF_COMMIT_in_dwi=${proc_dwi}/${idBIDS}_space-dwi_desc-MVF-COMMIT.nii.gz

if [[ ${MySD}  == "TRUE" || ${gratio}  == "TRUE" ]] && [[ ! -f "$MVF_COMMIT_in_dwi" ]]; then

    if [[ ! -f "$alpha" ]]; then
        
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
                Do_cmd fslmaths "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/COMMIT_init/dict/Results_StickZeppelinBall_AdvancedSolvers/compartment_IC.nii.gz" -nan "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_ICVF_MNI152_1mm_splenium.nii.gz"
                Do_cmd fslmaths "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/${alpha_sub}_${alpha_ses}_space-dwi_model-DTI_map-FA.nii.gz" -nan "${tmpDir}/MVF_calc/${alpha_sub}_${alpha_ses}_space-dwi_FA_MNI152_1mm_splenium.nii.gz"
            done
            matlab -nodisplay -r "addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/MVFcalc_scripts')); alpha = get_alpha('$tmpDir','$MVFalpha_list'); save('$tmpDir/04_COMMIT/alpha.txt', 'alpha', '-ASCII'); exit"
            Do_cmd rm -r ${tmpDir}/MVF_calc
        else
            until [ -f $alpha ]; do Info "Alpha computation for MTsat to MVF scaling is already in progress, waiting 10 min for it to finish"; sleep 10m; done

        fi
    fi

    alpha_value=$(cat $alpha)
    Do_cmd fslmaths $MTsat_in_dwi -mul $alpha_value $MVF_COMMIT_in_dwi

else
    Info "MTsat was already scaled to MVF"
fi

# -----------------------------------------------------------------------------------------------
# Calibrating g-ratio through NODDI - voxel wise

if [[ "$gratiotractometry" == "TRUE" ]]; then

    alpha_NODDI=${tmpDir}/04_COMMIT/alpha_NODDI.txt

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
        Do_cmd dwi2mask $dwi_mif ${tmp}/${idBIDS}_brain_mask.nii.gz

        /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $AMICO_py $idBIDS $proc_dwi $tmp

        voxel=($(mrinfo $T1nativepro -spacing))
        Do_cmd mrgrid $NODDI_dir/AMICO/NODDI/fit_NDI.nii.gz regrid -voxel $voxel $NODDI_dir/AMICO/NODDI/fit_NDI_up.nii.gz
        Do_cmd mrgrid $NODDI_dir/AMICO/NODDI/fit_FWF.nii.gz regrid -voxel $voxel $NODDI_dir/AMICO/NODDI/fit_FWF_up.nii.gz
    else
        Info "Subject ${id} has NODDI metrics"; ((Nsteps++))
    fi

    if [[ ! -f "$alpha_NODDI" ]]; then
        Info "Calculating alpha for NODDI calibration"
        if [[ ! -d "${tmpDir}/ICNODDI_folder" ]]; then
            Do_cmd mkdir ${tmpDir}/ICNODDI_folder
        fi

        cat $MVFalpha_list|while read line; do
            if [[ ${line} == ${idBIDS} ]]; then 
                IC=${tmpDir}/ICNODDI_folder/${idBIDS}_ICNODDI_brain.nii.gz
                cp $NODDI_NDI $IC
            fi
        done

        number_subject=($(awk 'END { print NR }' ${MVFalpha_list} )) 
        number_file=($(ls ${tmpDir}/ICNODDI_folder -1 | wc -l)) 

        until [ $number_subject == $number_file ]; do 
            Info "Getting IC-NODDI file for all subjects, waiting additional 10m"
            sleep 10m
            number_file=($(ls ${tmpDir}/ICNODDI_folder -1 | wc -l)) 
        done

        Info "Calculating alpha for MTsat to MVF scaling through NODDI"
        if [[ ! -d "${tmpDir}/MVFNODDI_calc" ]]; then
            Do_cmd mkdir ${tmpDir}/MVFNODDI_calc
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
                       -o "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz"
                Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/${alpha_sub}_${alpha_ses}_space-dwi_desc-MTsat_SyN.nii.gz" -nan "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_MTsat_MNI152_1mm_splenium.nii.gz" #### MTsat file location for all subjects was hard-coded.
                Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$tmpDir/ICNODDI_folder/${alpha_sub}_${alpha_ses}_ICNODDI_brain.nii.gz" -nan "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_ICVF_MNI152_1mm_splenium.nii.gz"
                Do_cmd fslmaths "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_MNI152_1mm_splenium.nii.gz" -mul "$out/$alpha_sub/$alpha_ses/dwi/${alpha_sub}_${alpha_ses}_space-dwi_model-DTI_map-FA.nii.gz" -nan "${tmpDir}/MVFNODDI_calc/${alpha_sub}_${alpha_ses}_space-dwi_FA_MNI152_1mm_splenium.nii.gz"
            done
            matlab -nodisplay -r "addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/MVFcalc_scripts')); alpha = get_alphaNODDI('$tmpDir','$MVFalpha_list'); save('$tmpDir/04_COMMIT/alpha_NODDI.txt', 'alpha', '-ASCII'); exit"
            Do_cmd rm -r ${tmpDir}/MVFNODDI_calc
        else
            until [ -f $alpha_NODDI ]; do Info "Alpha computation for MTsat to MVF scaling is already in progress, waiting 10 min for it to finish"; sleep 10m; done

        fi
    fi  
fi

# -----------------------------------------------------------------------------------------------
# MySD filtering and weighting for tract-specific MTsat 
MySD_tck="${proc_dwi}/${idBIDS}_${init_tck_str}-MySD-filtered.tck"
MySD_length="${proc_dwi}/${idBIDS}_${init_tck_str}-MySD-filtered_length.txt"
MySD_weights="${proc_dwi}/${idBIDS}_${init_tck_str}-MySD-filtered_weights.txt"
MySD_weighttimeslength="$proc_dwi/${idBIDS}_${init_tck_str}-MySD-filtered_volume.txt"

if [[ ${gratio}  == "TRUE" || ${MySD}  == "TRUE" ]] && [[ ! -f $MySD_weighttimeslength ]]; then Info "Prepping MySD inputs"

    MySD=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/MySD.py
    weights_MySD=${proc_dwi}/MySD/Results_VolumeFractions/streamline_weights.txt
    f_5tt=${proc_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz
    wm_mask=${tmp}/${idBIDS}_dwi_wm_mask.nii.gz

    while [[ ! -f $weights_MySD  ]] ; do
     	Do_cmd mrconvert -coord 3 2 -axes 0,1,2 $f_5tt $wm_mask
        Info "Running MySD"
        /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $MySD $idBIDS $proc_dwi $tmp $proc_dwi/MySD $init_tck $MVF_COMMIT_in_dwi
        # Removing streamlines whose weights are too low
      	Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_MySD $init_tck $MySD_tck -force
        # Testing if MySD ran into any issues
        tmptckcount=$(tckinfo $MySD_tck -count)
        tmpunfilteredtckcount=$(tckinfo $init_tck -count)
        if [[ "${tmptckcount##* }" -eq 0 ]] || [[ "${tmpunfilteredtckcount##* }" -eq "${tmptckcount##* }" ]] ; then
            rm -r "${proc_dwi}/MySD"
        fi
    done

  	Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_MySD -tck_weights_out $MySD_weights $init_tck $MySD_tck -force

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
# Running COMMIT using upscaled diffusion data multiplied by (1-MVF)

COMMIT_AV_tck="${proc_dwi}/${idBIDS}_${init_tck_str}-MySD-COMMITscaled-filtered.tck"
COMMIT_AV_length="${proc_dwi}/${idBIDS}_${init_tck_str}-MySD-COMMITscaled-filtered_length.txt"
COMMIT_AV_weights="${proc_dwi}/${idBIDS}_${init_tck_str}-MySD-COMMITscaled-filtered_weights.txt"
COMMIT_AV_weighttimeslength="$proc_dwi/${idBIDS}_${init_tck_str}-MySD-COMMITscaled-filtered_volume.txt"

if [[ ${gratio}  == "TRUE" ]] && [[ ! -f $COMMIT_AV_weighttimeslength ]]; then Info "Calculating AV using COMMIT"

    COMMIT=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/COMMIT.py
    weights_COMMIT_AV=${proc_dwi}/COMMITscaled/dict/Results_StickZeppelinBall_AdvancedSolvers/streamline_weights.txt

    bvecs=${tmp}/${idBIDS}_bvecs.txt
    bvals=${tmp}/${idBIDS}_bvals.txt
    wm_fod_mif="${proc_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.mif"
    wm_fod_json=${tmp}/${idBIDS}_wm_fod_norm.json
    wm_fod_nii=${tmp}/${idBIDS}_wm_fod_norm.nii.gz
    f_5tt=${proc_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz
    wm_mask=${tmp}/${idBIDS}_dwi_wm_mask.nii.gz

    if [[ ! -f $tmp/${idBIDS}_dwi_upscaled.nii.gz ]]; then Info "Computing scaled dwi file"
        
        dwi_corr="$proc_dwi/${idBIDS}_space-dwi_desc-dwi_preproc.mif"

        dwi_b0_down="${tmp}/${idBIDS}_space-dwi_desc-b0.nii.gz"
        dwi_b0_down_brain="${tmp}/${idBIDS}_space-dwi_desc-b0_brain.nii.gz"
        dwi_mask_tmp="${tmp}/${idBIDS}_space-dwi_desc-b0_brain_mask.nii.gz"
        dwi_mask="${tmp}/${idBIDS}_space-dwi_desc-b0_brain_mask.nii.gz"

        dwiextract -force -nthreads "$threads" "$dwi_corr" - -bzero | mrmath - mean "$dwi_b0_down" -axis 3 -force
        Do_cmd bet "$dwi_b0_down" "$dwi_b0_down_brain" -v # -B -f 0.25
        Do_cmd fslmaths $dwi_b0_down_brain $dwi_mask_tmp
        Do_cmd maskfilter "$dwi_mask_tmp" erode -npass 1 "$dwi_mask" -force

        MTimage=($(ls $bids_derivs/matlab/$subject/$SES/anat/${idBIDS}_MTsat.nii* 2>/dev/null)) ##### Hard-coded location
        alpha_value=$(cat ${tmpDir}/04_COMMIT/alpha.txt)
        MVFimage="$tmp/${idBIDS}_MVF.nii.gz"
        MVF_in_dwi_lowres="$tmp/${idBIDS}_space-dwi_desc-MVF_lowres.nii.gz"
        dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"
        dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
        dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
        dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"
        MTsat_affine="${dir_warp}/${idBIDS}_MTsat_to-nativepro_mode-image_desc-SyN_0GenericAffine.mat" #### Hard-coded transform, assuming registration was done using SC

        Do_cmd fslmaths $MTimage -mul $alpha_value $MVFimage
        Do_cmd antsApplyTransforms -d 3 -i "$MVFimage" -r "$dwi_b0_down" -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$MTsat_affine" -o "$MVF_in_dwi_lowres" -v
        Do_cmd mrcalc 1 $MVF_in_dwi_lowres -subtract $tmp/scaling_1.nii.gz -force
        Do_cmd dwiextract $dwi_corr -bzero $tmp/b0s_down.mif -force
        Do_cmd dwiextract $dwi_corr -no_bzero $tmp/not_b0s_down.mif -force
        Do_cmd mrcalc $tmp/not_b0s_down.mif $tmp/scaling_1.nii.gz -mult $tmp/not_b0s_down_scaled.mif -force
        Do_cmd mrcat $tmp/b0s_down.mif $tmp/not_b0s_down_scaled.mif $tmp/dwi_down_scaled.mif -force
        voxel=($(mrinfo $T1nativepro -spacing))
        Do_cmd mrgrid $tmp/dwi_down_scaled.mif regrid -voxel $voxel $tmp/dwi_up_scaled.mif -force

        Do_cmd mrconvert $tmp/dwi_up_scaled.mif -export_grad_fsl $bvecs $bvals $tmp/${idBIDS}_dwi_upscaled.nii.gz -force
        Do_cmd mrconvert $wm_fod_mif -json_export $wm_fod_json $wm_fod_nii -force
        Do_cmd mrconvert -coord 3 2 -axes 0,1,2 $f_5tt $wm_mask -force 
    fi

    while [[ ! -f $weights_COMMIT_AV  ]] ; do
        Info "Running COMMIT"
        /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $COMMIT $idBIDS $proc_dwi $tmp $proc_dwi/COMMITscaled $MySD_tck
        # Removing streamlines whose weights are too low
      	Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_COMMIT_AV $MySD_tck $COMMIT_AV_tck -force
        # Testing if MySD ran into any issues
        tmptckcount=$(tckinfo $COMMIT_AV_tck -count)
        tmpunfilteredtckcount=$(tckinfo $MySD_tck -count)
        if [[ "${tmptckcount##* }" -eq 0 ]] || [[ "${tmpunfilteredtckcount##* }" -eq "${tmptckcount##* }" ]] ; then
            rm -r "${proc_dwi}/COMMITscaled"
        fi
    done

  	Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_COMMIT_AV -tck_weights_out $COMMIT_AV_weights $MySD_tck $COMMIT_AV_tck -force

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
	Do_cmd tck2connectome -nthreads $threads $COMMIT_AV_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz $proc_dwi/nos_COMMIT_AV.txt -symmetric -zero_diagonal -quiet -force
    # Getting streamline length
    Do_cmd tckstats $COMMIT_AV_tck -dump $COMMIT_AV_length -force
    # Getting streamline myelin volume
    matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT')); AV_weighttimeslength = weight_times_length('$COMMIT_AV_weights','$COMMIT_AV_length'); save('$COMMIT_AV_weighttimeslength', 'AV_weighttimeslength', '-ASCII'); exit"

    if [ "$nocleanup" == "FALSE" ]; then
        # Cleaning up tmp files
        rm -r ${proc_dwi}/COMMITscaled/dict/dict*
    fi

    else Info "Streamline axonal volume has already been computed or this option was not selected"; 
fi

# -----------------------------------------------------------------------------------------------
# g-Ratio tractometry through NODDI

if [[ "$gratiotractometry" == "TRUE" ]]; then
    gratiomap=${proc_dwi}/${idBIDS}_space-dwi_desc-NODDI-gratiomap.nii.gz
    weights_gratio="${proc_dwi}/${idBIDS}_space-dwi_desc-NODDI-gratiomap_track_weight.csv"
    MVF_in_dwi=${proc_dwi}/${idBIDS}_space-dwi_desc-NODDI-MVFmap.nii.gz
    alphaNODDI_value=$(cat $alpha_NODDI)

    if [[ ! -f "$weights_gratio" ]]; then

        Do_cmd fslmaths $MTsat_in_dwi -mul $alphaNODDI_value $MVF_in_dwi
        Do_cmd mrcalc 1 $MVF_in_dwi -subtract 1 $NODDI_dir/AMICO/NODDI/fit_FWF_up.nii.gz -subtract -multiply $NODDI_dir/AMICO/NODDI/fit_NDI_up.nii.gz -multiply $tmp/AVF_NODDI.nii.gz
        Do_cmd mrcalc $tmp/AVF_NODDI.nii.gz $tmp/AVF_NODDI.nii.gz $MVF_in_dwi -add -div -sqrt $gratiomap

        # Grabbing the correct tract
        if [ -f $COMMIT_AV_tck ]; then
            tractometry_tck=$COMMIT_AV_tck
        elif [ -f $MySD_tck ]; then
            tractometry_tck=$MySD_tck
        else
            tractometry_tck=$init_tck
        fi

        Do_cmd tcksample $tractometry_tck $gratiomap $weights_gratio -stat_tck median -force

    else
        Info "Subject ${id} has gratio metrics";
    fi
fi

# -----------------------------------------------------------------------------------------------
# MTR-DUAL_COMMIT filtering and weighting for tract-specific MTR

if [[ -f $Dual_MTON ]] && [[ -f $Dual_MTOFF ]]; then
    dual=TRUE
else
    dual=FALSE
fi
DUAL_tck="${proc_dwi}/${idBIDS}_space-dual${tck_str}-DUAL-filtered.tck"
DUAL_length="${proc_dwi}/${idBIDS}_space-dual${tck_str}-DUAL-filtered_length.txt"
DUALon_weights="${proc_dwi}/${idBIDS}_space-dual${tck_str}-DUAL-filtered_MTon-weights.txt"
DUALon_weighttimeslength="$proc_dwi/${idBIDS}_space-dual${tck_str}-DUAL-filtered_MTon-volume.txt"
DUALoff_weights="${proc_dwi}/${idBIDS}_space-dual${tck_str}-DUAL-filtered_MToff-weights.txt"
DUALoff_weighttimeslength="$proc_dwi/${idBIDS}_space-dual${tck_str}-DUAL-filtered_MToff-volume.txt"
mtr_b0_in_dual=${proc_dwi}/${idBIDS}_space-dual_desc-mtrb0.nii.gz
mtr_b1500_in_dual=${proc_dwi}/${idBIDS}_space-dual_desc-mtrb1500.nii.gz
dual_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dual_mode-image_desc-SyN_"
dual_SyN_warp="${dual_SyN_str}1Warp.nii.gz"
dual_SyN_Invwarp="${dual_SyN_str}1InverseWarp.nii.gz"
dual_SyN_affine="${dual_SyN_str}0GenericAffine.mat"

if [[ ${dual}  == "TRUE" ]] && [[ ! -f $DUAL_tck ]]; then Info "Prepping COMMIT Dual-MTR inputs"

        Info "Upsampling dual-encoding images"
        Do_cmd fslmaths $Dual_MTON -nan $tmp/mton.nii.gz
      	Do_cmd mrgrid $tmp/mton.nii.gz regrid -voxel $res $tmp/mton_upscaled.nii.gz
        Do_cmd fslmaths $Dual_MTOFF -nan $tmp/mtoff.nii.gz
        Do_cmd mrgrid $tmp/mtoff.nii.gz regrid -voxel $res $tmp/mtoff_upscaled.nii.gz

        Info "Getting mton/mtoff B0 images"
        Do_cmd mrconvert -coord 3 0:0 $tmp/mton_upscaled.nii.gz $tmp/mton_b0.nii.gz
        Do_cmd mrconvert -coord 3 0:0 $tmp/mtoff_upscaled.nii.gz $tmp/mtoff_b0.nii.gz
        Do_cmd mrcalc $tmp/mtoff_b0.nii.gz $tmp/mton_b0.nii.gz -subtract $tmp/mtr_tmp_b0.nii.gz
        Do_cmd mrcalc $tmp/mtr_tmp_b0.nii.gz $tmp/mtoff_b0.nii.gz -divide $mtr_b0_in_dual
        
        Info "Getting mton/mtoff B1500 images"
        Do_cmd mrconvert -coord 3 1:30 $tmp/mton_upscaled.nii.gz $tmp/mton_b1500_all.nii.gz 
        Do_cmd mrmath $tmp/mton_b1500_all.nii.gz mean $tmp/mton_b1500.nii.gz -axis 3
        Do_cmd mrconvert -coord 3 1:30 $tmp/mtoff_upscaled.nii.gz $tmp/mtoff_b1500_all.nii.gz 
        Do_cmd mrmath $tmp/mtoff_b1500_all.nii.gz mean $tmp/mtoff_b1500.nii.gz -axis 3
        Do_cmd mrcalc $tmp/mtoff_b1500.nii.gz $tmp/mton_b1500.nii.gz -subtract $tmp/mtr_tmp_b1500.nii.gz
        Do_cmd mrcalc $tmp/mtr_tmp_b1500.nii.gz $tmp/mtoff_b1500.nii.gz -divide $mtr_b1500_in_dual

        regScript=/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/t1w_dwi_registration_SyN.sh
        log_syn="${tmp}/${idBIDS}_log_T1w_DWI_SyN.txt"

        Info "Registrations"
        Do_cmd bet $tmp/mtoff_b0.nii.gz $tmp/dual_brain.nii.gz -m
        Do_cmd maskfilter $tmp/dual_brain_mask.nii.gz erode -npass 2 $tmp/dual_brain_mask_erode.nii.gz -force
        Do_cmd mrcalc $mtr_b0_in_dual $tmp/dual_brain_mask_erode.nii.gz -mul $tmp/mtr_brain.nii.gz
        Do_cmd mrcalc 4000 $tmp/mtoff_b0.nii.gz $tmp/mton_b1500.nii.gz -add $tmp/mton_b0.nii.gz -add -sub 4000 -div 3 -pow 1000 -mul $tmp/dual_brain_mask_erode.nii.gz -mul $tmp/synth_t1.nii.gz -force
        "$regScript" "$T1nativepro_brain" "$tmp/mtr_brain.nii.gz" "$tmp/synth_t1.nii.gz" "$dual_SyN_str" "$log_syn"


        wm_mask=${tmp}/${idBIDS}_dwi_wm_mask.nii.gz
        wm_mask_dual=${tmp}/${idBIDS}_dual_wm_mask.nii.gz
        confidence_map=${tmp}/confidencemap.nii.gz

     	Info "Getting the white matter mask"
     	Do_cmd mrconvert -coord 3 2 -axes 0,1,2 $T15ttgen $wm_mask -force   
        Do_cmd antsApplyTransforms -d 3 -r $tmp/synth_t1.nii.gz -i $wm_mask -t $dual_SyN_warp -t $dual_SyN_affine -o $wm_mask_dual -v

        Info "Getting Confidence Map for COMMIT dual encoding"
        Do_cmd fslmaths $tmp/mtoff_upscaled.nii.gz -sub $tmp/mton_upscaled.nii.gz -mul $wm_mask_dual $tmp/tmp.nii.gz
        Do_cmd fslmaths $tmp/tmp.nii.gz -thr 0 -bin $tmp/tmp_bin_pos.nii.gz
        Do_cmd fslmaths $tmp/tmp.nii.gz -uthr 0 -abs -bin -mul -5 $tmp/tmp_bin_neg.nii.gz
        Do_cmd fslmaths $tmp/tmp_bin_pos.nii.gz -add $tmp/tmp_bin_neg.nii.gz -Tmean $tmp/tmp_bin_avg.nii.gz
        Do_cmd fslmaths $tmp/tmp_bin_avg.nii.gz -thr 0 $confidence_map

        dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"
        dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
        dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
        dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"
        init_DUAL_tck="${proc_dwi}/${idBIDS}_space-dual${tck_str}-filtered.tck"

        Info "Transforming tck to dual space"
        Do_cmd warpinit $confidence_map $tmp/identity_wrap[].nii -force
        for i in {0..2}; do
            Do_cmd antsApplyTransforms -d 3 -e 0 -i $tmp/identity_wrap${i}.nii -o $tmp/inv_mrtrix_warp${i}.nii -r $confidence_map -t $dwi_SyN_warp -t $dwi_SyN_affine -t [$dual_SyN_affine,1] -t $dual_SyN_Invwarp --default-value 2147483647 -v
        done
        Do_cmd warpcorrect $tmp/inv_mrtrix_warp[].nii $tmp/inv_mrtrix_warp_corrected.mif -marker 2147483647 -force
        Do_cmd tcktransform $init_tck $tmp/inv_mrtrix_warp_corrected.mif $init_DUAL_tck -force


        COMMIT_DUAL=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/COMMIT_dual.py
        weights_dualon=${proc_dwi}/DUALon/Results_StickZeppelinBall/streamline_weights.txt
        weights_dualoff=${proc_dwi}/DUALoff/Results_StickZeppelinBall/streamline_weights.txt
        
        weights_dualon_filtered1=${tmp}/commiton_weight.txt
        weights_dualoff_filtered1=${tmp}/commitoff_weight.txt

        while [[ ! -f $weights_dualon  ]] || [[ ! -f $weights_dualoff  ]] ; do

        if [[ ! -f $weights_dualon  ]]; then
            Info "Running COMMIT for MTon"
            /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $COMMIT_DUAL $idBIDS $proc_dwi $tmp $init_DUAL_tck $tmp/mton_upscaled.nii.gz $Dual_bvals $Dual_bvecs ${proc_dwi}/DUALon
        fi 
        if [[ ! -f $weights_dualoff  ]]; then
            Info "Running COMMIT for MToff"
            /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $COMMIT_DUAL $idBIDS $proc_dwi $tmp $init_DUAL_tck $tmp/mtoff_upscaled.nii.gz $Dual_bvals $Dual_bvecs ${proc_dwi}/DUALoff
        fi  

        # Removing invalid steamlines for Dual-MTon-DWI
        Do_cmd tckedit -minweight 0.00001 -tck_weights_in $weights_dualon $init_DUAL_tck $DUAL_tck -force
        # Rerunning COMMIT is necessary
        tmptckcount=$(tckinfo $DUAL_tck -count)
        tmpunfilteredtckcount=$(tckinfo $init_DUAL_tck -count)
        if [[ "${tmptckcount##* }" -eq 0 ]] || [[ "${tmpunfilteredtckcount##* }" -eq "${tmptckcount##* }" ]] ; then
            rm -r "${proc_dwi}/DUALon"
        fi
        #Removing invalid streamlines for Dual-MToff-DWI
        Do_cmd tckedit -minweight 0.00001 -tck_weights_in $weights_dualoff $init_DUAL_tck $DUAL_tck -force
        # Rerunning COMMIT is necessary
        tmptckcount=$(tckinfo $DUAL_tck -count)
        tmpunfilteredtckcount=$(tckinfo $init_DUAL_tck -count)
        if [[ "${tmptckcount##* }" -eq 0 ]] || [[ "${tmpunfilteredtckcount##* }" -eq "${tmptckcount##* }" ]] ; then
            rm -r "${proc_dwi}/DUALoff"
        fi
        done

        # Removing streamlines that does not exit in both 
        matlab -nodisplay -r "cd('${proc_dwi}'); commitoff = dlmread('DUALoff/Results_StickZeppelinBall/streamline_weights.txt'); commiton = dlmread('DUALon/Results_StickZeppelinBall/streamline_weights.txt'); unusable = (commitoff <= 0.000000000001) | (commiton <= 0.000000000001); commitoff(unusable) = 0; commiton(unusable) = 0; save('${tmp}/commitoff_weight.txt', 'commitoff', '-ASCII'); save('${tmp}/commiton_weight.txt', 'commiton', '-ASCII'); exit"

        Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_dualon_filtered1 -tck_weights_out $DUALon_weights $init_tck $DUAL_tck -force
        Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_dualoff_filtered1 -tck_weights_out $DUALoff_weights $init_tck $DUAL_tck -force

        Do_cmd tckstats $DUAL_tck -dump $DUAL_length -force  
     
        matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('/data_/tardiflab/wenda/programs/COMMIT')); COMMIT_weightoverlength = weight_times_length('$DUALon_weights','$DUAL_length'); save('$DUALon_weighttimeslength', 'COMMIT_weightoverlength', '-ASCII'); exit"
        matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('/data_/tardiflab/wenda/programs/COMMIT')); COMMIT_weightoverlength = weight_times_length('$DUALoff_weights','$DUAL_length'); save('$DUALoff_weighttimeslength', 'COMMIT_weightoverlength', '-ASCII'); exit"


    if [ "$nocleanup" == "FALSE" ]; then
        # Cleaning up tmp files 
        Info "Removing DUAL tmp files"
        rm -r ${proc_dwi}/DUALon/dict*
        rm -r ${proc_dwi}/DUALoff/dict*
    fi

fi

#-----------------------------Connectomes generation-----------------------------
function build_connectomes(){
    tck=$1	
    nodes=$2
	sc_file=$3
    options=$4
	# Build the weighted connectomes
    Do_cmd tck2connectome -nthreads "$threads" "${tck}" "${nodes}" "${sc_file}-connectome.txt" "$options" -assignment_radial_search 2 -quiet -symmetric -zero_diagonal -force
    Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${sc_file}-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"
}

parcellations=($(find "${dir_volum}" -name "*.nii.gz" ! -name "*cerebellum*" ! -name "*subcortical*"))
lut_sc="${util_lut}/lut_subcortical-cerebellum_mics.csv"

if [[ ${dual}  == "TRUE" ]]; then
    Info "Generating DUAL connectomes"
    dual_cere="${tmp}/${idBIDS}_space-dual_atlas-cerebellum.nii.gz"
    dual_subc="${tmp}/${idBIDS}_space-dual_atlas-subcortical.nii.gz"
    T1str_nat="${idBIDS}_space-nativepro_t1w_atlas"
    T1_seg_cerebellum="${dir_volum}/${T1str_nat}-cerebellum.nii.gz"
    T1_seg_subcortex="${dir_volum}/${T1str_nat}-subcortical.nii.gz"
    #Getting subcortical and cerebellum nodes
    Do_cmd antsApplyTransforms -d 3 -e 3 -i "$T1_seg_cerebellum" -r "$mtr_b0_in_dual" -n GenericLabel -t $dual_SyN_warp -t $dual_SyN_affine -o "$dual_cere" -v -u int
    Do_cmd fslmaths "$dual_cere" -bin -mul 100 -add "$dual_cere" "$dual_cere"
    Do_cmd antsApplyTransforms -d 3 -e 3 -i "$T1_seg_subcortex" -r "$mtr_b0_in_dual" -n GenericLabel -t $dual_SyN_warp -t $dual_SyN_affine -o "$dual_subc" -v -u int
    Do_cmd fslmaths "$dual_subc" -thr 16 -uthr 16 -binv -mul "$dual_subc" "$dual_subc"
    #Getting tck MTR weights
    weights_MTRB0="${tmp}/${idBIDS}_space-dual_desc-MTRB0-track_weight.csv"
    Do_cmd tcksample $DUAL_tck $mtr_b0_in_dual $weights_MTRB0 -stat_tck median -force
    weights_MTRB1500="${tmp}/${idBIDS}_space-dual_desc-MTRB1500-track_weight.csv"
    Do_cmd tcksample $DUAL_tck $mtr_b0_in_dual $weights_MTRB1500 -stat_tck median -force

    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str_DUAL="${dwi_cnntm}/${idBIDS}_space-dual_atlas-${parc_name}${tck_str}-DUAL-filtered-"
        lut="${util_lut}/lut_${parc_name}_mics.csv"
        dual_cortex="${tmp}/${idBIDS}_${parc_name}-cor_dual.nii.gz" # Segmentation in dwi space
        dual_cortexSub="${tmp}/${idBIDS}_${parc_name}-sub_dual.nii.gz"
        dual_all="${tmp}/${idBIDS}_${parc_name}-full_dual.nii.gz"
        # -----------------------------------------------------------------------------------------------
        # Build the Full connectome (Cortical-Subcortical-Cerebellar)
        if [[ ! -f "$dual_all" ]]; then 
            Info "Building $parc_name node"
            # Take parcellation into DWI space
            Do_cmd antsApplyTransforms -d 3 -e 3 -i "$seg" -r "$mtr_b0_in_dual" -n GenericLabel -t $dual_SyN_warp -t $dual_SyN_affine -o "$dual_cortex" -v -u int
            # Remove the medial wall
            for i in 1000 2000; do Do_cmd fslmaths "$dual_cortex" -thr "$i" -uthr "$i" -binv -mul "$dual_cortex" "$dual_cortex"; done
            Do_cmd fslmaths "$dual_cortex" -binv -mul "$dual_subc" -add "$dual_cortex" "$dual_cortexSub" -odt int # added the subcortical parcellation
            Do_cmd fslmaths "$dual_cortex" -binv -mul "$dual_cere" -add "$dual_cortexSub" "$dual_all" -odt int # added the cerebellar parcellation
        fi
        if [[ ! -f "${connectome_str_DUAL}_full-connectome.txt" ]]; then
            # Build the Cortical-Subcortical-Cerebellum connectomes
            option1="-tck_weights_in $DUALon_weighttimeslength"
            option2="-tck_weights_in $DUALoff_weighttimeslength"
            option3="-scale_file $weights_MTRB0 -stat_edge mean"
            option4="-scale_file $weights_MTRB1500 -stat_edge mean"
            build_connectomes "$DUAL_tck" "$dual_all" "${connectome_str_DUAL}MTon_full" "$option1"
            build_connectomes "$DUAL_tck" "$dual_all" "${connectome_str_DUAL}MToff_full" "$option2"
            matlab -nodisplay -r "cd('${dwi_cnntm}');COMMIT_on = dlmread('${connectome_str_DUAL}MTon_full-connectome.txt'); COMMIT_off = dlmread('${connectome_str_DUAL}MToff_full-connectome.txt'); COMMIT_MTR = 1-(COMMIT_on./COMMIT_off); COMMIT_MTR(isnan(COMMIT_MTR)) = 0; COMMIT_MTR(COMMIT_MTR < 0) = 0; save('${connectome_str_DUAL}MTR_full-connectome.txt', 'COMMIT_MTR', '-ASCII'); exit"

            build_connectomes "$DUAL_tck" "$dual_all" "${connectome_str_DUAL}MTRB0-Tractometry_full" "$option3"
            build_connectomes "$DUAL_tck" "$dual_all" "${connectome_str_DUAL}MTRB1500-Tractometry_full" "$option4"
        fi
    done
else Info "MTR annotated connectomes have already generated"; 
fi

# -----------------------------------------------------------------------------------------------
# Connectomes generation 
parcellations=($(find "${dir_volum}" -name "*.nii.gz" ! -name "*cerebellum*" ! -name "*subcortical*"))
dwi_cere="${proc_dwi}/${idBIDS}_space-dwi_atlas-cerebellum.nii.gz"
dwi_subc="${proc_dwi}/${idBIDS}_space-dwi_atlas-subcortical.nii.gz"
lut_sc="${util_lut}/lut_subcortical-cerebellum_mics.csv"

dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"  ## Updated transforms 
dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"
trans_T12dwi="-t ${dwi_SyN_warp} -t ${dwi_SyN_affine}" 

if [[ ${MySD}  == "TRUE" ]] || [[ ${gratio}  == "TRUE" ]]; then
    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str_MySD="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}${tck_str}-MySD-filtered-"
        lut="${util_lut}/lut_${parc_name}_mics.csv"
        dwi_cortex="${tmp}/${idBIDS}_${parc_name}-cor_dwi.nii.gz" # Segmentation in dwi space
        dwi_cortexSub="${tmp}/${idBIDS}_${parc_name}-sub_dwi.nii.gz"
        dwi_all="${tmp}/${idBIDS}_${parc_name}-full_dwi.nii.gz"
        # -----------------------------------------------------------------------------------------------
        # Build the Full connectome (Cortical-Subcortical-Cerebellar)
        if [[ ! -f "$dwi_all" ]]; then ((N++))
            Info "Building $parc_name cortical-subcortical-cerebellum connectome"
            # Take parcellation into DWI space
            Do_cmd antsApplyTransforms -d 3 -e 3 -i "$seg" -r "${dwi_b0}" -n GenericLabel "$trans_T12dwi" -o "$dwi_cortex" -v -u int
            # Remove the medial wall
            for i in 1000 2000; do Do_cmd fslmaths "$dwi_cortex" -thr "$i" -uthr "$i" -binv -mul "$dwi_cortex" "$dwi_cortex"; done
            Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_subc" -add "$dwi_cortex" "$dwi_cortexSub" -odt int # added the subcortical parcellation
            Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_cere" -add "$dwi_cortexSub" "$dwi_all" -odt int # added the cerebellar parcellation
        fi
        if [[ ! -f "${connectome_str_MySD}myelin-volume_full-connectome.txt" ]]; then
            Info "Generating $parc_name MySD connectome"
            option1="-tck_weights_in $MySD_weights"
            option2="-tck_weights_in $MySD_weighttimeslength"
            option3="-tck_weights_in $MySD_weights -scale_invnodevol"
            option4="-tck_weights_in $MySD_weighttimeslength -scale_invnodevol"
            build_connectomes "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-cross-sectional-area_full" "$option1"
            build_connectomes "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-volume_full" "$option2"
            build_connectomes "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-cross-sectional-area-node-norm_full" "$option3"
            build_connectomes "$MySD_tck" "$dwi_all" "${connectome_str_MySD}myelin-volume-node-norm_full" "$option4"
        fi
    done
else Info "MySD annotated connectomes have already generated"; 
fi


if [[ ${gratio}  == "TRUE" ]]; then
    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str_COMMIT="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}${tck_str}-MySD-COMMITscaled-filtered-"
        connectome_str_MySD="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}${tck_str}-MySD-filtered-"
        lut="${util_lut}/lut_${parc_name}_mics.csv"
        dwi_cortex="${tmp}/${idBIDS}_${parc_name}-cor_dwi.nii.gz" # Segmentation in dwi space
        dwi_cortexSub="${tmp}/${idBIDS}_${parc_name}-sub_dwi.nii.gz"
        dwi_all="${tmp}/${idBIDS}_${parc_name}-full_dwi.nii.gz"
        # -----------------------------------------------------------------------------------------------
        # Build the Full connectome (Cortical-Subcortical-Cerebellar)
        if [[ ! -f "$dwi_all" ]]; then ((N++))
            Info "Building $parc_name cortical-subcortical-cerebellum connectome"
            # Take parcellation into DWI space
            Do_cmd antsApplyTransforms -d 3 -e 3 -i "$seg" -r "${dwi_b0}" -n GenericLabel "$trans_T12dwi" -o "$dwi_cortex" -v -u int
            # Remove the medial wall
            for i in 1000 2000; do Do_cmd fslmaths "$dwi_cortex" -thr "$i" -uthr "$i" -binv -mul "$dwi_cortex" "$dwi_cortex"; done
            Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_subc" -add "$dwi_cortex" "$dwi_cortexSub" -odt int # added the subcortical parcellation
            Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_cere" -add "$dwi_cortexSub" "$dwi_all" -odt int # added the cerebellar parcellation
        fi
        if [[ ! -f "${connectome_str_COMMIT}gratio_full-connectome.txt" ]]; then
            Info "Generating $parc_name g-ratio and COMMIT connectome"
            option1="-scale_file $weights_gratio -stat_edge mean"
            option2="-tck_weights_in $COMMIT_AV_weights"
            option3="-tck_weights_in $COMMIT_AV_weighttimeslength"
            option4="-tck_weights_in $COMMIT_AV_weights -scale_invnodevol"
            option5="-tck_weights_in $COMMIT_AV_weighttimeslength -scale_invnodevol"
            option6=""
            option7="-scale_length -stat_edge mean"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}gratio-tractometry_full" "$option1"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-cross-sectional-area_full" "$option2"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-volume_full" "$option3"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-cross-sectional-area-node-norm_full" "$option4"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}axonal-volume-node-norm_full" "$option5"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}NOS_full" "$option6"
            build_connectomes "$COMMIT_AV_tck" "$dwi_all" "${connectome_str_COMMIT}LOS_full" "$option7"

    		matlab -nodisplay -r "MVF = dlmread('${connectome_str_MySD}myelin-volume_full-connectome.txt'); AVF = dlmread('${connectome_str_COMMIT}axonal-volume_full-connectome.txt'); gratio = sqrt(1-MVF./(MVF+AVF)); gratio(isnan(gratio)) = 0; save('${connectome_str_COMMIT}gratio_full-connectome.txt', 'gratio', '-ASCII'); exit"

        fi
    done
fi

# -----------------------------------------------------------------------------------------------
# Tractometry connectomes generation 

if [[ ${tractometry}  == "TRUE" ]]; then

    # Getting the tck file for tractometry
    if [ -f $COMMIT_AV_tck  ]; then
        tractometry_tck=$COMMIT_AV_tck
        connectome_str_tractometry="${init_tck_str}-MySD-COMMITscaled"
    elif [ -f $MySD_tck ]; then
        tractometry_tck=$MySD_tck
        connectome_str_tractometry="${init_tck_str}-MySD"
    else
        tractometry_tck=$init_tck
        connectome_str_tractometry="$init_tck_str"
    fi

    Info "Performing tractometry"
    for image in $tractometry_input; do

        image_str=$(basename "$image" | cut -d. -f1) #Get only the basename of the file without extension
        image_str=${image_str/"${idBIDS}_"/}
        image_brain="${tmp}/${idBIDS}_${image_str}_BrainExtractionBrain.nii.gz"

        str_image_syn="${dir_warp}/${idBIDS}_${image_str}_to-nativepro_mode-image_desc-SyN_"
        t1_image_warp="${str_image_syn}1Warp.nii.gz"
        t1_image_Invwarp="${str_image_syn}1InverseWarp.nii.gz"
        t1_image_affine="${str_image_syn}0GenericAffine.mat"

        image_in_dwi="${proc_dwi}/${idBIDS}_space-dwi_desc-${image_str}_SyN.nii.gz"
        weights_image="${proc_dwi}/${idBIDS}_${connectome_str_tractometry}-filtered_${image_str}-weight.csv"

        if [[ ! -f "$weights_image" ]]; then
            Info "Non-linear registration and sampling of ${image_str}"
            #Do_cmd antsBrainExtraction.sh -d 3 -a $image -e "$util_MNIvolumes/MNI152_T1_1mm_brain.nii.gz" -m $MNI152_mask -o "${tmp}/${idBIDS}_${image_str}_"
            Do_cmd bet $image $image_brain -f 0.35
            Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$image_brain" -o "$str_image_syn" -t a -n "$threads" -p d
            #Do_cmd antsApplyTransforms -d 3 -i "$image" -r "$dwi_b0" -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_image_warp" -t "$t1_image_affine" -o "$image_in_dwi" -v --float
            Do_cmd antsApplyTransforms -d 3 -i "$image" -r "$dwi_b0" -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_image_affine" -o "$image_in_dwi" -v

            #Sampling image
            Do_cmd tcksample $tractometry_tck $image_in_dwi $weights_image -stat_tck median -force
        else
              Info "Subject ${id} has already sampled ${image_str}"; ((Nsteps++))
        fi

        for seg in "${parcellations[@]}"; do
            parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
            connectome_str="${dwi_cnntm}/${idBIDS}_${connectome_str_tractometry}-filtered-"
            lut="${util_lut}/lut_${parc_name}_mics.csv"
            dwi_cortex="${tmp}/${idBIDS}_${parc_name}-cor_dwi.nii.gz" # Segmentation in dwi space
            dwi_cortexSub="${tmp}/${idBIDS}_${parc_name}-sub_dwi.nii.gz"
            dwi_all="${tmp}/${idBIDS}_${parc_name}-full_dwi.nii.gz"
            # -----------------------------------------------------------------------------------------------
            # Build the Full connectome (Cortical-Subcortical-Cerebellar)
            if [[ ! -f "$dwi_all" ]]; then ((N++))
                Info "Building $parc_name cortical-subcortical-cerebellum connectome"
                # Take parcellation into DWI space
                Do_cmd antsApplyTransforms -d 3 -e 3 -i "$seg" -r "${dwi_b0}" -n GenericLabel "$trans_T12dwi" -o "$dwi_cortex" -v -u int
                # Remove the medial wall
                for i in 1000 2000; do Do_cmd fslmaths "$dwi_cortex" -thr "$i" -uthr "$i" -binv -mul "$dwi_cortex" "$dwi_cortex"; done
                Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_subc" -add "$dwi_cortex" "$dwi_cortexSub" -odt int # added the subcortical parcellation
                Do_cmd fslmaths "$dwi_cortex" -binv -mul "$dwi_cere" -add "$dwi_cortexSub" "$dwi_all" -odt int # added the cerebellar parcellation
            fi
            if [[ ! -f "${connectome_str}-${image_str}-tractometry_full-connectome.txt" ]]; then
                option1="-scale_file $weights_image -stat_edge mean"
                build_connectomes "$tractometry_tck" "$dwi_all" "${connectome_str}-${image_str}-tractometry_full" "$option1"
            fi
        done
    done
fi



if [[ ${tck_imaging}  == "TRUE"  ]]; then

    mkdir ${proc_dwi}/roi_image

    Info "Getting tck parcels"
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

    Do_cmd mri_convert ${dir_freesurfer}/mri/brainstemSsLabels.v12.FSvoxelSpace.mgz $tmp/T1_brain_FS_bstem.nii.gz --out_orientation LAS
    Do_cmd fslmaths $tmp/nodes_fixSGM.nii.gz -uthr 85 -thr 85 -binv $tmp/T1_brain_FS_bstem_binv.nii.gz
    Do_cmd fslmaths $tmp/nodes_fixSGM.nii.gz -mul $tmp/T1_brain_FS_bstem_binv.nii.gz $tmp/aparc+aseg_FS_nobstem.nii.gz
    Do_cmd fslmaths $tmp/T1_brain_FS_bstem.nii.gz -binv -mul $tmp/aparc+aseg_FS_nobstem.nii.gz $tmp/aparc+aseg_FS_nobstem.nii.gz

    Do_cmd fslmaths $tmp/T1_brain_FS_bstem.nii.gz -uthr 175 -thr 175 -bin $tmp/T1_brain_FS_medulla.nii.gz
    Do_cmd fslmaths $tmp/T1_brain_FS_medulla.nii.gz -mul 85 $tmp/T1_brain_FS_medulla.nii.gz
    Do_cmd fslmaths $tmp/aparc+aseg_FS_nobstem.nii.gz -add $tmp/T1_brain_FS_medulla.nii.gz $tmp/nodes_fixSGM.nii.gz

    # Move parcel from T1 space to diffusion space
    t1_fs_str="${tmp}/${idBIDS}_fs_to-nativepro_mode-image_desc_"
    t1_fs_affine="${t1_fs_str}0GenericAffine.mat"
    Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$tmp/T1_brain_FS.nii.gz" -o "$t1_fs_str" -t a -n "$threads" -p d
    Do_cmd antsApplyTransforms -d 3 -r $dwi_b0 -i $tmp/nodes_fixSGM.nii.gz -n GenericLabel -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_fs_affine" -o $tmp/${idBIDS}_DK-85-full_dwi.nii.gz -v 

    Do_cmd tck2connectome $COMMIT_AV_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz ${proc_dwi}/roi_image/AVF.txt -tck_weights_in $COMMIT_AV_weighttimeslength -symmetric -force
    Do_cmd tck2connectome $MySD_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz ${proc_dwi}/roi_image/MVF.txt -tck_weights_in $MySD_weighttimeslength -symmetric -force
    Do_cmd tck2connectome $COMMIT_AV_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz  ${proc_dwi}/roi_image/tracto.txt -scale_file $weights_gratio -stat_edge mean -symmetric -quiet -out_assignments ${proc_dwi}/roi_image/tract_assignments.txt

    matlab -nodisplay -r "MVF = dlmread('${proc_dwi}/roi_image/MVF.txt'); AVF = dlmread('${proc_dwi}/roi_image/AVF.txt'); gratio = sqrt(1-MVF./(MVF+AVF)); gratio(isnan(gratio)) = 0; save('${proc_dwi}/roi_image/gratio.txt', 'gratio', '-ASCII'); exit"

    Do_cmd connectome2tck $COMMIT_AV_tck ${proc_dwi}/roi_image/tract_assignments.txt ${proc_dwi}/roi_image/filt.tck -files single -nodes 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85 -exclusive

    Do_cmd tck2connectome ${proc_dwi}/roi_image/filt.tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz ${proc_dwi}/roi_image/nos.txt -symmetric -quiet -out_assignments ${proc_dwi}/roi_image/filt_tract_assignments.txt  

fi


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
