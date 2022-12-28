% Code corresponding to Stuldreher et al. (2023), Robustness of physiological 
% synchrony in wearable electrodermal activity and heart rate as a measure 
% of attentional engagement to movie clips

% Ivo Stuldreher, Netherlands Organisation for Applied Scientific Research
% (TNO)
% ivo.stuldreher@tno.nl

% How to run:
% Running this main script should provide you with all the figures and
% results as presented in the manuscript. In default, the script will take
% use the raw data, pre-process it, compute inter-subject correlations and
% then present the results. As this can be quite time-consuming depending
% on hardware, we also provide pre-processed data and pre-computed
% inter-subject correlations. Should you want to use that, you can sent the
% variables flag_load_new and flag_compute_synchrony to false.

% Requirements: 
%  - Ledalab (www.ledalab.de)

clearvars; close all;

addpath('./functions')

flag_load_new = true;
flag_compute_synchrony = true;

%% SPECIFY PATHS AND EPOCHS
% specify filepath and find files in the subdirectories corresponding to
% data from each participant
path_to_data = '.\data';
d = dir(path_to_data);
isub = [d(:).isdir] == true;
subdirs = {d(isub).name}';
subdirs(ismember(subdirs,{'.','..'})) = [];
number_subdirs = length(subdirs);

% find defined epoch order for each participant
number_epochs = 6;
epoch_order_condition_table = readtable(fullfile('.\participantorder.xlsx'));
epoch_order_overview = epoch_order_condition_table{:,2:7};
epoch_condition_overview = epoch_order_condition_table{:,9:end};
epoch_title = {'Chauffeur', 'El Mourabbi', 'De Chinese Muur', 'One of the Boys', 'Samual', 'Turn it Around'};
condition_name = {'MA', 'TA'};

%% LOAD DATA
% load raw data and save as .mat file OR load processed data if raw data
% has already been processed
if flag_load_new
    for n1 = 1 : number_subdirs
        path_to_subdir = fullfile(path_to_data, subdirs{n1});
        id = str2double(subdirs{n1}(13:end));

        % load eda
        eda_file_info = dir(fullfile(path_to_subdir, 'eda.bin'));
        if ~isempty(eda_file_info)
            data(id).eda = import_bin(fullfile(path_to_subdir, eda_file_info.name));
        end

        % load hr
        hr_file_info = dir(fullfile(path_to_subdir, '*.fit'));
        if ~isempty(hr_file_info)
            data(id).hr = import_tickr(fullfile(path_to_subdir, hr_file_info.name));
        end

        tmp_data = data(id);
        save(fullfile(path_to_subdir, 'data_raw.mat'), '-struct', 'tmp_data');
        clear tmp_data;
    end
    number_participants = length(data);
else
    for n1 = 1 : number_subdirs
        path_to_subdir = fullfile(path_to_data, subdirs{n1});
        id = str2double(subdirs{n1}(13:end));

        data(id) = load(fullfile(path_to_subdir, 'data_processed.mat'));
    end
    number_participants = length(data);
end

% import event markers, i.e. markers indicating the timestamp of the start
% of each epoch

% initialize variables
marker_time = NaT(number_epochs, 2, number_participants, 'TimeZone', 'Europe/Amsterdam');

for n1 = 1 : number_subdirs

    path_to_subdir = fullfile(path_to_data, subdirs{n1});
    id = str2double(subdirs{n1}(13:end));
    marker_file_info = dir(fullfile(path_to_subdir, 'marker_data.csv'));
    if ~isempty(marker_file_info)

        data(id).marker = readtable(fullfile(path_to_subdir, marker_file_info.name), 'Delimiter', ',');
        data(id).marker.Properties.VariableNames = {'Index' 'EventMarker' 'EventTime'};

        % find indices in markers corresponding to epoch start
        epoch_idc = [];
        iter = 1;
        for iter = 1 : number_epochs
            epoch_idc(iter) = find(cellfun(@(x) ~isempty(x), (strfind(data(id).marker.EventMarker, ['film_', num2str(iter)]))));
        end

        cnt = 0;
        for e1 = epoch_idc

            cnt = cnt + 1;

            % find index in marker corresponding to epoch e1 and save start 
            % and end time of the epochs
            start_time = data(id).marker.EventTime(e1);
            if ~strcmp(data(id).marker.EventMarker(e1+1), 'video_finish')
                fprintf('WARNING: marker order incorrect\n');
            end
            end_time = data(id).marker.EventTime(e1+1);
            marker_time(cnt,1,id) = datetime(start_time, 'ConvertFrom', 'posix', 'TimeZone', 'Europe/Amsterdam');
            marker_time(cnt,2,id) = datetime(end_time, 'ConvertFrom', 'posix', 'TimeZone', 'Europe/Amsterdam');
        end         
    end
