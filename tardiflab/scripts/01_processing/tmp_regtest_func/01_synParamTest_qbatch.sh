#!/bin/bash
#
# Runs ANTs SyN registration testing for a range of parameter combinations on the batch
#
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

  id="10"
  SES="1"
  vm=15
  script=/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/tmp_regtest_func/regtest_func_t1w_testANTs_syn.sh

#  declare -a SYNCONVERG=("100x70x50x20" "200x150x100x50" "300x200x150x100")
#  declare -a SYNSHRINK=("8x4x2x1" "6x4x2x1" "4x3x2x1")
#  declare -a SYNSMOOTH=("5x3x2x0" "4x3x1x0" "3x2x1x0")

#  declare -a SYNCONVERG=("50x20" "100x50" "150x100")
#  declare -a SYNSHRINK=("4x1" "3x1" "2x1")
#  declare -a SYNSMOOTH=("3x0" "2x0" "1x0")

#  declare -a SYNCONVERG=( "10x10" "10x20" "10x50" "10x100"  "20x10" "20x20" "20x50" "20x100"  "50x10"  "50x20"  "50x50"  "50x100")
#  declare -a SYNSHRINK=("4x1"  "2x1")
#  declare -a SYNSMOOTH=("3x0"  "1x0")


  logdir=/data_/tardiflab/mwc/bids/derivatives/micapipe/tmp_micapipe/02_proc-func/sub-${id}/ses-${SES}/tmpregtest_testANTs/ants_3_synparams/qbatchlogs

  if [[ ! -d ${logdir} ]]  ; then mkdir -p ${logdir} ; fi

  cd ${logdir}

S1=4; S2=0; S3=0;

for i in "${SYNCONVERG[@]}" ; do

    S1=$((S1+1))

    for j in "${SYNSHRINK[@]}" ; do

	S2=$((S2+1))

	for k in "${SYNSMOOTH[@]}" ; do
		S3=$((S3+1))
#		echo "SYNCONVERG: ${i}; SYNSHRINK: ${j}; SYNSMOOTH: ${k}; S1=$S1; S2=$S2; S3=$S3"
		it="${S1}_${S2}_${S3}"
		qbatch -verbose -l h_vmem=${vm}G -N "srt_${S1}_${S2}_${S3}" /usr/bin/time --verbose "$script" "$id" "$SES" "$i" "$j" "$k" "$it"

	done
    done
done
