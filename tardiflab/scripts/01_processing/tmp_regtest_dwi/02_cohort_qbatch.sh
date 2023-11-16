#!/bin/bash
#
# Runs ANTs SyN registration for the whole cohort on the batch
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

  rootdir=/data_/tardiflab/mwc/bids/derivatives/micapipe/tmp_micapipe/02_proc-dwi

  vm=15
#  script=/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/tmp_regtest/regtest_dwi_t1w_testANTs_cohort.sh
#  meth="ants_final"

  script=/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/tmp_regtest/regtest_dwi_t1w_testANTs_cohort2.sh
  meth="ants_comboFOD"

# Session-1
  SES="1"
#  for SUB in {01..09} {11..30} ; do
  for SUB in 10 ; do

      # Create dirs
	testdir=${rootdir}/sub-${SUB}/ses-${SES}/tmpregtest
 	testdir_xfm=${testdir}/${meth}/xfms
  	testdir_anat=${testdir}/${meth}/anat
  	testdir_dwi=${testdir}/${meth}/dwi
  	testdir_tmp=${testdir}/${meth}/tmp
	testdir_log=${testdir}/${meth}/qbatchlogs

  	if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
  	if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
  	if [[ ! -d ${testdir_dwi} ]]  ; then mkdir -p ${testdir_dwi} ; fi
  	if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi
	if [[ ! -d ${testdir_log} ]]  ; then mkdir -p ${testdir_log} ; fi

	cd ${testdir_log}

      # Call to desired function
	qbatch -verbose -l h_vmem=${vm}G -N "sub-${SUB}_ses-${SES}" /usr/bin/time --verbose "$script" "$SUB" "$SES"
  done


# Session-2
#  SES="2"
#  for SUB in 18 {20..27} 29 ; do

      # Create dirs
#        testdir=${rootdir}/sub-${SUB}/ses-${SES}/tmpregtest
#        testdir_xfm=${testdir}/${meth}/xfms
#        testdir_anat=${testdir}/${meth}/anat
#        testdir_dwi=${testdir}/${meth}/dwi
#        testdir_tmp=${testdir}/${meth}/tmp
#        testdir_log=${testdir}/${meth}/qbatchlogs

#        if [[ ! -d ${testdir_xfm} ]]  ; then mkdir -p ${testdir_xfm} ; fi
#        if [[ ! -d ${testdir_anat} ]] ; then mkdir -p ${testdir_anat} ; fi
#        if [[ ! -d ${testdir_dwi} ]]  ; then mkdir -p ${testdir_dwi} ; fi
#        if [[ ! -d ${testdir_tmp} ]]  ; then mkdir -p ${testdir_tmp} ; fi
#        if [[ ! -d ${testdir_log} ]]  ; then mkdir -p ${testdir_log} ; fi

#        cd ${testdir_log}

      # Call to desired function
#        qbatch -verbose -l h_vmem=${vm}G -N "sub-${SUB}_ses-${SES}" /usr/bin/time --verbose "$script" "$SUB" "$SES"
#  done