end

%% PRE-PROCESSING
% remove unnecessary data from the sets. Only include data from the 60
% seconds before the start until 60 seconds after the end of the experiment
if flag_load_new
    signals = {'hr', 'eda'};
    for n1 = 1 : number_participants

        for s1 = 1 : length(signals)

            if ~isempty(data(n1).(signals{s1}))

                experiment_idc = data(n1).(signals{s1}).time >= min(marker_time(:,1,n1)) - seconds(60) & data(n1).(signals{s1}).time <= max(marker_time(:,2,n1)) + seconds(60);
                data(n1).(signals{s1}).data = data(n1).(signals{s1}).data(experiment_idc); 
                data(n1).(signals{s1}).time = data(n1).(signals{s1}).time(experiment_idc);

            end
        end
    end
end

% pre-process EDA
if flag_load_new
    for n1 = 1 : number_participants

        if isempty(data(n1).eda)
            continue
        end

        path_to_subdir = fullfile(path_to_data, sprintf('participant_%i', n1));

        % pre-process eda by finding signal-loss periods and using s-golay
        % filter to compensate for jitter in the signal following Thammasan et 
        % al. (2020)
        [data(n1).eda.data, data(n1).eda.idc_to_discard, data(n1).eda.discard] = preprocess_eda(data(n1).eda.data, data(n1).eda.fs);

        % decompose phasic and tonic components following Benedek and Kearnbach
        % (2010) and select the phasic component (also known as skin
        % conductance responses - SCR) for further analyses
        decomposition_results = eda_decomposition(data(n1).eda.data, seconds(data(n1).eda.time - data(n1).eda.tstart));
        data(n1).scr = data(n1).eda;
        data(n1).scr.data = decomposition_results.scr;

        % remove signal-loss periods from data;
        data(n1).scr.discard = data(n1).eda.discard;
        data(n1).eda.data(data(n1).eda.idc_to_discard) = nan;
        data(n1).scr.data(data(n1).scr.idc_to_discard) = nan;

        tmp_data = data(n1);
        save(fullfile(path_to_subdir, 'data_processed.mat'), '-struct', 'tmp_data');
        clear tmp_data;

    end
end

% pre-process HR
if flag_load_new
    for n1 = 1 : number_participants

        if isempty(data(n1).hr)
            continue
        end

        path_to_subdir = fullfile(path_to_data, sprintf('participant_%i', n1));

        % pre-process hr by exclusing spurious values and changes
        [data(n1).hr.data, data(n1).hr.discard] = hr_outlier_detection(data(n1).hr.data, data(n1).hr.fs, n1);

        tmp_data = data(n1);
        save(fullfile(path_to_subdir, 'data_processed.mat'), '-struct', 'tmp_data');
        clear tmp_data;

    end
end

% cut physiological data in epochs, where each epoch corresponds to one of
% the six presented movies
signals = {'hr', 'eda', 'scr'};
for n1 = 1 : number_participants

    for s1 = 1 : length(signals)

        if ~isempty(data(n1).(signals{s1}))

            for e1 = 1 : number_epochs

                epoch_idc = data(n1).(signals{s1}).time >= marker_time(e1, 1,n1) & data(n1).(signals{s1}).time <= marker_time(e1, 2,n1);
                data(n1).epoch(e1).(signals{s1}).data = data(n1).(signals{s1}).data(epoch_idc); 
                data(n1).epoch(e1).(signals{s1}).fs = data(n1).(signals{s1}).fs;

            end
        end
    end
