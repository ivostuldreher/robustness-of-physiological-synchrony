function [eda_out, badSignal_idx, discard] = preprocess_eda(data, fs)
    %This function is to preprocess EDA signals by removing
    % - signal below a specific treshold,
    % - transitional periods surrounding the above period (e.g. 2 seconds),
    % - and inter-loss periods -- one between two loss periods if being too short (e.g. shorter than 6 seconds),
    %and by applying (cubic) Savitzky-Golay filtering

    %% Defining parameters
    
    discard = false;
    
%     fs = eda_in.srate;
    uS_threshold = 1;           % minimal threshold for discarding data = 1 uS
    expand_area = fs*2;         % transitional period = 2 seconds
    further_expand_area = fs*6; % inter-loss period = 6 seconds
    sg_filter_length = fs*3+1;  % 3 seconds; +1 as only odd number is allowed

    signal = data;
    
    %% Detecting signal-loss period
    idc_zeroValue = find(signal<=uS_threshold);

    diff_idx_zero = diff(idc_zeroValue);
    consecutive_zero_idx = [];
    consecutive_zero_cnt = [];
    counter_zero = 0;
    for m = 1:length(diff_idx_zero)
        if diff_idx_zero(m)==1
            counter_zero = counter_zero+1;
        else
            consecutive_zero_idx = [consecutive_zero_idx idc_zeroValue(m)]; %m is the last index of consecutive 1s
            consecutive_zero_cnt = [consecutive_zero_cnt counter_zero];
            counter_zero = 0;
        end
    end
    if diff_idx_zero(m)==1
        consecutive_zero_idx = [consecutive_zero_idx idc_zeroValue(m)+1]; %m is the last index of consecutive 1s
        consecutive_zero_cnt = [consecutive_zero_cnt counter_zero];
    end

    %% Expansion (transitional period)
    badSignal_idx = zeros(1,sum(~isnan(signal)));
    expanded_edge_idx = [];
    for i_zeroSes = 1:size(consecutive_zero_idx,2)
        range_session = consecutive_zero_idx(i_zeroSes)-consecutive_zero_cnt(i_zeroSes):consecutive_zero_idx(i_zeroSes);
        badSignal_idx(range_session) = 1;


        flag_inside = false;
        if range_session(1)-expand_area > 0
            toExpand = (range_session(1)-expand_area):(range_session(1)-1);
            flag_inside = true;
            badSignal_idx(toExpand) = 1;
        end
        if range_session(end)+expand_area < length(signal)
            toExpand = (range_session(end)+1):(range_session(end)+expand_area);
            flag_inside = flag_inside&true;
            badSignal_idx(toExpand) = 1;
        end
        if flag_inside
            expanded_edge_idx = [expanded_edge_idx; range_session(1)-expand_area range_session(end)+expand_area;];
        end

        %end of expansion code
    end

    %% Further expansion (inter-loss period)

    for i_expand = 2:size(expanded_edge_idx,1)
        if expanded_edge_idx(i_expand,1)-expanded_edge_idx(i_expand-1,2) <= further_expand_area
            toFurtherExpand = expanded_edge_idx(i_expand-1,2):expanded_edge_idx(i_expand,1);
            if ~isempty(toFurtherExpand)

            end
            badSignal_idx(toFurtherExpand) = 1;
        end
    end
    % end of further expansion code

    badSignal_idx = find(badSignal_idx);
    %Replacing with NAN
%     signal(badSignal_idx==1) = NaN;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if length(badSignal_idx) / length(data) > .25
        discard = true;
    end

    %% Savitzky-Golay filtering
    filt_order = 3; %Cubic polynomial
    signal_sg_filt   = sgolayfilt(signal, filt_order, sg_filter_length);
    
    %%Visualization
%     figure;
%     plot(data); hold on;
%     plot(signal);
%     plot(signal_sg_filt);
%     legend('Original','Invalid-rmv','S-G filtered')
%     ylabel('\muS'); xlabel('datapoints');
%    
    eda_out = signal_sg_filt';
    clearvars signal signal_sg_filt
end