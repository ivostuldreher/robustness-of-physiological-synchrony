function [number_participants_above_chance, percentage_participants_above_chance, missing_participants] = plot_synchrony_vs_random_synchrony(data, r_to_group_cond, r_rand_to_group, epoch_order_overview, epoch_condition_overview, epoch_title, signals, varargin)

% 08-12-21: add plot as variable input argument

flag_plot = true; flag_ma_only = false;
for ii = 1 : length(varargin)/2
    switch varargin{2*ii-1}
        case 'plot', flag_plot = varargin{2*ii};
        case 'onlyMA', flag_ma_only = varargin{2*ii};
        otherwise, error(['Unknown option ' varargin{2*ii-1} ])
    end
end

number_participants = max(cellfun(@(x) length(x), r_to_group_cond));
participant_idc = find(cellfun(@(x) ~isempty(x), {data.marker}));
number_epochs = max(cellfun(@(x) length(x), {data(:).epoch}));
number_freq = max(cellfun(@(x) size(x, 3), r_to_group_cond));
number_conditions = max(cellfun(@(x) size(x, 4), r_to_group_cond));
color = {'none', 'none'; 'black', 'black'};

epoch_order_overview = epoch_order_overview';
epoch_condition_overview = epoch_condition_overview';


h_test = nan(length(signals), number_epochs, number_participants, number_freq);

 missing_participants = zeros(30, number_epochs, length(signals));

for sig = 1 : length(signals)
    
    not_isempty = cellfun( @(x) ~isempty(x), {data(participant_idc).(signals{sig})});
    participant_idc_to_use = participant_idc(not_isempty);
    
%     not_discard = cellfun(@(x) ~x.discard, {data(participant_idc_to_use).(signals{sig})});
    discard = cellfun(@(x) x.discard, {data(participant_idc_to_use).(signals{sig})});
%     participant_idc_to_use = participant_idc_to_use(not_discard);
    
    number_rand = length(r_rand_to_group{sig});
    r_rand_to_group_epoch_with_nan = nan(length(r_rand_to_group{sig}), number_participants, number_epochs);
    
    for f1 = 1 : number_freq
    
        % initialize figure handle
        if flag_plot
            fig = figure('position', [0, 0, 1376, 768]);
        end
        
        for e1 = 1 : number_epochs

            if flag_plot
                % initialize subplot axes handle
                ax(e1) = subplot(2, number_epochs/2, e1, ...
                    'parent', fig);
            end

            epoch_idc = epoch_order_overview == e1;
            epoch_condition = epoch_condition_overview(epoch_idc);

            % select randomized synchrony to epoch e1 and permute data to have
            % data of each participant in a column
            c1 = 1;
            r_rand_to_group_epoch_with_nan(:,:,e1) = squeeze(permute(r_rand_to_group{sig}(:,:,e1,f1,c1), [2,1,3,4,5]));

            % remove columns containing NaNs from the randomized data
            r_rand_to_group_epoch = r_rand_to_group_epoch_with_nan(:, participant_idc_to_use, e1);
            missing_epoch = find(all(isnan(r_rand_to_group_epoch)));
%             r_rand_to_group_epoch(:,missing_epoch) = [];
            r_rand_to_group_epoch(:,[missing_epoch, find(discard)]) = 10;
            
            missing_participants(unique([missing_epoch, find(discard)]), e1,sig) = 1;

            % create violin plot with randomized data
            if flag_plot
                [h, l] = violin(r_rand_to_group_epoch, 'facecolor', 'black', 'edgecolor', 'none', 'facealpha', .5, 'medc', '');  
            end

            cnt = 1;
            for n1 = participant_idc_to_use
