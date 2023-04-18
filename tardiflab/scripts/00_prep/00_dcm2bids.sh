#!/bin/bash
#
# BIDSifies the MWC data by:
#    1. Using a single subject's config file (sub-06) as a template to generate config files for all other subs
#    2. Runs dcm2bids on all subjects
#    3. Performs the following manual editing of the BIDS file structure
# 	a. Keeps a single T1w scan from those with repeats (cuts other scan) & renames all T1w scans to eliminate "run-#" entity:
# 	   sub-07, scan 2
# 	   sub-08, scan 2
# 	   sub-09, scan 2
# 	   sub-10, scan 2
# 	   sub-20_ses-1, scan 1
# 	   sub-24_ses-2, scan 2
# 	b. 
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Setup
  rootdir="/data_/tardiflab/mwc"
  bidsdir="${rootdir}/bids"
  codedir="${bidsdir}/code"
  rawdir="${bidsdir}/rawdata"

# -----------------------------------------------------------------------------------------------------------------------------------

## 1. Generate config files
      ${codedir}/01_script_mkconfigfiles.sh


# -----------------------------------------------------------------------------------------------------------------------------------


## 2. Run dcm2bids
      ${codedir}/02_dcm2bidscall.sh


# -----------------------------------------------------------------------------------------------------------------------------------


## 3. Handle extra T1w images

      # Remove lower quality scan
  	for SUB in {07..10} ; do
  	    rm ${rawdir}/sub-${SUB}/ses-1/anat/*_run-1_proc-*_T1w.*
  	done
  	rm ${rawdir}/sub-20/ses-1/anat/*_run-2_proc-*_T1w.*
  	rm ${rawdir}/sub-24/ses-2/anat/*_run-1_proc-*_T1w.*

      # Rename T1w files to exclude run-# entity
	find ${rawdir}/*/* -iname "*_run-*_proc-*_T1w.*" -exec rename -v 's/_run-1_/_/g' '{}' \;
	find ${rawdir}/*/* -iname "*_run-*_proc-*_T1w.*" -exec rename -v 's/_run-2_/_/g' '{}' \;
