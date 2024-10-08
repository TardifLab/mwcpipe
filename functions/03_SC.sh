#!/bin/bash
#
# DWI POST structural TRACTOGRAPHY processing with bash:
#
# POST processing workflow for diffusion MRI TRACTOGRAPHY.
#
# This workflow makes use of MRtrix3
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
tracts=$8
autoTract=$9
keep_tck=${10}
dwi_str=${11}
filter=${12}
reg_lambda=${13}
tractometry=${14} 
filter_types=${15}
tractometry_input=${16}
PROC=${17}
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

# Update path for multiple acquisitions processing
if [[ "${dwi_str}" != "DEFAULT" ]]; then
  dwi_str="acq-${dwi_str/acq-/}"
  dwi_str_="_${dwi_str}"
  export proc_dwi=$subject_dir/dwi/"${dwi_str}"
  export dwi_cnntm=$proc_dwi/connectomes
  export autoTract_dir=$proc_dwi/auto_tract
else
  dwi_str=""; dwi_str_=""
fi

# Check inputs: DWI post TRACTOGRAPHY
fod_wmN="${proc_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.mif"
dwi_5tt="${proc_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz"
dwi_b0="${proc_dwi}/${idBIDS}_space-dwi_desc-b0.nii.gz"
dwi_mask="${proc_dwi}/${idBIDS}_space-dwi_desc-b0_brain_mask.nii.gz" ## Changed such that it maches the b0
str_dwi_affine="${dir_warp}/${idBIDS}_space-dwi_from-dwi${dwi_str_}_to-nativepro_mode-image_desc-affine_"
mat_dwi_affine="${str_dwi_affine}0GenericAffine.mat"

#dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-dwi${dwi_str_}_to-dwi_mode-image_desc-SyN_" ## Original transforms
#dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
#dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"
dwi_SyN_str="${dir_warp}/${idBIDS}_space-dwi_from-T1w_to-dwi_mode-image_desc-SyN_"  ## Updated transforms 
dwi_SyN_warp="${dwi_SyN_str}1Warp.nii.gz"
dwi_SyN_Invwarp="${dwi_SyN_str}1InverseWarp.nii.gz"
dwi_SyN_affine="${dwi_SyN_str}0GenericAffine.mat"

dti_FA="${proc_dwi}/${idBIDS}_space-dwi_model-DTI_map-FA.nii.gz" ## Changed format from mif to nii
lut_sc="${util_lut}/lut_subcortical-cerebellum_mics.csv"
# from proc_structural
T1str_nat="${idBIDS}_space-nativepro_t1w_atlas"
T1_seg_cerebellum="${dir_volum}/${T1str_nat}-cerebellum.nii.gz"
T1_seg_subcortex="${dir_volum}/${T1str_nat}-subcortical.nii.gz"
# TDI output
tdi="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tdi.mif"

# Check inputs
if [ ! -f "$fod_wmN"  ]; then Error "Subject $id doesn't have FOD:\n\t\tRUN -proc_dwi"; exit; fi
if [ ! -f "$dwi_b0" ]; then Error "Subject $id doesn't have dwi_b0:\n\t\tRUN -proc_dwi"; exit; fi
#if [ ! -f "$mat_dwi_affine" ]; then Error "Subject $id doesn't have an affine mat from T1nativepro to DWI space:\n\t\t${mat_dwi_affine}\n\t\tRUN -proc_dwi"; exit; fi
if [ ! -f "$dwi_5tt" ]; then Error "Subject $id doesn't have 5tt in dwi space:\n\t\tRUN -proc_dwi"; exit; fi
if [ ! -f "$T1_seg_cerebellum" ]; then Error "Subject $id doesn't have cerebellar segmentation:\n\t\tRUN -post_structural"; exit; fi
if [ ! -f "$T1_seg_subcortex" ]; then Error "Subject $id doesn't have subcortical segmentation:\n\t\tRUN -post_structural"; exit; fi
if [ ! -f "$dwi_mask" ]; then Error "Subject $id doesn't have DWI binary mask:\n\t\tRUN -proc_dwi"; exit; fi
if [ ! -f "$dti_FA" ]; then Error "Subject $id doesn't have a FA:\n\t\tRUN -proc_dwi"; exit; fi
if [ ! -f "$dwi_SyN_affine" ]; then Warning "Subject $id doesn't have an SyN registration, only AFFINE will be apply"; regAffine="TRUE"; else regAffine="FALSE"; fi
if [[ $filter_types != "COMMIT" && $filter_types != "SIFT2" && $filter_types != "COMMIT2" ]]; then Error "-filter argument does not exist"; exit; fi
if [[ "$filter_types" == "COMMIT2" ]] && [[ "$reg_lambda" == "FALSE" ]]; then Error "Subject $id is filtering using COMMIT2 but doesn't have a lambda:\n\t\tRUN -SC with -reg_lambda"; exit; fi

