#!/bin/bash
#
# Useful for getting location of raw & derivative data, as well as code related to the MWC project
# Defines several variables that can be used to quickly access materials
#
# Input:
# 	$1 : subject numeric ID (2 digit e.g., 01, 10, 25, etc)
# 	$2 : session numeric tag (1 digit: 1 or 2)
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Run init file
  source /data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh                                           # Sets the path structure for all the required dependencies

  # NOTE: This creates the following variables which can be used to access code & data
    # root_dir="/data_/tardiflab"                                                                                       # Lab root
    # softwareDir="${root_dir}/01_programs" 										# Location of all relevant software
    # mwcdir="${root_dir}/mwc" 												# Project root
    # RAW_DIR="${mwcdir}/bids" 												# BIDS directory with raw data files
    # OUT_DIR="${RAW_DIR}/derivatives" 											# Processing derivatives
    # MICAPIPE="${mwcdir}/mwcpipe" 											# Internal custom version of micapipe (repo pulled 04.23)
    # scripts="${MICAPIPE}/tardiflab/scripts/01_processing" 								# Custom scripts that interface with & extend micapipe
    # As well as virtual python environments for COMMIT & micapipe

# Code
  proc_script_main=${MICAPIPE}/micapipe 										# The workhorse, sets main variables and calls micapipe modules
  proc_script_util=${MICAPIPE}/functions/utilities.sh 									# Sets variables, paths & subfunctions used by all micapipe modules
  proc_script_func=${MICAPIPE}/functions/02_proc-func.sh 								# rs-fMRI processing module
  proc_script_fc=${MICAPIPE}/functions/03_FC.py 									# functional post-processing & FC computation


# Data
  export ID=$1
  export SES=$2
  export subject="sub-${ID}"
  export ses="ses-${SES}"
  export idBIDS="${subject}_${ses}"

  export subject_dir="${OUT_DIR}/micapipe/${subject}/${ses}"								# micapipe derivatives for each subject
  export proc_func="${subject_dir}/func" 										# micapipe FUNCTIONAL derivatives

  export sub_func_tmp="${OUT_DIR}/micapipe/tmp_micapipe/02_proc-func/${subject}/${ses}" 				# TEMPORARY micapipe functional derivatives
  export func_ICA="${sub_func_tmp}/ICA_MELODIC" 									# Everything for ICA & FIX is here
  export func_ICA_melodic="${func_ICA}/filtered_func_data.ica" 								# melodic outputs to pass to fsleyes

  export func_volum="${proc_func}/desc-se_task-rest_dir-AP_bold/volumetric" 						# Volumetric functional derivatives
  export func_surf="${proc_func}/desc-se_task-rest_dir-AP_bold/surfaces" 						# Surface space functional derivatives

  export func_nii="${func_volum}/${idBIDS}_space-func_desc-se.nii.gz"                                                   # High pass filtered input
  export fmri_HP="${func_volum}/${idBIDS}_space-func_desc-se_HP.nii.gz" 						# High pass filtered output