%                 setdiff(participant_idc_to_use, missing_epoch)

                if ~isnan(r_to_group_cond{sig}(n1,e1)) & ~any(participant_idc_to_use(missing_epoch) == n1) & ~any(participant_idc_to_use(discard) == n1)

                    % test for significant differences between synchrony value
                    % and randomized synchrony distribution
                    h_test(sig,e1,n1,f1) = ttest2(r_to_group_cond{sig}(n1,e1,f1,c1), squeeze(r_rand_to_group{sig}(n1,:,e1,f1,c1)), 'tail', 'right');

                    % plot participant synchrony value on top of violin
                    % distribution with filling of marker based on p-value
                    if ~isnan(h_test(sig,e1,n1,f1)) & flag_plot
                        plot(cnt, r_to_group_cond{sig}(n1,e1,f1,c1), 'color', color{2, epoch_condition(n1)}, 'marker', 'o', 'markerfacecolor', color{h_test(sig,e1,n1,f1)+1, epoch_condition(n1)});
                    end


                else
                    
                    plot(cnt, 0, 'color', color{2, epoch_condition(n1)}, 'marker', 'x');
                    
                end
                cnt = cnt + 1;

                if flag_plot
                    set(ax(e1), 'ylim', [-.1, .2], 'xtick', [], 'fontsize', 10);
                    title(epoch_title{e1});

                    if mod(e1,number_epochs/2) == 1
                        ylabel('Inter-subject correlation', 'fontsize', 10);
                    end
                end

            end
            
            if flag_ma_only
                number_participants_above_chance(sig,e1,f1) = sum(squeeze(h_test(sig,e1,:,f1) == 1) & epoch_condition == 1);
                percentage_participants_above_chance(sig,e1,f1) = sum(squeeze(h_test(sig,e1,:,f1) == 1) & epoch_condition == 1) / sum(squeeze(h_test(sig,e1,:,f1) == 0 | h_test(sig,e1,:,f1) == 1) & epoch_condition == 1);
            else
                number_participants_above_chance(sig,e1,f1) = sum(h_test(sig,e1,:,f1) == 1);
                percentage_participants_above_chance(sig,e1,f1) = sum(h_test(sig,e1,:,f1) == 1) / sum(h_test(sig,e1,:,f1) == 0 | h_test(sig,e1,:,f1) == 1);
            end
            
        epoch_condition_all(e1,:) = epoch_condition;
            
        end
    end
       
    if flag_ma_only
       r_rand_to_group_epoch_with_nan = permute(r_rand_to_group_epoch_with_nan, [3,2,1]);
       epoch_condition_all_rand = [];
       for r1 = 1 : number_rand
           epoch_condition_all_rand(:,:,r1) = epoch_condition_all;
       end
       r_rand_to_group_epoch_with_nan(epoch_condition_all_rand == 1) = nan;
       r_rand_to_group_epoch_with_nan = permute(r_rand_to_group_epoch_with_nan, [3,2,1]);
    end
    
    r_rand_to_group_all = reshape(permute(r_rand_to_group_epoch_with_nan, [1,3,2]), number_rand*number_epochs, number_participants);
    r_to_group_all = permute(r_to_group_cond{sig}, [2,1]);
    
    if flag_ma_only
        r_to_group_all(epoch_condition_all == 1) = nan;
%         r_rand_to_group_epoch_with_nan([, epoch_condition_all']) = nan;
    end
    
     % remove columns containing NaNs from the randomized data and real
     % data
    r_rand_to_group_all = r_rand_to_group_all(:, participant_idc_to_use);
    r_to_group_all = r_to_group_all(:, participant_idc_to_use);
    
    % remove NaNs
    idc_to_use = ~(all(isnan(r_to_group_all)) | all(isnan(r_rand_to_group_all)));
    r_rand_to_group_all = r_rand_to_group_all(:, idc_to_use);
    r_to_group_all = r_to_group_all(:, idc_to_use);
    
%     if flag_plot
%         fig = figure;
%         ax = axes('parent', fig);
%         
% 
%         % create violin plot with randomized data
%         [h_chance, l_chance] = violin(r_rand_to_group_all, 'facecolor', 'black', 'edgecolor', 'none', 'facealpha', .5, 'medc', '');
% 
%         [h_real, l_real] = violin(r_to_group_all, 'facecolor', [0, .5, 0], 'edgecolor', 'none', 'facealpha', .5, 'medc', '');
% 
%     end
    
    for n1 = 1 : length(r_to_group_all)

        % test for significant differences between synchrony value
        % and randomized synchrony distribution
        h_test_all(n1,f1) = ttest2(r_to_group_all(:,n1), squeeze(r_rand_to_group_all(:,n1)), 'tail', 'right');

    end
    
    for i1 = 1 : length(h_test_all(:,f1))
        if h_test_all(i1,f1) == 0 & flag_plot
        	h_real(i1).FaceColor = 'Red';
        end
    end
    
    if flag_plot
        set(ax, 'ylim', [-.1, .2], 'xtick', [], 'fontsize', 16);
        ylabel('Inter-subject correlation', 'fontsize', 16);
    end
    
    number_participants_above_chance(sig,number_epochs+1,f1) = sum(h_test_all(sig,:,f1));
    percentage_participants_above_chance(sig,number_epochs+1,f1) = sum(h_test_all(sig,:,f1)) / length(h_test_all(sig,:,f1));
    
    if flag_plot
        print(fig, sprintf('./figures/%s_isc_vs_chance_iscr', signals{sig}), '-dpng', '-r300')  
    end
        
end

end
            