# -----------------------------------------------------------------------------------------------
# Check IF output exits and WARNING
N=$(ls "${dwi_cnntm}"/"${idBIDS}"_space-dwi_atlas-*_desc-iFOD2-"${tracts}"-"${filter}"_full-connectome.txt 2>/dev/null | wc -l)
if [ "$N" -gt 3 ]; then Warning " Connectomes with $tracts streamlines already exist!!
  If you want to re-run the $tracts tractogram or add parcellations first clean the outpus:
    micapipe_cleanup -SC -sub $id -out ${out/"/micapipe"/} -bids $BIDS -tracts ${tracts}"; fi

#------------------------------------------------------------------------------#
Title "Tractography and structural connectomes\n\t\tmicapipe $Version, $PROC"
micapipe_software
Info "Number of streamlines: $tracts"
Info "Auto-tractograms: $autoTract"
Info "Saving tractography: $keep_tck"
Info "Saving temporal dir: $nocleanup"
Info "MRtrix will use $threads threads"

#	Timer
aloita=$(date +%s)
Nparc=0

# Create script specific temp directory
#tmp="${tmpDir}/${RANDOM}_micapipe_post-dwi_${id}"

tmpDir=/data/tardiflab2/wenda/tmp
tmp=${tmpDir}/03_SC/${subject}/${SES}
Do_cmd mkdir -p "$tmp"

#tmp=${tmpDir}/03_SC/${subject}/${SES}
#Do_cmd mkdir -p "$tmp"

# TRAP in case the script fails
trap 'cleanup $tmp $nocleanup $here' SIGINT SIGTERM

# Create Connectomes directory for the outpust
[[ ! -d "$dwi_cnntm" ]] && Do_cmd mkdir -p "$dwi_cnntm" && chmod -R 770 "$dwi_cnntm"
[[ ! -d "$dir_QC_png" ]] && Do_cmd mkdir -p "$dir_QC_png" && chmod -R 770 "$dir_QC_png"
Do_cmd cd "$tmp"

# -----------------------------------------------------------------------------------------------
# Prepare the segmentatons
parcellations=($(find "${dir_volum}" -name "*.nii.gz" ! -name "*cerebellum*" ! -name "*subcortical*"))
dwi_cere="${proc_dwi}/${idBIDS}_space-dwi_atlas-cerebellum.nii.gz"
dwi_subc="${proc_dwi}/${idBIDS}_space-dwi_atlas-subcortical.nii.gz"

# Transformations from T1nativepro to DWI
if [[ ${regAffine}  == "FALSE" ]]; then
    trans_T12dwi="-t ${dwi_SyN_warp} -t ${dwi_SyN_affine}" # -t [${mat_dwi_affine},1]  ## Not using the affine with the updated registration scipt
elif [[ ${regAffine}  == "TRUE" ]]; then
    trans_T12dwi="-t [${mat_dwi_affine},1]"
fi

