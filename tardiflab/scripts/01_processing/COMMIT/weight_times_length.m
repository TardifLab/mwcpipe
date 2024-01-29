function weight_length = weight_times_length(weight,length)

     COMMIT_length = dlmread(length); 
     COMMIT_weight = dlmread(weight); 

     if iscolumn(COMMIT_weight) == 0
         COMMIT_weight = transpose(COMMIT_weight);
     end
     
     weight_length = COMMIT_weight.*COMMIT_length; 
end
