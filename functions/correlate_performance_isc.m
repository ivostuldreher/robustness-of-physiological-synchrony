function [rho, p] = correlate_performance_isc(data, r_to_group, performance, epoch_order_overview, epoch_condition_overview, signals, flagOnlyMovieAttending, varargin)

% 09-11-2021: add outlier removal
% 19-11-2021: add varargin for correlation type

number_participants = length(data);
participant_idc = find(cellfun(@(x) ~isempty(x), {data.marker}));
number_epochs = max(cellfun(@(x) length(x), {data(:).epoch}));
number_signals = length(signals);

% variable input arguments
type = 'pearson';
for ii = 1 : length(varargin)/2
    switch varargin{2*ii-1}
        case 'type', type = varargin{2*ii};
        otherwise, error(['Unknown option ' varargin{2*ii-1} ])
    end
end

for s1 = 1 : number_signals
    
    for e1 = 1 : number_epochs
        
        is_outlier = isoutlier(r_to_group{s1}(:,e1)) | isoutlier(performance(:,e1));
        
        if flagOnlyMovieAttending ~= 0

            participant_group_idc = epoch_condition_overview(epoch_order_overview == e1);
            not_is_nan(:,e1) = ~is_outlier & ~isnan(performance(:,e1)) & ~isnan(r_to_group{s1}(:,e1)) & participant_group_idc == flagOnlyMovieAttending;

        else
            not_is_nan(:,e1) = ~is_outlier & ~isnan(performance(:,e1)) & ~isnan(r_to_group{s1}(:,e1));

        end
    
        [rho(s1,e1), p(s1,e1)] = corr(r_to_group{s1}(not_is_nan(:,e1),e1), performance(not_is_nan(:,e1),e1));
        
    end
    
    r_to_group_all = reshape(r_to_group{s1}, [], 1);
    performance_all = reshape(performance, [], 1);
    
    not_is_nan_all = reshape(not_is_nan, [], 1);%~isnan(performance_all) & ~isnan(r_to_group_all);
    
    [rho(s1,number_epochs+1), p(s1,number_epochs+1)] = corr(r_to_group_all(not_is_nan_all), performance_all(not_is_nan_all), 'type', type);
    
end

end