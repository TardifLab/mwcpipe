%% Quick script to obtain alpha factor to calculate MVF
% By Wen Da - April 2023

%%
function alpha = get_alpha(tmp,list)
    subject = readtable(list, 'ReadVariableNames', false, "Delimiter",",");
    subject = table2cell(subject);

    mtsat = [];
    IC_fraction = [];
    FW_fraction = [];

    for a = 1:height(subject)
        sub = char(subject(a,1));
        FA = niftiread(strcat(tmp,'/MVFNODDI_calc/',sub,'_space-dwi_FA_MNI152_1mm_splenium.nii.gz'));
        IC = niftiread(strcat(tmp,'/MVFNODDI_calc/',sub,'_space-dwi_ICVF_MNI152_1mm_splenium.nii.gz'));
        FW = niftiread(strcat(tmp,'/MVFNODDI_calc/',sub,'_space-dwi_FWF_MNI152_1mm_splenium.nii.gz'));
        MT = niftiread(strcat(tmp,'/MVFNODDI_calc/',sub,'_space-dwi_MTsat_MNI152_1mm_splenium.nii.gz'));

        FA = nonzeros(FA);
        IC = nonzeros(IC);
        MT = nonzeros(MT);
        FW = nonzeros(FW);

        mtsat = [mtsat transpose(MT(FA>0.8))];
        IC_fraction = [IC_fraction transpose(IC(FA>0.8))];
        FW_fraction = [FW_fraction transpose(FW(FA>0.8))]

    end 

    g = 0.7;


    MVF = (-g^2.*IC_fraction.*(1-FW_fraction)+IC_fraction.*(1-FW_fraction))./(g^2-g^2.*IC_fraction.*(1-FW_fraction)+IC_fraction.*(1-FW_fraction));
    alpha = MVF./mtsat;
     
    alpha = double(mean(alpha));

end
