#!/bin/bash
#
# Use to get the number of ICs for each subject prior to manual labeling (post-melodic, pre-fix)
#
#
# INPUTS:
#       $1 : subject directory
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# Settings
  datadir=$1

# File storing outputs
  cd ${datadir}
  echo "Subject_Session,IC_counts" > tmpfile.csv


# Session 1
  ses=1
  for id in {01..30}; do
      subsestag=$(echo "sub-${id}_ses-${ses}")
      nICs=$(sed -n 's/.*Start whitening using  //p' ${datadir}/sub-${id}/ses-${ses}/ICA_MELODIC/filtered_func_data.ica/log.txt | cut -d " " -f 1)

   # Add line to file
     { cat tmpfile.csv; echo "${subsestag},${nICs}"; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv;                        # Highly intelligent method to add newline to csv ;)
  done


# Session 2
  ses=2
  for id in 18 {20..27} 29; do
      subsestag=$(echo "sub-${id}_ses-${ses}")
      nICs=$(sed -n 's/.*Start whitening using  //p' ${datadir}/sub-${id}/ses-${ses}/ICA_MELODIC/filtered_func_data.ica/log.txt | cut -d " " -f 1)

   # Add line to file
     { cat tmpfile.csv; echo "${subsestag},${nICs}"; } > tmpfile2.csv ; rm tmpfile.csv; mv tmpfile2.csv tmpfile.csv;
  done


  mv tmpfile.csv subject_IC_counts.csv;







