#!/bin/bash
#
# Main routing point to call all processing-related functions for all subjects & sessions
# Change the FUNC_ID variable to choose your function.
# All function calls are passed through the cluster (qbatch)
#
# Logs are stored in $log_dir.
# Additional option to gauge resource needs using /usr/bin/time (see bottom)
#
# Input:
#	$1 : FUNC_ID, tag indicating which function to send to qbatch { volumetric, post_structural, dwi, SC, FC, noddi, icvf_conn, conn_slice, tck_gen }
#
# 2021 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

rootdir=/data_/tardiflab/mwc
scriptdir="${rootdir}/mwcpipe/tardiflab/scripts/01_processing"
logdir="${rootdir}/mwcpipe/tardiflab/output/logs"

# Choose function you wish to call for all subs
  FUNC_ID=$1  						#{ volumetric, post_structural, dwi, noddi, SC, FC, noddi, icvf_conn, conn_slice, tck_gen }

# Set options based on desired function
  if [ $FUNC_ID == volumetric ]        ; then VM=6  ;  Fn=1  ; script="${scriptdir}/02_micapipe_call.sh" ; 	# vm=9 works 100% of the time
  elif [ $FUNC_ID == post_structural ] ; then VM=3  ;  Fn=2  ; script="${scriptdir}/02_micapipe_call.sh" ;
  elif [ $FUNC_ID == dwi ]             ; then VM=25 ;  Fn=3  ; script="${scriptdir}/02_micapipe_call.sh" ;
  elif [ $FUNC_ID == noddi ]           ; then VM=10 ;  Fn=4  ; script="${scriptdir}/03_run_noddi.sh" ;
  elif [ $FUNC_ID == SC ]              ; then VM=50 ;  Fn=5  ; script="${scriptdir}/02_micapipe_call.sh" ; 	# VM=5 for 5M tck;  VM=15 for 40M tck
  elif [ $FUNC_ID == commit_prep ]     ; then VM=5  ;  Fn=6  ; script="${scriptdir}/04_run_commit0.sh" ;
  elif [ $FUNC_ID == commit ]          ; then VM=50 ;  Fn=7  ; script="${scriptdir}/04_run_commit1.sh" ;         	# very memory intense, not ideal if tck size > 10-15M streamlines, VM=30 works most of the time
  elif [ $FUNC_ID == connectomes ]     ; then VM=10 ;  Fn=8  ; script="${scriptdir}/05_connectomes.sh" ; 		# VM=3 works most of the time
  elif [ $FUNC_ID == FC ]              ; then VM=20 ;  Fn=9  ; script="${scriptdir}/02_micapipe_call.sh" ;
  elif [ $FUNC_ID == pre_COMMIT ]      ; then VM=10 ;  Fn=10 ; script="${scriptdir}/02_micapipe_call.sh" ;
  elif [ $FUNC_ID == proc_COMMIT ]     ; then VM=40 ;  Fn=11 ; script="${scriptdir}/02_micapipe_call.sh" ;
  elif [ $FUNC_ID == conn_slice ]      ; then VM=5  ;  Fn=00 ; script="${scriptdir}/connSlicer_qbatch.sh" ;
  fi

# directory to store log files
  log_func_dir="${logdir}/$Fn_$FUNC_ID"

<<comm
# Session-1
#  for SUB in {02..17} 19 28 30; do
  for SUB in 17 19 28 30 ; do

	ID=sub-"${SUB}"
	sub_dir="${log_func_dir}/${ID}_ses-1"
	if [ ! -d ${sub_dir} ]; then mkdir -p ${sub_dir} ;  fi
	cd ${sub_dir} 												# cd or logs will output in cwd

	# Call to desired function
#	qbatch -verbose -l h_vmem=${VM}G -N "s${SUB}_1_f${Fn}" ${script} $SUB $FUNC_ID "1" 				# Standard call
	qbatch -q all.q -verbose -l h_vmem=${VM}G -N "s${SUB}_1_f${Fn}" /usr/bin/time --verbose ${script} $SUB $FUNC_ID "1"	# option to gauge resource allocation
  done

comm
# Session-1
  for SUB in 18 {20..27} 29 ; do

        ID=sub-"${SUB}"
        sub_dir="${log_func_dir}/${ID}_ses-1"
        if [ ! -d ${sub_dir} ]; then mkdir -p ${sub_dir} ;  fi
        cd ${sub_dir}                                                                                           # cd or logs will output in cwd

        # Call to desired function
        qbatch -q tardif.q -verbose -l h_vmem=${VM}G -N "s${SUB}_1_f${Fn}" ${script} $SUB $FUNC_ID "1"                            # Standard call
#       qbatch -verbose -l h_vmem=${VM}G -N "s${SUB}_2_f${Fn}" /usr/bin/time --verbose ${script} $SUB $FUNC_ID "1"    # option to gauge resource allocation
  done


# Session-2
  for SUB in 18 {20..27} 29 ; do

        ID=sub-"${SUB}"
        sub_dir="${log_func_dir}/${ID}_ses-2"
        if [ ! -d ${sub_dir} ]; then mkdir -p ${sub_dir} ;  fi
        cd ${sub_dir}                                                                                           # cd or logs will output in cwd

        # Call to desired function
        qbatch -q tardif.q -verbose -l h_vmem=${VM}G -N "s${SUB}_2_f${Fn}" ${script} $SUB $FUNC_ID "2"                            # Standard call
#       qbatch -verbose -l h_vmem=${VM}G -N "s${SUB}_2_f${Fn}" /usr/bin/time --verbose ${script} $SUB $FUNC_ID "2"    # option to gauge resource allocation

  done

