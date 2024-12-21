%% Function to degibbs using RPG
% By Wen Da - April 2023

%%
function degibbs = rpg_degibbs(dwi, dim, pf)
    rpg = rpgdegibbs(); rpg.compilefiles(fullfile('/data_/tardiflab/mwc/mwcpipe/tardiflab/scripts/01_processing/rpg_degibbs/lib')); 
    img_size = size(dwi);
    for a = 1:img_size(4)
        degibbs(:,:,:,a) = rpg.degibbs(dwi(:,:,:,a),dim,pf);
    end

end