end

% compute percentage of removed data
signals = {'hr', 'scr'};
percentage_removed = nan(number_participants, number_epochs,length(signals));
for s1 = 1 : length(signals)
    
    for n1 = 1 : number_participants
        
        if ~isempty(data(n1).(signals{s1}))
            
            for e1 = 1 : number_epochs
                
                percentage_removed(n1,e1,s1) = length(find(isnan(data(n1).epoch(e1).(signals{s1}).data))) / length(data(n1).epoch(e1).(signals{s1}).data);
                
                if strcmp(signals{s1}, 'hr')
                    [~, data(n1).epoch(e1).(signals{s1}).discard] = hr_outlier_detection(data(n1).epoch(e1).(signals{s1}).data, data(n1).epoch(e1).(signals{s1}).fs, n1);
                    if isempty(data(n1).epoch(e1).(signals{s1}).data)
                        data(n1).epoch(e1).(signals{s1}).discard = true;
                    end
                elseif strcmp(signals{s1}, 'scr')
                    [~, ~, data(n1).epoch(e1).(signals{s1}).discard] = preprocess_eda(data(n1).epoch(e1).eda.data, data(n1).epoch(e1).eda.fs);
                    if isempty(data(n1).epoch(e1).(signals{s1}).data)
                        data(n1).epoch(e1).(signals{s1}).discard = true;
                    end
                    
                    if sum(isnan(data(n1).epoch(e1).(signals{s1}).data)) / length(data(n1).epoch(e1).(signals{s1}).data) > 0.3
                        data(n1).epoch(e1).(signals{s1}).discard = true;
                    end
                end               
            end
        end
    end
    
    fprintf('On average %.2f%% (SD: %.2f%%) of %s data was removed\n', nanmean(nanmean(percentage_removed(:,:,s1)))*100, nanstd(nanmean(percentage_removed(:,:,s1), 2))*100, signals{s1})
 
end

signals = {'hr', 'scr'};
fs = [1, 8];
number_signals = length(signals);
number_participants = length(data);

% the data of the same epochs can slightly differ in length across
% participants by just a few samples. We here cut the epochs all to the 
% exact same length by finding the minimum length and the epochs of all
% participant to that length
for s1 = 1 : number_signals
    idc_to_use = cellfun(@(c) ~isempty(c), {data.(signals{s1})});
    for e1 = 1 : number_epochs
    
        max_number_points = mode(arrayfun(@(a) length(a.epoch(e1).(signals{s1}).data), data(idc_to_use)));
        
        for n2 = setdiff(1 : number_participants, find(~idc_to_use))
            data(n2).epoch(e1).(signals{s1}).data_cut = nan(1, max_number_points);
            max_number_points_to_select = min([length(data(n2).epoch(e1).(signals{s1}).data), max_number_points]);
            data(n2).epoch(e1).(signals{s1}).data_cut(1:max_number_points_to_select) = data(n2).epoch(e1).(signals{s1}).data(1:max_number_points_to_select);
            if strcmp(signals{s1}, 'scr')
                data(n2).epoch(e1).(signals{s1}).data_cut = resample(data(n2).epoch(e1).(signals{s1}).data_cut, 8, 32);
            end
        end
    end
end

%% COMPUTE INTER-SUBJECT CORRELATIONS FOR THE INDIVIDUAL MOVIES
% compute dyadic physiological synchrony and circular shuffled synchrony for significance computation
if flag_compute_synchrony
    r = epoch_synchrony(data, signals, 'synchrony_function', 'ps_mwa');
    number_rand = 50;
    r_rand = circular_shuffled_synchrony(data, signals, number_rand, 'synchrony_function', 'ps_mwa');
else   
    load('isc.mat');
end

