#!/bin/bash
#
#
# copies tSNR files related to rsfMRI time series into a target directory
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

if [ ! -d ${targetdir} ]; then mkdir -p ${targetdir} ;  fi

ls ${sourcedir}/sub-*/ses-*/func/*/volumetric/*_space-func_desc-se_tSNR.txt | xargs -I {} cp {} "$targetdir"
