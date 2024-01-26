#!/bin/bash
#
# Runs ANTs SyN registration for the whole cohort on the batch
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

  rootdir=/data_/tardiflab/mwc/bids/derivatives/micapipe/tmp_micapipe/02_proc-func

  vm=15
#  vm=5

  script=/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/tmp_regtest_func/regtest_func_t1w_synthseg.sh

# Loop
  SES="1"
#  SES="2"
#  for SUB in {02..30} ; do
#  for SUB in 18 {20..27} 29 ; do
  for SUB in 01 ; do

      # Create dirs
	testdir=${rootdir}/sub-${SUB}/ses-${SES}/tmpregtest_synthseg
	testdir_log=${testdir}/qbatchlogs
	if [[ ! -d ${testdir_log} ]]  ; then mkdir -p ${testdir_log} ; fi

 	testdir_xfm=${testdir}/${newmeth}/xfm

  	if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi

	cd ${testdir_log}

      # Call to desired function
	qbatch -verbose -l h_vmem=${vm}G -N "sub-${SUB}_ses-${SES}" /usr/bin/time --verbose "$script" "$SUB" "$SES"
  done