% compute synchrony to the whole group by averaging over all participants
r_to_group = epoch_synchrony_to_group(data, r, signals);
r_rand_to_group = rand_epoch_synchrony_to_group(data, r_rand, signals, epoch_order_overview, epoch_condition_overview);
[number_participants_above_chance, percentage_participants_above_chance, missing_participants] = plot_synchrony_vs_random_synchrony(data, r_to_group, r_rand_to_group, epoch_order_overview, epoch_condition_overview, epoch_title, signals);

%% CORRELATE INTER-SUBJECT CORRELATIONS WITH QUESTIONNAIRE PERFORMANCE
load('number_correct');
[rho, p] = correlate_performance_isc(data, r_to_group, number_correct, epoch_order_overview, epoch_condition_overview, signals, 0, 'type', 'spearman');
for s1 = 1 : length(signals)
    for e1 = 1 : length(epoch_title)
        fprintf('Correlations between inter-subject correlations in %s during %s and number of correct answers on movie questions: r = %.2f, p = %.3f\n', signals{s1}, epoch_title{e1}, rho(s1,e1), p(s1,e1));
    end
    fprintf('Correlations between inter-subject correlations in %s and number of correct answers on movie questions when aggregating over movies: r = %.2f, p = %.3f\n', signals{s1}, rho(s1,7), p(s1,7));
end

%% COMBINE EPOCHS BASED ON LATING SQAURE
% combine the 10-minute movies into a 60-minute movie clips in six
% different ways based on the latin square here below.
order = [1 2 3 4 5 6; ...
    2 5 4 6 1 3; ...
    5 1 6 3 2 4; ...
    3 4 5 1 6 2; ...
    6 3 2 5 4 1; ...
    4 6 1 2 3 5];
number_orders = size(order, 2);

for s1 = 1 : number_signals
      
    % select indices of participants to use and create empty variable to
    % fill
    data_epochs.(signals{s1}).fs = fs(s1);
    idc_to_use = cellfun(@(c) ~isempty(c), {data.(signals{s1})});
    number_participants_to_use = sum(idc_to_use);
    number_points = sum(cellfun(@(c) length(c.data_cut), {data(3).epoch.(signals{s1})}));
    data_epochs.(signals{s1}).data = nan(6, number_points, number_participants_to_use);
    
    % combine epochs in one large data structure
    cnt = 1;
    for n1 = setdiff(1 : number_participants, find(~idc_to_use))
        for o1 = 1 : number_orders
            data_epochs.(signals{s1}).data(o1,:,cnt) = cell2mat(cellfun(@(c) c.data_cut, {data(n1).epoch(order(o1,:)).(signals{s1})}, 'UniformOutput', false));
        end
        cnt = cnt + 1;
    end
end

%% COMPUTE INTER-SUBJECT CORRELATIONS

% define the varying stimulus duration to compute ISC on. Then define the
% number of stimulus durations, number of iterations and number of
% participants
t_max = [30, 60 : 120 : 1200, 1440 : 240 : 3600]; % [s]
number_max_time = length(t_max);
[number_iterations, ~, number_participants] = size(data_epochs.(signals{s1}).data);

% compute number of calculations for progress bar
number_calculations = cumsum(1:number_participants);
number_calculations = number_calculations(end)*number_iterations;
progress = 1;

% window and step time of moving correlation [s]
wt = 15;
st = 1;

if flag_compute_synchrony
    for s1 = 1 : number_signals

        f = waitbar(0, sprintf('Computing inter-subject correlations for %s...', signals{s1}));

        % initialize ISC structure
        r{s1} = nan(number_participants, number_participants, number_iterations, number_max_time);

        for i1 = 1 : number_iterations

            for n1 = 1 : number_participants

                for n2 = n1+1 : number_participants

                    r_in_time = movingcorrelation(data_epochs.(signals{s1}).data(i1,:,n1)', data_epochs.(signals{s1}).data(i1,:,n2)', data_epochs.(signals{s1}).fs, wt, st);
                    r{s1}(n1,n2,i1,:) = arrayfun(@(t) nanmean(r_in_time(1 : t*st)), t_max);

                    progress = progress + 1;
                    percentual_progress = progress/number_calculations;
                    waitbar(percentual_progress, f, sprintf('Computing inter-subject correlations for %s...', signals{s1}));

                end

            end
        end
        close(f)
    end
