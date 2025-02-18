#!/bin/bash
#
# A plug-in for the micapipe module 02_proc-func.sh that replaces the T1w-FUNC transform computation
# Uses a nonlinear SyN method with an initial translation step to align the images by their geometric center
#
# INPUTS:
#       $1 : moving image
# 	$2 : fixed image 1
#       $4 : prefix for output filenames
# 	$5 : log filename
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# ----------------------- SETUP ------------------------ #
  moving="$1"
  fixed1="$2"
  func_SyN_str="$3"
  log_syn="$4"

  echo "Moving image: $moving"
  echo "Fixed image 1: $fixed1"
  echo "Output prefix: $func_SyN_str"
  echo "Log location: $log_syn"


  translation="[$fixed1,$moving,1]" 												# 0=geometric center; 1=center of mass; 2=origin
  w8_fixed1="1.0" 														# weights for cost function
#  sample_fixed1="0.25"                                                                                                         # Proportion of points to sample
  MIhb="32"                                                                                                                     # histogramBins for MI
  CCpr="4"                                                                                                                      # patchRadius for CC

  RIGIDCONVERG="1000x500x250x100"
  RIGIDTOL="1e-6"
  RIGIDSHRINK="8x4x2x1"
  RIGIDSMOOTH="3x2x1x0vox"

  AFFINECONVERG="500x250x150x50"
  AFFINETOL="1e-6"
  AFFINESHRINK="4x2x1x1"
  AFFINESMOOTH="2x1x0x0vox"

  SYNCONVERG="100x70x50x20"
  SYNTOL="1e-6"
  SYNSHRINK="2x1x1x1"
  SYNSMOOTH="1x0x0x0vox"
  SYNREGULARIZE="0.1"


# Rigid + Affine + SyN
  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$func_SyN_str" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1","$MIhb"] \
    --convergence ["$RIGIDCONVERG","$RIGIDTOL",10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --transform Affine[0.1] \
    --metric CC["$fixed1","$moving","$w8_fixed1","$CCpr"] \
    --convergence ["$AFFINECONVERG","$AFFINETOL",10] \
    --shrink-factors "$AFFINESHRINK" \
    --smoothing-sigmas "$AFFINESMOOTH" \
    --transform SyN["$SYNREGULARIZE",3,0] \
    --metric CC["$fixed1","$moving","$w8_fixed1","$CCpr"] \
    --convergence ["$SYNCONVERG","$SYNTOL",10] \
    --shrink-factors "$SYNSHRINK" \
    --smoothing-sigmas "$SYNSMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1 > "$log_syn"
