%% Quick script to obtain diffusion metrics
% By Wen Da - September 2024

%%
function diff = get_diff(metric,FA,FA_range)

    metric_img = niftiread(metric);
    FA_img = niftiread(FA);

    metric_value = nonzeros(metric_img);
    FA_value = nonzeros(FA_img);

    diff = metric_value(FA_value > FA_range(1) & FA_value < FA_range(2));
    diff = mean(diff);
end
