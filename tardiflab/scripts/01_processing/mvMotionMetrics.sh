#!/bin/bash
#
#
# copies files quantifying subject motion in rsfMRI data
#
# Inputs:
#	$1 : source directory
#	$2 : target directory
#
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

  sourcedir=$1
  targetdir=$2

# Framewise Displacement output by fsl_motion_outliers
  usedir="${targetdir}/fd"
  if [ ! -d ${usedir} ]; then mkdir -p ${usedir} ;  fi
  ls ${sourcedir}/sub-*/ses-*/func/*/volumetric/*_space-func_desc-se_metric_FD.1D | xargs -I {} cp {} "$usedir"


# Output confound file from fsl_motion_outliers (not generated if no timepoints exceed threshold)
  usedir="${targetdir}/spikes"
  if [ ! -d ${usedir} ]; then mkdir -p ${usedir} ;  fi
  ls ${sourcedir}/sub-*/ses-*/func/*/volumetric/*_space-func_desc-se_spikeRegressors_FD.1D | xargs -I {} cp {} "$usedir"
