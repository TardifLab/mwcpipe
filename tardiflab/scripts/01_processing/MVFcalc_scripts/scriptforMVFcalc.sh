source /data_/tardiflab/wenda/programs/micapipe-mod/scripts/init.sh 

SUB=/data/tardiflab2/wenda/mwc/list

cat $SUB|while read line; do

    antsApplyTransforms -d 3 -n NearestNeighbor -i /data/tardiflab2/wenda/mwc/splenium.nii.gz -r /data/tardiflab2/wenda/mwc/${line}/proc_struct/${line}_t1w_1.0mm_nativepro_brain.nii.gz -t [/data/tardiflab2/wenda/mwc/${line}/xfms/${line}_t1w_1.0mm_nativepro_brain_to_1.0mm_MNI152_SyN_brain_0GenericAffine.mat,1] -t /data/tardiflab2/wenda/mwc/${line}/xfms/${line}_t1w_1.0mm_nativepro_brain_to_1.0mm_MNI152_SyN_brain_1InverseWarp.nii.gz -o /data/tardiflab2/wenda/mwc/${line}/proc_struct/${line}T1splenium.nii -v

    antsApplyTransforms -d 3 -n NearestNeighbor -i /data/tardiflab2/wenda/mwc/${line}/proc_struct/${line}T1splenium.nii -r /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}_dwi_b0.nii.gz -t [/data/tardiflab2/wenda/mwc/${line}/xfms/${line}_dwi_to_nativepro_0GenericAffine.mat, 1] -o /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}dwisplenium.nii -v

    fslmaths /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}_mtsat_in_dwi.nii.gz -mul /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}dwisplenium.nii -nan /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}mtsatsplenium.nii

    mrconvert /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}_dti_FA.mif /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}_dti_FA.nii.gz -force
    fslmaths /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}_dti_FA.nii.gz -mul /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}dwisplenium.nii -nan /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}FAsplenium.nii

    fslmaths /data/tardiflab2/wenda/mwc/${line}/proc_dwi/sc/commit2/dict/Results_StickZeppelinBall_COMMIT1/compartment_IC.nii.gz -mul /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}dwisplenium.nii -nan /data/tardiflab2/wenda/mwc/${line}/proc_dwi/${line}ICsplenium.nii

done