else 
    load('isc_latin_square');
end

%% COMPUTE CHANCE LEVEL INTER-SUBJECT CORRELATIONS
number_rand = 50;
number_calculations = cumsum(1:number_participants);
number_calculations = number_calculations(end)*number_iterations*number_rand;
progress = 1;

if flag_compute_synchrony
    for s1 = 1 : number_signals
        r_rand{s1} = nan(number_participants, number_participants, number_iterations, number_max_time, number_rand);

        f = waitbar(0, sprintf('Computing inter-subject correlations for %s...', signals{s1}));

        for i1 = 1 : number_iterations

            for n1 = 1 : number_participants

                for r1 = 1 : number_rand
                    shuffle_position = randi(size(data_epochs.(signals{s1}).data, 2));
                    rand_data = circshift(data_epochs.(signals{s1}).data(i1,:,n1), shuffle_position);

                    for n2 = n1+1 : number_participants

                        r_in_time = movingcorrelation(rand_data', data_epochs.(signals{s1}).data(i1,:,n2)', data_epochs.(signals{s1}).fs, wt, st);
                        r_rand{s1}(n1,n2,i1,:,r1) = arrayfun(@(t) nanmean(r_in_time(1 : t*st)), t_max);

                        progress = progress + 1;
                        percentual_progress = progress/number_calculations;
                        waitbar(percentual_progress, f, sprintf('Computing inter-subject correlations for %s...', signals{s1}));

                    end
                end

            end
        end
        close(f)
    end
end

% mirror inter-subject correlation matrices across diagonal
for s1 = 1 : number_signals
    for t1 = 1 : number_max_time
        for i1 = 1 : number_iterations
            for r1 = 1 : number_rand
                r_rand{s1}(:,:,i1,t1,r1) = triu(r_rand{s1}(:,:,i1,t1,r1))' + triu(r_rand{s1}(:,:,i1,t1,r1));
                r{s1}(:,:,i1,t1) = triu(r{s1}(:,:,i1,t1))' + triu(r{s1}(:,:,i1,t1));
            end
        end
    end
end

%% COMPUTE INTER-SUBJECT CORRELATIONS TOWARDS THE GROUP
number_rand_participant_combinations = 50;

