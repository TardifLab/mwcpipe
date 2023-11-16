#!/bin/bash
# Resting state preprocessing
# Written by Casey Paquola and Reinder Vos De Wael (Oct 2018).
# and a tiny bit from Sara (Feb 2019)...
# and a whole lot from Sara (August 2019)
# and incorporation to mica-pipe by Raul (August-September 2020)
# and addition of a bunch of fancy flags by Jessica (October-November 2020)
#
# Resting state fMRI processing with bash:
#
# Preprocessing workflow for func.
#
# This workflow makes use of AFNI, FSL, ANTs, FIX
#
# Atlas an templates are avaliable from:
#
# https://github.com/MICA-MNI/micaopen/templates
#
#   ARGUMENTS order:
#   $1 : BIDS directory
#   $2 : participant
#   $3 : Out Directory
#
BIDS=$1
id=$2
out=$3
SES=$4
nocleanup=$5
threads=$6
tmpDir=$7
changeTopupConfig=$8
changeIcaFixTraining=$9
thisMainScan=${10}
thisPhase=${11}
smooth=${12}
mainScanStr=${13}
func_pe=${14}
func_rpe=${15}
performNSR=${16}
performGSR=${17}
noFIX=${18}
sesAnat=${19}
regAffine=${20}
dropTR=${21}
noFC=${22}
PROC=${23}
export OMP_NUM_THREADS=$threads
here=$(pwd)

#------------------------------------------------------------------------------#
# source utilities
source $MICAPIPE/functions/utilities.sh

# Assigns variables names
bids_variables "$BIDS" "$id" "$out" "$SES"

  acq="se"
  tagMRI="se_task-rest_dir-AP_bold"
  func_lab="_space-func_desc-${acq}"
  fmri_tag=desc-se_task-rest_dir-AP_bold

if [[ "$sesAnat" != FALSE  ]]; then
  sesAnat=${sesAnat/ses-/}
  BIDSanat="${subject}_ses-${sesAnat}"
  dir_anat="${out}/${subject}/ses-${sesAnat}/anat"
  dir_volum="${dir_anat}/volumetric"
  dir_conte69="${dir_anat}/surfaces/conte69"
  T1nativepro="${dir_anat}/${BIDSanat}_space-nativepro_t1w.nii.gz"
  T1nativepro_brain="${dir_anat}/${BIDSanat}_space-nativepro_t1w_brain.nii.gz"
  T1nativepro_mask="${dir_anat}/${BIDSanat}_space-nativepro_t1w_brain_mask.nii.gz"
  dir_freesurfer="${dir_surf}/${subject}_ses-${sesAnat}"
  T1freesurfr="${dir_freesurfer}/mri/T1.mgz"
else
  BIDSanat="${idBIDS}"
  dir_anat="${proc_struct}"
fi

# func directories
Info "Obtaining the func acquisition name"
proc_func="$subject_dir/func/${fmri_tag}"
Note "tagMRI:" "${tagMRI}"

#------------------------------------------------------------------------------#
Title "functional MRI processing\n\t\tmicapipe $Version, $PROC "
micapipe_software
bids_print.variables-func
Note "Saving temporal dir:" "$nocleanup"
Note "Parallel processing:" "${threads} threads"
Note "proc_fun outputs:" "${proc_func}"

#	Timer
# Create script specific temp directory
tmp=${tmpDir}/02_proc-func/${subject}/${SES}
Do_cmd mkdir -p "$tmp"

# TRAP in case the script fails
trap 'cleanup $tmp $nocleanup $here' SIGINT SIGTERM

# Define directories
export SUBJECTS_DIR="$dir_surf"

func_volum="${proc_func}/volumetric"   # volumetricOutputDirectory
func_surf="${proc_func}/surfaces"      # surfaceOutputDirectory
if [ -d "${proc_func}/ICA_MELODIC" ]; then
  func_ICA="${proc_func}/ICA_MELODIC";
else
  func_ICA="${tmp}/ICA_MELODIC"      # ICAOutputDirectory
fi


#------------------------------------------------------------------------------#
# Scans to process
func_nii="${func_volum}/${idBIDS}${func_lab}".nii.gz


#------------------------------------------------------------------------------#
func_mc="${func_volum}/${idBIDS}${func_lab}.1D"
func_spikes="${func_volum}/${idBIDS}${func_lab}_spikeRegressors_FD.1D"

#------------------------------------------------------------------------------#
Info "!!!!!  goin str8 to ICA-FIX yo  !!!!!"

