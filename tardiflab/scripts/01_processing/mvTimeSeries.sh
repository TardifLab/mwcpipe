#!/bin/bash
#
#
# copies rsfMRI time series into a target directory
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

ls ${sourcedir}/sub-*/ses-*/func/*/surfaces/*_func_space-conte69-32k_desc-timeseries_clean.txt | xargs -I {} cp {} "$targetdir"