if [[ ! -f "$dwi_cere" ]]; then Info "Registering Cerebellar parcellation to DWI-b0 space"
      Do_cmd antsApplyTransforms -d 3 -e 3 -i "$T1_seg_cerebellum" -r "$dwi_b0" -n GenericLabel "$trans_T12dwi" -o "$dwi_cere" -v -u int
      if [[ -f "$dwi_cere" ]]; then ((Nparc++)); fi
      # Threshold cerebellar nuclei (29,30,31,32,33,34) and add 100
      # Do_cmd fslmaths $dwi_cere -uthr 28 $dwi_cere
      Do_cmd fslmaths "$dwi_cere" -bin -mul 100 -add "$dwi_cere" "$dwi_cere"
else Info "Subject ${id} has a Cerebellar segmentation in DWI space"; ((Nparc++)); fi

if [[ ! -f "$dwi_subc" ]]; then Info "Registering Subcortical parcellation to DWI-b0 space"
    Do_cmd antsApplyTransforms -d 3 -e 3 -i "$T1_seg_subcortex" -r "$dwi_b0" -n GenericLabel "$trans_T12dwi" -o "$dwi_subc" -v -u int
    # Remove brain-stem (label 16)
    Do_cmd fslmaths "$dwi_subc" -thr 16 -uthr 16 -binv -mul "$dwi_subc" "$dwi_subc"
    if [[ -f "$dwi_subc" ]]; then ((Nparc++)); fi
else Info "Subject ${id} has a Subcortical segmentation in DWI space"; ((Nparc++)); fi

# -----------------------------------------------------------------------------------------------
# Generate probabilistic tracts
tck="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography.tck"
if [ ! -f "$tck" ]; then
    Info "Building the ${tracts} streamlines connectome!!!"
    export tckjson="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography.json"
    Do_cmd tckgen -nthreads "$threads" \
        "$fod_wmN" \
        "$tck" \
        -act "$dwi_5tt" \
        -crop_at_gmwmi \
        -backtrack \
        -seed_dynamic "$fod_wmN" \
        -algorithm iFOD2 \
        -step 0.5 \
        -angle 22.5 \
        -cutoff 0.06 \
        -maxlength 400 \
        -minlength 10 \
        -select "$tracts"

    # Exit if tractography fails
    if [ ! -f "$tck" ]; then Error "Tractogram failed, check the logs: $(ls -Art "$dir_logs"/post-dwi_*.txt | tail -1)"; exit; fi

    # json file of tractogram
    tck_json iFOD2 0.5 22.5 0.06 400 10 seed_dynamic "$tck"

    # TDI for QC
    Info "Creating a Track Density Image (tdi) of the $tracts connectome for QC"
    Do_cmd tckmap -vox 1,1,1 -dec -nthreads "$threads" "$tck" "$tdi" -force
    ((Nparc++))
else
    Info "Subject ${id} has a ${tracts} tractogram"; ((Nparc++))
fi