fmri_mean="${func_volum}/${idBIDS}${func_lab}_mean.nii.gz"
fmri_HP="${func_volum}/${idBIDS}${func_lab}_HP.nii.gz"
func_brain="${func_volum}/${idBIDS}${func_lab}_brain.nii.gz"
fmri_mask="${func_volum}/${idBIDS}${func_lab}_brain_mask.nii.gz"


#------------------------------------------------------------------------------#
#--------------------------- Tardiflab Mod Section ----------------------------#

  fmri_in_T1nativepro="${proc_struct}/${idBIDS}_space-nativepro_desc-${tagMRI}_mean.nii.gz"
  T1nativepro_in_func="${func_volum}/${idBIDS}_space-func_desc-t1w.nii.gz"
  t1bold="${proc_struct}/${idBIDS}_space-nativepro_desc-t1wbold.nii.gz"

  str_func_SyN="${dir_warp}/${idBIDS}_from-${tagMRI}_to-nativepro_mode-image_desc-SyN_"
  SyN_func_affine="${str_func_SyN}0GenericAffine.mat"
  SyN_func_warp="${str_func_SyN}1Warp.nii.gz"
  SyN_func_Invwarp="${str_func_SyN}1InverseWarp.nii.gz"

  export reg="Affine+SyN"

  transforms="-t ${SyN_func_warp} -t ${SyN_func_affine}" 					# FUNC --> T1w
  transformInv="-t [${SyN_func_affine},1] -t ${SyN_func_Invwarp}"  				# T1w --> FUNC
  xfmat="-t [${SyN_func_affine},1]" 								# T1w --> FUNC  only linear for FIX

  regScript=/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/t1w_func_registration_SyN.sh
  log_syn="${tmp}/${idBIDS}_log_T1w_FUNC_SyN.txt"

# Registration to native pro
  Nreg=$(ls "$SyN_func_affine" "$fmri_in_T1nativepro" "$T1nativepro_in_func" 2>/dev/null | wc -l )
  if [[ "$Nreg" -lt 3 ]]; then
      if [[ ! -f "${t1bold}" ]]; then
            Info "Creating a synthetic BOLD image for registration"
          # Inverse T1w
            Do_cmd ImageMath 3 "${tmp}/${id}_t1w_nativepro_NEG.nii.gz" Neg "$T1nativepro"
          # Dilate the T1-mask
           #Do_cmd ImageMath 3 "${tmp}/${id}_t1w_mask_dil-2.nii.gz" MD "$T1nativepro_mask" 2
          # Masked the inverted T1w
            Do_cmd ImageMath 3 "${tmp}/${id}_t1w_nativepro_NEG_brain.nii.gz" m "${tmp}/${id}_t1w_nativepro_NEG.nii.gz" "$T1nativepro_mask"
          # Match histograms values acording to func
            Do_cmd ImageMath 3 "${tmp}/${id}_t1w_nativepro_NEG-rescaled.nii.gz" HistogramMatch "${tmp}/${id}_t1w_nativepro_NEG_brain.nii.gz" "$func_brain"
          # Smoothing
            Do_cmd ImageMath 3 "$t1bold" G "${tmp}/${id}_t1w_nativepro_NEG-rescaled.nii.gz" 0.35
      else
            Info "Subject ${id} has a synthetic BOLD image for registration"
      fi

    # Compute SyN from FUNC to T1w space ($REGSCRIPT $moving $fixed1 $outprefix $logfile)
      if [[ ! -f "${SyN_func_affine}" ]] || [[ ! -f "${SyN_func_warp}" ]]; then
          Do_cmd "$regScript" "$func_brain" "$t1bold" "$str_func_SyN" "$log_syn"
      else Info "Subject ${id} has a SyN transform T1w <--> FUNC space"; fi

#      Do_cmd rm -rf "${dir_warp}"/*Warped.nii.gz 2>/dev/null

    # fmri to t1-nativepro
      Do_cmd antsApplyTransforms -d 3 -i "$func_brain" -r "$t1bold" -n BSpline "${transforms}"  -o "$fmri_in_T1nativepro" -v --float

    # t1-nativepro to fmri
      Do_cmd antsApplyTransforms -d 3 -i "$T1nativepro_brain" -r "$func_brain" -n BSpline "${transformInv}" -o "$T1nativepro_in_func" -v --float

      if [[ -d "${func_ICA}/filtered_func_data.ica" ]]; then Do_cmd cp "${T1nativepro_in_func}" "${func_ICA}/filtered_func_data.ica/t1w2fmri_brain.nii.gz"; fi
      if [[ -f "${SyN_func_Invwarp}" ]] ; then ((Nsteps++)); fi
  else
      Info "Subject ${id} has a func volume and transformation matrix in T1nativepro space"
  fi

Info "DONE"
