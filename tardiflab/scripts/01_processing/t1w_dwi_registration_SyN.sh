#!/bin/bash
#
# A plug-in for the micapipe module 02_proc-dwi.sh that replaces the T1w-DWI transform computation
# Uses a nonlinear SyN method with 2 equally weighted fixed images
#
# INPUTS:
#       $1 : moving image
# 	$2 : fixed image 1
# 	$3 : fixed image 2
#       $4 : prefix for output filenames
# 	$5 : log filename
#
# 2023 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#-------------------------------------------------------------------------------

# ----------------------- SETUP ------------------------ #
  moving="$1"
  fixed1="$2"
  fixed2="$3"
  dwi_SyN_str="$4"
  log_syn="$5"


  translation="[$fixed1,$moving,1]"
  w8_fixed1="0.5" 																# weights for cost function
  w8_fixed2="0.5"
  sample_fixed1="0.25"																# Proportion of points to sample
  sample_fixed2="0.25"

  RIGIDCONVERG="1000x500x250x100"
  RIGIDSHRINK="8x4x2x1"
  RIGIDSMOOTH="3x2x1x0"

  AFFINECONVERG="1000x500x250x100"
  AFFINESHRINK="8x4x2x1"
  AFFINESMOOTH="3x2x1x0"

  SYNCONVERG="100x100x100"
  SYNTOL="1e-6"
  SYNSHRINK="3x2x1"
  SYNSMOOTH="2x1x0"

# Rigid + Affine + SyN
  antsRegistration --dimensionality 3 \
    --float 0 \
    --output "$dwi_SyN_str" \
    --interpolation BSpline[3] \
    --use-histogram-matching 1 \
    --transform Rigid[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$RIGIDCONVERG",1e-6,10] \
    --shrink-factors "$RIGIDSHRINK" \
    --smoothing-sigmas "$RIGIDSMOOTH" \
    --transform Affine[0.1] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$AFFINECONVERG",1e-6,10] \
    --shrink-factors "$AFFINESHRINK" \
    --smoothing-sigmas "$AFFINESMOOTH" \
    --transform SyN[0.1,3,0] \
    --metric MI["$fixed1","$moving","$w8_fixed1",32,Regular,"$sample_fixed1"] \
    --metric MI["$fixed2","$moving","$w8_fixed2",32,Regular,"$sample_fixed2"] \
    --convergence ["$SYNCONVERG",1e-6,10] \
    --shrink-factors "$SYNSHRINK" \
    --smoothing-sigmas "$SYNSMOOTH" \
    --initial-moving-transform "$translation" \
    --verbose 1 > "$log_syn"