# -----------------------------------------------------------------------------------------------
# Filtering
if [[ ${filter}  == "TRUE" ]]; then

    for filter_name in $filter_types; do

        weights_sift2="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_SIFT2_weights.txt"
        if [[ "$filter_name" == "SIFT2" ]] && [[ ! -f "$weights_sift2" ]]; then
         	Info "SIFT2 filtering"            
            #SIFT2
            Do_cmd tcksift2 -nthreads "$threads" "$tck" "$fod_wmN" "$weights_sift2"
        fi

        if [[ "$filter_name" == "COMMIT2" || "$filter_name" == "COMMIT" ]]; then
         	
            if [[ ! -f "$tmp/${idBIDS}_DK-85-full_dwi.nii.gz" ]]; then 
                Info "Creating DK85 parcel"            
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
                Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$tmp/T1_brain_FS.nii.gz" -o "$t1_fs_str" -t a -n "$threads" -p d
                Do_cmd antsApplyTransforms -d 3 -r $dwi_b0 -i $tmp/nodes_fixSGM.nii.gz -n GenericLabel -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_fs_affine" -o $tmp/${idBIDS}_DK-85-full_dwi.nii.gz -v
            fi

            wm_fod_mif="${proc_dwi}/${idBIDS}_space-dwi_model-CSD_map-FOD_desc-wmNorm.mif"
            wm_fod_json=${tmp}/${idBIDS}_wm_fod_norm.json
            wm_fod_nii=${tmp}/${idBIDS}_wm_fod_norm.nii.gz
            f_5tt=${proc_dwi}/${idBIDS}_space-dwi_desc-5tt.nii.gz
            wm_mask=${tmp}/${idBIDS}_dwi_wm_mask.nii.gz
            dwi_up_mif="${proc_dwi}/${idBIDS}_space-dwi_desc-dwi_preproc_upscaled.mif"
            dwi_up_nii=${tmp}/${idBIDS}_dwi_upscaled.nii.gz
            bvecs=${tmp}/${idBIDS}_bvecs.txt
            bvals=${tmp}/${idBIDS}_bvals.txt
            if [ ! -e "$wm_fod_nii" ] || [ ! -e "$wm_mask" ] || [ ! -e "$dwi_up_nii" ]; then
             	Info "Getting NIFTI files for COMMIT"
             	Do_cmd mrconvert $wm_fod_mif -json_export $wm_fod_json $wm_fod_nii
             	Do_cmd mrconvert -coord 3 2 -axes 0,1,2 $f_5tt $wm_mask
             	Do_cmd mrconvert $dwi_up_mif -export_grad_fsl $bvecs $bvals $dwi_up_nii
            fi

        fi

        COMMIT2_tck="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-filtered.tck"
        COMMIT2_length="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-filtered_length.txt"
        COMMIT2_weights="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-filtered_weights.txt"
        COMMIT2_weighttimeslength="$proc_dwi/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-filtered_volume.txt"
        weights_commit2="${proc_dwi}/COMMIT2_init/dict/Results_StickZeppelinBall_COMMIT2/streamline_weights.txt"

        if [[ $filter_name == "COMMIT2" ]] && [[ ! -f "$COMMIT2_tck" ]]; then
         	Info "COMMIT2 filtering" 
            if [[ ! -f $weights_commit2 ]]; then
                COMMIT2=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/COMMIT2.py
                while [[ ! -f $weights_commit2  ]] ; do #Sometimes run into an error with COMMIT outputs, reruning it seems to fix it
                Info "Running COMMIT2"
                Do_cmd /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $COMMIT2 ${idBIDS} $proc_dwi $tmp $reg_lambda #empirically determined to have a matrix density of 35% using the DK parcellation (2e-1 for deterministic at 3M, 8e-1 for probabilistic at 3M for MWC dataset)
                # Remove any streamlines whose weights are too low
                Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_commit2 -tck_weights_out $COMMIT2_weights $tmp/DWI_tractogram_connecting.tck $COMMIT2_tck -force     
                # Testing if COMMIT2 ran into any issues
                tmptckcount=$(tckinfo $COMMIT2_tck -count)
                if [[ "${tmptckcount##* }" -eq 0 ]]; then
                    rm -r "${proc_dwi}/COMMIT2_init"
                fi
                done
            fi
                # Compute network density
	            Do_cmd tck2connectome -nthreads $threads $COMMIT2_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz $proc_dwi/nos_commit2.txt -symmetric -zero_diagonal -quiet -force
                # Get track length
                Do_cmd tckstats $COMMIT2_tck -dump $COMMIT2_length -force
                # Get track volume
                matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT')); COMMIT2_weighttimeslength = weight_times_length('$COMMIT2_weights','$COMMIT2_length'); save('${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT2-filtered_volume.txt', 'COMMIT2_weighttimeslength', '-ASCII'); exit"
            
            if [ "$nocleanup" == "FALSE" ]; then
                # Here to cleanup some files
                rm -r ${proc_dwi}/COMMIT2_init/dict/dict*
            fi
        fi

        COMMIT_tck="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT-filtered.tck"
        COMMIT_length="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT-filtered_length.txt"
        COMMIT_weights="${proc_dwi}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT-filtered_weights.txt"
        COMMIT_weighttimeslength="$proc_dwi/${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT-filtered_volume.txt"
        weights_commit="${proc_dwi}/COMMIT_init/dict/Results_StickZeppelinBall_AdvancedSolvers/streamline_weights.txt"

        if [[ $filter_name == "COMMIT" ]] && [[ ! -f "$COMMIT_tck" ]]; then
            COMMIT=${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT/COMMIT_init.py
            if [[ ! -f $weights_commit ]]; then
                while [[ ! -f $weights_commit  ]] ; do #Sometimes run into an error with COMMIT outputs, reruning it seems to fix it
                Info "Running COMMIT"
                Do_cmd fslmaths $tmp/${idBIDS}_DK-85-full_dwi.nii.gz -bin $tmp/${idBIDS}_DK-85-full_dwi_bin.nii.gz
                Do_cmd tck2connectome $tck $tmp/${idBIDS}_DK-85-full_dwi_bin.nii.gz ${tmp}/nos.txt -quiet -out_assignments ${tmp}/tck_assignments.txt
                Do_cmd connectome2tck $tck ${tmp}/tck_assignments.txt ${tmp}/filt_tck.tck -files single -nodes 1 -keep_self
                Do_cmd connectome2tck $tck ${tmp}/tck_assignments.txt ${tmp}/filt_tck_unused.tck -files single -nodes 0 -keep_self
#                Do_cmd tck2connectome $tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz ${tmp}/nos.txt -quiet -out_assignments ${tmp}/tck_assignments.txt
#                Do_cmd connectome2tck $tck ${tmp}/tck_assignments.txt ${tmp}/filt_tck.tck -files single -nodes 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85
             	Do_cmd /data_/tardiflab/wenda/programs/localpython/bin/python3.10 $COMMIT $idBIDS $proc_dwi $tmp ${tmp}/filt_tck.tck
                # Remove any streamlines whose weights are too low
                Do_cmd tckedit -minweight 0.000000000001 -tck_weights_in $weights_commit -tck_weights_out $COMMIT_weights ${tmp}/filt_tck.tck $COMMIT_tck -force     
                # Testing if COMMIT2 ran into any issues
                tmptckcount=$(tckinfo $COMMIT_tck -count)
                if [[ "${tmptckcount##* }" -eq 0 ]]; then
                    rm -r "${proc_dwi}/COMMIT_init"
                fi
                done
            fi

            # Compute network density
            Do_cmd tck2connectome -nthreads $threads $COMMIT_tck $tmp/${idBIDS}_DK-85-full_dwi.nii.gz $proc_dwi/nos_commit.txt -symmetric -zero_diagonal -quiet -force
            # Get track length
            Do_cmd tckstats $COMMIT_tck -dump $COMMIT_length -force
            # Get track volume
            matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('${MICAPIPE}/tardiflab/scripts/01_processing/COMMIT')); COMMIT_weighttimeslength = weight_times_length('$COMMIT_weights','$COMMIT_length'); save('${idBIDS}_space-dwi_desc-iFOD2-${tracts}_tractography_COMMIT-filtered_volume.txt', 'COMMIT_weighttimeslength', '-ASCII'); exit"
        
            if [ "$nocleanup" == "FALSE" ]; then
                # Here to cleanup some files
                rm -r ${proc_dwi}/COMMIT_init/dict/dict*
            fi
        fi
    done

fi

# -----------------------------------------------------------------------------------------------
# Build the Connectomes
function build_connectomes(){
	nodes=$1
	sc_file=$2
    options=$3
	# Build the weighted connectomes
    Do_cmd tck2connectome -nthreads "$threads" "${tck}" "${nodes}" "${sc_file}-connectome.txt" "$options" -symmetric -zero_diagonal -quiet -assignment_radial_search 2 -force
    Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${sc_file}-connectome.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"

    # Calculate the edge lenghts
    Do_cmd tck2connectome -nthreads "$threads" "${tck}" "${nodes}" "${sc_file}-edgeLengths.txt" "$options" -scale_length -stat_edge mean -symmetric -zero_diagonal -assignment_radial_search 2 -quiet -force
    Do_cmd Rscript "$MICAPIPE"/functions/connectome_slicer.R --conn="${sc_file}-edgeLengths.txt" --lut1="$lut_sc" --lut2="$lut" --mica="$MICAPIPE"
}

if [[ ${filter} == "FALSE" ]]; then

    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}_desc-iFOD2-${tracts}-${filter_name}"
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
        if [[ ! -f "${connectome_str}_full-connectome.txt" ]]; then
            build_connectomes "$dwi_all" "${connectome_str}_full"
        fi
    done

