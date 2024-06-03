#!/data_/tardiflab/wenda/programs/localpython/bin/python3.10

import sys
import os
import numpy as np
import commit
from commit import trk2dictionary
import amico

"""
# 2023 Wen Da Lu, BIC, Montreal Neurological Institute, McGill
#------------------------------------------------------------------------------------------------------------------------------------
"""

#-----------------------------------#
#------------- SETUP ---------------#
#-----------------------------------#
commit.core.setup()       # precomputes the rotation matrices used internally by COMMIT
# Inputs
ID  		= sys.argv[1]
in_dir   	= sys.argv[2]
tmp_dir     = sys.argv[3]
reg_lambda 	= sys.argv[4]

print(".\n *** Initializing COMMIT for: ", ID)
print(".\n *** Lambda value: ", reg_lambda)

# Dirs
commit_dir      = in_dir + "/COMMIT2"
dict_dir        = commit_dir + "/dict"

# Files
dwi_b0 	    	= in_dir + "/" + ID + "_space-dwi_desc-b0.nii.gz"
tractogram      = in_dir + "/" + ID + "_space-dwi_desc-iFOD2-3M_tractography.tck"
fib_assignment  = tmp_dir + "/" + ID  + "_fibers_assignment.txt"
parcellation    = tmp_dir + "/" + ID  + "_DK-85-full_dwi.nii.gz"
connectome      = tmp_dir + "/" + ID  + "_connectome.csv"
wm_fod         	= tmp_dir + "/" + ID  + "_wm_fod_norm.nii.gz"
wm_mask        	= tmp_dir + "/" + ID  + "_dwi_wm_mask.nii.gz"
dwi_corr       	= tmp_dir + "/" + ID  + "_dwi_upscaled.nii.gz"
bvals        	= tmp_dir + "/" + ID  + "_bvals.txt"
bvecs       	= tmp_dir + "/" + ID  + "_bvecs.txt"
scheme 		    = tmp_dir + "/AMICO.scheme"

#------------------------------------
# Running COMMIT2
#------------------------------------
os.system( 'tck2connectome -force -assignment_radial_search 2 -out_assignments ' + fib_assignment + ' ' + tractogram + ' ' + ' ' + parcellation + ' ' + connectome )

if not os.path.isdir( tmp_dir + "/bundles" ) :
    os.mkdir( "bundles" )
bundles_dir         = tmp_dir + "/bundles"
os.system( 'connectome2tck -force -nthreads 14 -exclusive -files per_edge -keep_self ' + tractogram + ' ' + fib_assignment + ' ' + bundles_dir +'/bundle_' )

C = np.loadtxt( connectome, delimiter=',' ) # NB: change 'delimiter' to suits your needs
CMD = 'tckedit -force -nthreads 14 '
for i in range(C.shape[0]):
    CMD_i = 'tckedit -force -nthreads 14'
    for j in range(i,C.shape[0]):
        if C[i,j] > 0 :
            CMD_i += ' ' + bundles_dir + '/bundle_%d-%d.tck' %(i+1,j+1)
    os.system( CMD_i + ' ' + bundles_dir + '/demo01_fibers_connecting_%d.tck' % (i+1) )

os.system( CMD + bundles_dir + '/demo01_fibers_connecting_*.tck ' + tmp_dir + '/DWI_tractogram_connecting.tck' )

trk2dictionary.run(
    filename_tractogram = tmp_dir + '/DWI_tractogram_connecting.tck',
    filename_mask       = wm_mask,
    fiber_shift         = 0.5,
    path_out            = dict_dir
)

# convert the bvals/bvecs pair to a single scheme file
amico.util.fsl2scheme( bvals, bvecs, scheme )

# load the data
mit = commit.Evaluation( commit_dir, '.' ) 
mit.load_data(
        dwi_filename    = dwi_corr,
        scheme_filename = scheme
)

# use a forward-model with 1 Stick for the streamlines and 2 Balls for all the rest
mit.set_model( 'StickZeppelinBall' )
d_par       = 1.7E-3             # Parallel diffusivity [mm^2/s]
d_perps_zep = []                 # Perpendicular diffusivity(s) [mm^2/s]
d_isos      = [ 1.7E-3, 3.0E-3 ] # Isotropic diffusivity(s) [mm^2/s]
mit.model.set( d_par, d_perps_zep, d_isos )

mit.generate_kernels( regenerate=True )
mit.load_kernels()

# create the sparse data structures to handle the matrix A
mit.load_dictionary( dict_dir )
mit.set_threads()
mit.build_operator()

# perform the fit
mit.fit( tol_fun=1e-3, max_iter=1000 )
mit.save_results( path_suffix="_COMMIT1" )

x_nnls, _, _ = mit.get_coeffs( get_normalized=False )

#Preparing the anatomical prior on bundles
C = np.loadtxt( connectome, delimiter=',' )
C = np.triu( C ) # be sure to get only the upper-triangular part of the matrix
group_size = C[C>0].astype(np.int32)

tmp = np.insert( np.cumsum(group_size), 0, 0 )
group_idx = np.array( [np.arange(tmp[i],tmp[i+1]) for i in range(len(tmp)-1)], dtype=np.object_ )

group_w = np.empty_like( group_size, dtype=np.float64 )
for k in range(group_size.size) :
    group_w[k] = np.sqrt(group_size[k]) / ( np.linalg.norm(x_nnls[group_idx[k]]) + 1e-12 )

#reg_lambda = 5e-4 # change to suit your needs

#Evaluation with the new COMMIT2
prior_on_bundles = commit.solvers.init_regularisation(
    mit,
    regnorms    = [commit.solvers.group_sparsity, commit.solvers.non_negative, commit.solvers.non_negative],
    structureIC = group_idx,
    weightsIC   = group_w,
    lambdas     = [reg_lambda, 0.0, 0.0]
)

mit.fit( tol_fun=1e-3, max_iter=1000, regularisation=prior_on_bundles )
mit.save_results( path_suffix="_COMMIT2" )
