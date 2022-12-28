function r_rand_to_group = rand_epoch_synchrony_to_group(data, r_rand, signals, epoch_order_overview, epoch_condition_overview)

number_participants = max(cellfun(@(x) size(x,1), r_rand));
participant_idc = find(cellfun(@(x) ~isempty(x), {data.marker}));
number_epochs = max(cellfun(@(x) size(x,4), r_rand));

for sig = 1 : length(signals)
    
    number_rand =  size(r_rand{sig}, 3);
        
    not_isempty = cellfun( @(x) ~isempty(x), {data(participant_idc).(signals{sig})});
    participant_idc_to_use = participant_idc(not_isempty);
    
%     not_discard = cellfun(@(x) ~x.discard, {data(participant_idc_to_use).(signals{sig})});
%     participant_idc_to_use = participant_idc_to_use(not_discard);
    
    r_rand_to_group{sig} = nan(number_participants, number_rand, number_epochs);
   
    for n1 = 1 : number_participants
       
        % skip participants with empty data
        if isempty(data(n1).marker)
            continue
        end
        
        for e1 = 1 : number_epochs
            
            % find in which order the epochs were played and then find the
            % condition all participants in  epoch e1
            epoch_idc = epoch_order_overview == e1;
            epoch_condition = epoch_condition_overview(epoch_idc);
            
            for r1 = 1 : number_rand     

                r_rand_to_group{sig}(n1,r1,e1) = nanmean(r_rand{sig}(n1, participant_idc_to_use, r1, e1));

            end
        end  
    end
end