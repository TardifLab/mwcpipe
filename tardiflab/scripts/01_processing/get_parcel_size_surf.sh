#!/bin/bash
#
# get number of vertices and surface are of parcels from surface data
#
# Inputs:
#	$1 : subject ID (integer); doesn't support rescans
#	$2 : parcellation
# 	$3 : hemipshere (lh rh)
#
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Inputs
  SUB=$1
  PARC=$2
  HEMI=$3

# Dirs & paths
  rootdir=/data_/tardiflab/mwc
  mwcpipe_dir=${rootdir}/mwcpipe
  code_dir=${mwcpipe_dir}/tardiflab/scripts/01_processing
  source ${code_dir}/init.sh
  export SUBJECTS_DIR=/data_/tardiflab/01_programs/freesurfer_v7/subjects


# Params
#  SUB="10"
  SUBSESID="Nelson_HC${SUB}"
#  PARC="schaefer-400"
#  HEMI="lh"
  out_file=parc_stats_${PARC}-${HEMI}_sub-${SUB}.txt


# --------- Get Parcel measures

# Output stats for 1 parcelation, hemisphere & subject
  mris_anatomical_stats -a ${mwcpipe_dir}/parcellations/${HEMI}.${PARC}_mics.annot -f ${out_file} ${SUBSESID} ${HEMI}

# Extract num vertices
  out_file_numVertices=num_vertices_${PARC}-${HEMI}_sub-${SUB}.txt
  awk 'NR > 61 {print $2}' ${out_file} > ${out_file_numVertices}   					# skips the 1st 61 lines

# Extract surface area
  out_file_surfArea=surface_area_${PARC}-${HEMI}_sub-${SUB}.txt
  awk 'NR > 61 {print $3}' ${out_file} > ${out_file_surfArea}


# -------- Compute summary stats

# Print out stats
  echo " + ----------- Stats for NUM VERTICES ------------ + "
  python ${code_dir}/get_parcel_size.py "${out_file_numVertices}"

  echo " + ----------- Stats for SURFACE AREA ------------ + "
  python ${code_dir}/get_parcel_size.py "${out_file_surfArea}"

# Remove tmp files
  rm $out_file_surfArea $out_file_numVertices $out_file


