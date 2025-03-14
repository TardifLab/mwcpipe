#!/bin/bash
#
# get number of voxels in volumetric parcellation data
#
# Inputs:
#	$1 : subject ID (integer)
# 	$2 : session ID (1 or 2)
#	$3 : parcellation
#
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Inputs
  SUB=$1
  SES=$2
  PARC=$3

  SUBSESID="sub-${SUB}_ses-${SES}"

# Dirs & paths
  rootdir=/data_/tardiflab/mwc
  mwcpipe_dir=${rootdir}/mwcpipe
  code_dir=${mwcpipe_dir}/tardiflab/scripts/01_processing
  source ${code_dir}/init.sh
  sub_dir=${rootdir}/bids/derivatives/micapipe/sub-${SUB}/ses-${SES}

# Params
  out_file=parc_stats_${PARC}_${SUBSESID}.txt


# --------- Get Parcel measures

  PARCELLATION=${sub_dir}/anat/volumetric/${SUBSESID}_space-nativepro_t1w_atlas-${PARC}.nii.gz

# Extracts the voxel counts using the column headers
 # 3dROIstats -nzvoxels -mask $PARCELLATION $PARCELLATION | \
 # awk 'NR==1 {for (i=3; i<=NF; i++) if ($i ~ /^NZcount_/) cols[i]++} NR==2 {for (i in cols) print $i}' > $out_file

# Additionally excludes the L & R medial wall
  3dROIstats -nzvoxels -mask $PARCELLATION $PARCELLATION | \
  awk 'NR==1 {for (i=3; i<=NF; i++) if ($i ~ /^NZcount_/ && $i != "NZcount_1000" && $i != "NZcount_2000") cols[i]++} NR==2 {for (i in cols) print $i}' > $out_file

# -------- Compute summary stats

# Print out stats
  echo " + ----------- Stats for NUM VOXELS ------------ + "
  python ${code_dir}/get_parcel_size.py "${out_file}"


# Remove tmp files
  rm $out_file


