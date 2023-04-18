#/bin/bash
#
# initializes dependencies & paths necessary to run micapipe & related functions
#
#
# 2021 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

# Save OLD PATH
  export OLD_PATH=$PATH

# Declare path vars for all necessary binaries
  export root_dir=/data_/tardiflab
  export softwareDir=${root_dir}/01_programs
  export mrtrixDir=${softwareDir}/mrtrix3
  export AFNIDIR=${softwareDir}/afni
  export ANTSPATH=${softwareDir}/ANTs/bin
  export workbench_path=${softwareDir}/workbench/bin_linux64
  export FSLDIR=${softwareDir}/fsl && source ${FSLDIR}/etc/fslconf/fsl.sh
  export FREESURFER_HOME=${softwareDir}/freesurfer && source $FREESURFER_HOME/FreeSurferEnv.sh
  export FIXPATH=${softwareDir}/fix								# make sure fix knows where to find mcr (see fix/settings.sh, set FSL_FIX_MCRROOT variable)
# export PYTHONPATH=${softwareDir}/anaconda3/bin
  export MATLABPATH=${softwareDir}/matlab
  export RPATH=${softwareDir}/R-3.6.3/bin
  export customBin=${softwareDir}/bin

# Export new PATH with all the necessary binaries
  export PATH="${customBin}:${MATLABPATH}:${RPATH}/bin:${AFNIDIR}:${ANTSPATH}:${workbench_path}:${FREESURFER_HOME}/bin:${mrtrixDir}/bin:${mrtrixDir}/lib:${FSLDIR}/bin:${FIXPATH}:${PATH}"

# Set the libraries paths for mrtrx and fsl (This use of LD_LIBRARY_PATH may be frowned upon :/)
  export LD_LIBRARY_PATH="${FSLDIR}/lib:${FSLDIR}/bin:${mrtrixDir}/lib:${RPATH}/lib"

# Append my R library  			*** (NOT TESTED) ***
  myRLibs=${softwareDir}/Rlibs
  #[[ ! -e $myRLibs ]] && mkdir $myRLibs
  if [ -n "$R_LIBS" ]; then
      export R_LIBS=$myRLibs:$R_LIBS
  else
      export R_LIBS=$myRLibs
  fi

# Language utilities
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8

# Additional Paths
  export mwcdir="${root_dir}/mwc"
  export RAW_DIR="${mwcdir}/bids/rawdata"                                      		# Where you have raw data stored (NOTE: Must adapt $utilities.sh to match file names)
  export OUT_DIR="${mwcdir}/mwcpipe/tardiflab/output"                                   # Where you want derivatives saved
  export MICAPIPE="${mwcdir}/mwcpipe" 							# Where you put all tools incl micapipe
  export scripts="${MICAPIPE}/tardiflab/scripts/01_processing"                          # Location of custom tools that interface with micapipe

  export pyvenv_commit=${softwareDir}/COMMIT_MTR_env 					# Location of virtual environment with dependencies for COMMIT & AMICO

# To run on cluster
  export SGE_ROOT=/opt/sge

# To run mrview in X2go
  export LD_PRELOAD=/opt/nvidia/nsight-systems/2021.3.2/host-linux-x64/Mesa/libGL.so && /opt/mrtrix3/bin/mrview $image