for s1 = 1 : number_signals
    
    participant_to_use = find(~all(isnan(r{s1}(:,:,1,1))));
    number_participants_to_use = length(participant_to_use);
    
    percentage_significant{s1} = nan(number_max_time, number_participants_to_use, number_rand_participant_combinations, number_iterations);

    for t1 = 1 : number_max_time

        for n2 = 2 : number_participants_to_use

            for r2 = 1 : number_rand_participant_combinations

                pp_idc = randsample(participant_to_use, n2);

                r_to_group_tmp = nan(length(pp_idc), number_iterations);
                r_rand_to_group_tmp = nan(length(pp_idc), number_iterations, number_rand);
                for i1 = 1 : number_iterations

                    r_to_group_tmp(:,i1) = nanmean(r{s1}(pp_idc,pp_idc,i1,t1), 2);

                    r_rand_to_group_tmp(:,i1,:) = squeeze(nanmean(r_rand{s1}(pp_idc,pp_idc,i1,t1,:), 2));

                end

                h = nan(size(r_to_group_tmp, 1), number_iterations);
                for n1 = size(r_to_group_tmp, 1) : -1 : 1
                    [h(n1,:), ~] = ttest2(r_to_group_tmp(n1,:), squeeze(squeeze(r_rand_to_group_tmp(n1,:,:))'), 'Dim', 1, 'tail', 'right');
                end

                percentage_significant{s1}(t1,n2,r2,:) = nansum(h)./sum(~isnan(h));

            end
        end
    end

    mean_percentage_significant{s1} = nanmean(nanmean(percentage_significant{s1}, 3), 4);
    total_amount_data{s1} = ((1:number_participants_to_use).*t_max')/60;
end

%% plot effect of stimulus duration
% standard deviation across movies
for s1 = 1 : number_signals
    participant_to_use = find(~all(isnan(r{s1}(:,:,1,1))));
    number_participants_to_use = length(participant_to_use);
    std_percentage_significant = nanstd(nanmean(percentage_significant{s1}, 3), [], 4);

    fig = figure;
    ax = axes('parent', fig, ...
        'ylim', [0, 100], ...
        'fontname', 'arial', 'fontsize', 14);
    hold(ax, 'all');
    xlabel('Stimulus duration [s]');
    ylabel('Participants with significant ISC [%]')
    color = colormap(flipud(copper(number_participants_to_use)));

    for n1 = 1 : number_participants_to_use
    plot(ax, ...
        t_max, 100*mean_percentage_significant{s1}(:,n1), ...
        'color', color(n1,:), 'linewidth', 1.5);
    if n1 < 7 
        text(ax, ...
            t_max(end), 100*mean_percentage_significant{s1}(end,n1), num2str(n1));
    end
    
    end
    c = colorbar('ticks', [0, 1], 'ticklabels', {'2', num2str(sum(~all(isnan(mean_percentage_significant{s1}))))});
    c.Label.String = 'Group size';
    c.Label.FontSize = 14;
    c.Label.FontName = 'Arial';

    print(fig, sprintf('./figures/%s_isc_significance_stimulus_duration.png', signals{s1}), '-dpng', '-r300')
    
    fig = figure;
    ax = axes('parent', fig, ...
        'ylim', [0, 40], ...
        'fontname', 'arial', 'fontsize', 14);
    hold(ax, 'all');
    xlabel('Stimulus duration [s]');
    ylabel('SD_{movies} [%]')
    color = colormap(flipud(copper(number_participants_to_use)));
    for n1 = 1 : number_participants_to_use
    plot(ax, ...
        t_max, 100*std_percentage_significant(:,n1), ...
        'color', color(n1,:), 'linewidth', 1.5);
    end
    c = colorbar('ticks', [0, 1], 'ticklabels', {'2', num2str(sum(~all(isnan(mean_percentage_significant{s1}))))});
    c.Label.String = 'Group size';
    c.Label.FontSize = 14;
    c.Label.FontName = 'Arial';
    print(fig, sprintf('./figures/%s_std_isc_significance_stimulus_duration.png', signals{s1}), '-dpng', '-r300')
    
end
%% plot effect of group size
% standard deviation across smaller groups
for s1 = 1 : number_signals
    participant_to_use = find(~all(isnan(r{s1}(:,:,1,1))));
    number_participants_to_use = length(participant_to_use);
    
    std_percentage_significant = nanstd(nanmean(percentage_significant{s1}, 4), [], 3);

    fig = figure;
    ax = axes('parent', fig, ...
        'fontname', 'arial', 'fontsize', 14, ...
        'ylim', [0, 100]);
    hold(ax, 'all');
    xlabel('Group size');
    ylabel('Participants with significant ISC [%]')
    color = colormap(flipud(copper(number_max_time)));

    for t1 = 1 : number_max_time
        plot(ax, ...
            1:number_participants_to_use, 100*mean_percentage_significant{s1}(t1,:), ...
            'color', color(t1,:), 'linewidth', 1.5);
    if t1 < 4 
        text(ax, ...
            number_participants_to_use, 100*mean_percentage_significant{s1}(t1,end), num2str(t_max(t1)));
    end
    end
    c = colorbar('ticks', [0, 1], 'ticklabels', {'30', '3600'});
    c.Label.String = 'Stimulus duration [s]';
    c.Label.FontSize = 14;
    c.Label.FontName = 'Arial';

    print(fig, sprintf('./figures/%s_isc_significance_group_size.png', signals{s1}), '-dpng', '-r300')
    
    fig = figure;
    ax = axes('parent', fig, ...
        'ylim', [0, 40], ...
        'fontname', 'arial', 'fontsize', 14);
    hold(ax, 'all');
    xlabel('Group size');
    ylabel('SD_{subgroups} [%]')
    color = colormap(flipud(copper(number_max_time)));
    for t1 = 1 : number_max_time
        plot(ax, ...
            1:number_participants_to_use, 100*std_percentage_significant(t1,:), ...
            'color', color(t1,:), 'linewidth', 1.5);
    end
    c = colorbar('ticks', [0, 1], 'ticklabels', {'30', '3600'});
    c.Label.String = 'Stimulus duration [s]';
    c.Label.FontSize = 14;
    c.Label.FontName = 'Arial';
    print(fig, sprintf('./figures/%s_std_isc_significance_group_size.png', signals{s1}), '-dpng', '-r300')
end
%% plot effect of total data
% standard deviation across all combination of subgroups and movies
for s1 = 1 : number_signals
    participant_to_use = find(~all(isnan(r{s1}(:,:,1,1))));
    number_participants_to_use = length(participant_to_use);
    std_percentage_significant = nanstd(reshape(percentage_significant{s1}, [number_max_time, number_participants_to_use, number_iterations*number_rand_participant_combinations]), [], 3);

    fig = figure;
    ax = axes('parent', fig, ...
        'fontsize', 14, 'fontname', 'arial', ...
        'ylim', [0, 100], 'xlim', [0, 1800]);
    hold(ax, 'all');
    xlabel('Data [min]')
    ylabel('Participants with significant ISC [%]')
    color = colormap(flipud(copper(number_participants)));

    for n1 = 1 : number_participants_to_use

        fill( [t_max*n1/60, fliplr(t_max*n1/60)], 100*[mean_percentage_significant{s1}(:,n1)' - std_percentage_significant(:,n1)', fliplr(mean_percentage_significant{s1}(:,n1)' + std_percentage_significant(:,n1)')], color(n1,:), ...
            'linestyle', 'none', 'facealpha', .05);

    end

    for n1 = 1 : number_participants_to_use
        for t1 = 1 : number_max_time
            plot( t_max(t1)*n1/60, 100*mean_percentage_significant{s1}(t1,n1), 'marker', 'o', 'color', color(n1,:), 'markerfacecolor', color(n1,:), 'markersize', sqrt(t_max(t1))/7);
        end
    end

    cnt = 1;
    for t1 = 1 : 5 : number_max_time
        p_leg(cnt) = plot(nan, nan, 'marker', 'o', 'color', 'black', 'markerfacecolor', 'black', 'markersize', sqrt(t_max(t1))/7, 'linestyle', 'none');
        cnt = cnt + 1;
    end

    lgd = legend(p_leg, arrayfun(@(a) num2str(a), t_max(1 : 5 : number_max_time)/60, 'UniformOutput', false), 'location', 'SE');
    title(lgd, 'Stimulus duration [min]', 'FontSize', 12)

    c = colorbar('ticks', [0, 1], 'ticklabels', {'2', num2str(sum(~all(isnan(mean_percentage_significant{s1}))))});
    c.Label.String = 'Group size';
    c.Label.FontSize = 14;
    c.Label.FontName = 'Arial';

    print(fig, sprintf('./figures/%s_isc_significance_total_data.png', signals{s1}), '-dpng', '-r300')
end

%% FUNCTIONS

function [rho] = movingcorrelation(data1, data2, fs, wt, st)

% convert seconds to samples
ws = wt * fs;
ss = st * fs;

% build filter coefficient to estimate the slope
p = mod(ws, 2);
s = (ws - p) / 2;

% calculate moving window correlation with window size 'ws' and step increment of
% 'ss' by taking the mean of the gradient within 'ws'
rho = zeros(ceil(length(data1)/ss), 1);
for j = 1 : ss : s
    rho(ceil(j/ss)) = corr(data1(1:j+s), data2(1:j+s));
end
for j = s+1 : ss : length(data1) - s
    rho(ceil(j/ss)) = corr(data1(j-s:j+s), data2(j-s:j+s));
end
for j = length(data1) - s + 1 : ss : length(data1)
    rho(ceil(j/ss)) = corr(data1(j-s:end), data2(j-s:end));
end

end
