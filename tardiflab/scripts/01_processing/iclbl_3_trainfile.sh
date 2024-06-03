#/bin/bash
#
# Produces FIX training file
#
# 	$1: subject directory
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Setup
  source /data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/init.sh

  datadir=$1
  iclbldir=${datadir}/ic_labeling
  ICADIR="ICA_MELODIC"



# Train classifier
  fix -t ${iclbldir}/training.RData \
      -l ${datadir}/sub-01/ses-1/${ICADIR}/ \
         ${datadir}/sub-02/ses-1/${ICADIR}/ \
         ${datadir}/sub-03/ses-1/${ICADIR}/ \
         ${datadir}/sub-04/ses-1/${ICADIR}/ \
         ${datadir}/sub-05/ses-1/${ICADIR}/ \
         ${datadir}/sub-06/ses-1/${ICADIR}/ \
         ${datadir}/sub-07/ses-1/${ICADIR}/ \
         ${datadir}/sub-08/ses-1/${ICADIR}/ \
         ${datadir}/sub-09/ses-1/${ICADIR}/ \
         ${datadir}/sub-10/ses-1/${ICADIR}/ \
         ${datadir}/sub-18/ses-1/${ICADIR}/ \
         ${datadir}/sub-20/ses-1/${ICADIR}/ \
         ${datadir}/sub-21/ses-1/${ICADIR}/ \
         ${datadir}/sub-22/ses-1/${ICADIR}/ \
         ${datadir}/sub-23/ses-1/${ICADIR}/ \
         ${datadir}/sub-24/ses-1/${ICADIR}/ \
         ${datadir}/sub-25/ses-1/${ICADIR}/ \
         ${datadir}/sub-26/ses-1/${ICADIR}/ \
         ${datadir}/sub-27/ses-1/${ICADIR}/ \
         ${datadir}/sub-29/ses-1/${ICADIR}/
