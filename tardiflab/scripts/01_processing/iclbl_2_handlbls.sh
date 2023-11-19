#/bin/bash
#
# Preps hand label files by adding leading line and moving to melodic dirs
#
# 	$1: subject dir
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Setup
  datadir=$1
  iclbldir=${datadir}/ic_labeling
  if [ ! -d ${iclbldir} ]; then  mkdir -p ${iclbldir}; fi


# Move subjects hand labels files
  for id in {01..10} 18 {20..27} 29; do
	sourcefile=${iclbldir}/sub-${id}/hand_labels_noise.txt
	targloc=${datadir}/sub-${id}/ses-1/ICA_MELODIC/

      # Add leading line
	sed -i 1i"./filtered_func_data.ica" ${sourcefile}

      # Move to subject directory
	cp ${sourcefile} ${targloc}
  done



