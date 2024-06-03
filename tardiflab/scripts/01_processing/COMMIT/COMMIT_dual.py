#!/data_/tardiflab/wenda/programs/localpython/bin/python3.10

import sys
import numpy as np
import commit
from commit import trk2dictionary
import amico

"""
Quick COMMIT dual encoding python code 

# October 2022 Lu Wen Da, McGill
#------------------------------------------------------------------------------------------------------------------------------------
"""

#-----------------------------------#
#------------- SETUP ---------------#
#-----------------------------------#
commit.core.setup() 
# Inputs
ID  		= sys.argv[1]
in_dir   	= sys.argv[2]
tmp_dir     = sys.argv[3]
tractogram 	= sys.argv[4]
dual_file   = sys.argv[5]
bvals       = sys.argv[6]
bvecs       = sys.argv[7]
out_dir     = sys.argv[8]

# Dirs
proj_dir     	= "/data/tardiflab2/wenda/mwc"
subProc_dir  	= proj_dir + "/" + ID + "/proc_dwi"
dict_dir        = out_dir
print(".\n *** DICT OUTPUT: ", dict_dir)

# Files
wm_mask        	= tmp_dir + "/" + ID + "_dual_wm_mask.nii.gz"
confimap        = tmp_dir + "/confidencemap.nii.gz"
scheme 	    	= tmp_dir + "/AMICOscheme.txt"

#------------------------------------
# Import usual COMMIT structure

trk2dictionary.run(
    ndirs                 = 500,
    filename_tractogram   = tractogram,
    filename_mask         = wm_mask,
    TCK_ref_image         = dual_file,
    path_out              = dict_dir,
    fiber_shift           = 0.5,
    min_seg_len           = 1e-3#,
    ## filename_peaks        = 'peaks.nii.gz',#<-- only if I want to use also zeppelin
    ## peaks_use_affine      = True
)

#commit.core.setup(ndirs=500)

# Setting parameters
print('\n Setting parameters \n') 
mit = commit.Evaluation('.', '.')
mit.set_config('doNormalizeSignal', False)
mit.set_config('doMergeB0', False)
mit.set_config('doNormalizeKernels', True)

print('\n Creating the scheme file \n')    
amico.util.fsl2scheme( bvals, bvecs, scheme )
mit.load_data(
        dwi_filename    = dual_file,
        scheme_filename = scheme
)

# Set model and generate the kernel
print('\n Set model and generate the kernel \n')   
mit.set_model( 'StickZeppelinBall' )
d_par = 1.7E-3 # Parallel diffusivity [mm^2/s] for the streamline
d_perp = 0.6E-3 # Perpendicular diffusivity [mm^2/s] for the streamline
d_perps = [] # Perpendicular diffusivities [mm^2/s] for zeppelin in the voxel
d_ISOs = [ 3.0E-3 ] # Isotropic diffusivitie(s) [mm^2/s]
mit.model.set( d_par, d_perps, d_ISOs, d_perp=d_perp) 
mit.generate_kernels( ndirs=500, regenerate=True )
mit.load_kernels()

# Load dictionary and buid the operator
print('\n Load dictionary and buid the operator \n')
mit.load_dictionary( dict_dir )

mit.set_threads(8)
mit.build_operator()

# fitting
print('\n Start fitting \n')
mit.fit( tol_fun=1e-3, max_iter=1000, verbose=True, confidence_map_filename = confimap, confidence_map_rescale=False) 
mit.save_results()
mit.get_coeffs()