fi

for filter_name in $filter_types; do

    #Setting up weights and filter for the connectomes
    if [ "$filter_name" == "SIFT2" ]; then
        options="-tck_weights_in $weights_sift2"
    elif [ "$filter_name" == "COMMIT2" ]; then
        options="-tck_weights_in $weights_commit2"
    elif [ "$filter_name" == "COMMIT" ]; then
        options="-tck_weights_in $weights_commit"
    fi

    for seg in "${parcellations[@]}"; do
        parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
        connectome_str="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}_desc-iFOD2-${tracts}-${filter_name}"
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
        if [[ ! -f "${connectome_str}_full-connectome.txt" ]]; then
            # Build the Cortical-Subcortical-Cerebellum connectomes
            build_connectomes "$dwi_all" "${connectome_str}_full" "$options"
        fi
    done

done


# Change connectome permissions
chmod 770 -R "$dwi_cnntm"/* 2>/dev/null

# -----------------------------------------------------------------------------------------------
# Compute Auto-Tractography   ------------  weights is up to debate to what it should be.......
if [ "$autoTract" == "TRUE" ]; then
    Info "Running Auto-tract"
    autoTract_dir="$proc_dwi"/auto_tract
    [[ ! -d "$autoTract_dir" ]] && Do_cmd mkdir -p "$autoTract_dir"
    fa_niigz="${tmp}/${idBIDS}_dti_FA.nii.gz"
    Do_cmd mrconvert "$dti_FA" "$fa_niigz"
    echo -e "\033[38;5;118m\nCOMMAND -->  \033[38;5;122m03_auto_tracts.sh -tck $tck -outbase $autoTract_dir/${id} -mask $dwi_mask -fa $fa_niigz -tmpDir $tmp -keep_tmp  \033[0m"
    "$MICAPIPE"/functions/03_auto_tracts.sh -tck "$tck" -outbase "${autoTract_dir}/${idBIDS}_space-dwi_desc-iFOD2-${tracts}-${filter}" -mask "$dwi_mask" -fa "$fa_niigz" -weights "$weights" -tmpDir "$tmp" -keep_tmp
fi

# -----------------------------------------------------------------------------------------------
# Tractometry 

if [[ ${tractometry}  == "TRUE" ]]; then
    Info "Performing tractometry"
    for image in $tractometry_input; do
        image_str=$(basename "$image" | cut -d. -f1)
        image_str=${image_str/"${idBIDS}_"/}
        image_brain="${tmp}/${idBIDS}_${image_str}_BrainExtractionBrain.nii.gz"

        str_image_syn="${dir_warp}/${idBIDS}_${image_str}_to-nativepro_mode-image_desc-SyN_"
        t1_image_warp="${str_image_syn}1Warp.nii.gz"
        t1_image_Invwarp="${str_image_syn}1InverseWarp.nii.gz"
        t1_image_affine="${str_image_syn}0GenericAffine.mat"

        image_in_dwi="${proc_dwi}/${idBIDS}_space-dwi_desc-${image_str}_SyN.nii.gz"
        weights_image="${proc_dwi}/${idBIDS}_space-dwi_desc-${image_str}_track_weight.csv"

        if [[ ! -f "$weights_image" ]]; then
            Info "Non-linear registration and sampling of ${image_str}"
            #Do_cmd antsBrainExtraction.sh -d 3 -a $image -e "$util_MNIvolumes/MNI152_T1_1mm_brain.nii.gz" -m $MNI152_mask -o "${tmp}/${idBIDS}_${image_str}_"
            Do_cmd bet $image $image_brain -f 0.35
            Do_cmd antsRegistrationSyN.sh -d 3 -f "$T1nativepro_brain" -m "$image_brain" -o "$str_image_syn" -t a -n "$threads" -p d
            #Do_cmd antsApplyTransforms -d 3 -i "$image" -r "$dwi_b0" -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_image_warp" -t "$t1_image_affine" -o "$image_in_dwi" -v --float
            Do_cmd antsApplyTransforms -d 3 -i "$image" -r "$dwi_b0" -t "$dwi_SyN_warp" -t "$dwi_SyN_affine" -t "$t1_image_affine" -o "$image_in_dwi" -v

            #Sampling image
            Do_cmd tcksample $tck $image_in_dwi $weights_image -stat_tck median -force
        else
              Info "Subject ${id} has already sampled ${image_str}"; ((Nsteps++))
        fi

        for seg in "${parcellations[@]}"; do
            parc_name=$(echo "${seg/.nii.gz/}" | awk -F 'atlas-' '{print $2}')
            connectome_str="${dwi_cnntm}/${idBIDS}_space-dwi_atlas-${parc_name}_desc-iFOD2-${tracts}-tractometry-${image_str}"
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
            options="-tck_weights_in $weights_image"
            if [[ ! -f "${connectome_str}_full-connectome.txt" ]]; then
                # Build the Cortical-Subcortical-Cerebellum connectomes
                build_connectomes "$dwi_all" "${connectome_str}_full" "$options"
            fi
        done

        # Change connectome permissions
        chmod 770 -R "$dwi_cnntm"/* 2>/dev/null

    done
fi

# -----------------------------------------------------------------------------------------------
# QC notification of completition
QC_SC
lopuu=$(date +%s)
eri=$(echo "$lopuu - $aloita" | bc)
eri=$(echo print "$eri"/60 | perl)

# Notification of completition
N="$(( 3 + ${#parcellations[*]} * 3))" ### Need to update number of steps
if [ "$Nparc" -eq "$N" ]; then status="COMPLETED"; else status="INCOMPLETE"; fi
Title "DWI-post TRACTOGRAPHY processing ended in \033[38;5;220m $(printf "%0.3f\n" "$eri") minutes \033[38;5;141m:
\tSteps completed : $(printf "%02d" "$Nparc")/$(printf "%02d" "$N")
\tStatus          : ${status}
\tCheck logs      : $(ls "$dir_logs"/SC_*.txt)"
# Print QC stamp
grep -v "${id}, ${SES/ses-/}, SC${tracts}${dwi_str_}" "${out}/micapipe_processed_sub.csv" > "${tmp}/tmpfile" && mv "${tmp}/tmpfile" "${out}/micapipe_processed_sub.csv"
echo "${id}, ${SES/ses-/}, SC${tracts}${dwi_str_}, ${status}, $(printf "%02d" "$Nparc")/$(printf "%02d" "$N"), $(whoami), $(uname -n), $(date), $(printf "%0.3f\n" "$eri"), ${PROC}, ${Version}" >> "${out}/micapipe_processed_sub.csv"
cleanup "$tmp" "$nocleanup" "$here"
