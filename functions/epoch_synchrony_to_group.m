function [r_to_group, r_to_group_in_time] = epoch_synchrony_to_group(data, r, signals, r_in_time)

% 23-12-2012: add optional input argument r_in_time
flag_time_resolved = false;
if nargin > 3 && nargout > 1
    flag_time_resolved = true;
end

number_participants = max(cellfun(@(x) length(x), r));
participant_idc = find(cellfun(@(x) ~isempty(x), {data.marker}));
number_epochs = max(cellfun(@(x) length(x), {data(:).epoch}));
number_freq = max(cellfun(@(x) size(x, 4), r));

for sig = 1 : length(signals)
    
    not_isempty = cellfun( @(x) ~isempty(x), {data(participant_idc).(signals{sig})});
    participant_idc_to_use = participant_idc(not_isempty);
    
%     not_discard = cellfun(@(x) ~x.discard, {data(participant_idc_to_use).(signals{sig})});
%     participant_idc_to_use = participant_idc_to_use(not_discard);
    
    r_to_group{sig} = nan(number_participants,number_epochs, number_freq);
   
    for n1 = participant_idc_to_use
        
        for e1 = 1 : number_epochs
            
            
                
                for f1 = 1 : number_freq
           
                    r_to_group{sig}(n1,e1,f1) = nanmean(r{sig}(n1, setdiff(participant_idc_to_use, n1), e1, f1));
                    
                    if flag_time_resolved
                        tmp_cell = {r_in_time{sig}(n1, setdiff(participant_idc_to_use, n1), e1, f1).data};
                        number_samples = cellfun(@(x) length(x), tmp_cell);
                        min_length = min(number_samples(number_samples > 0 & number_samples > 550));

                        try
                            r_to_group_in_time{sig,e1}(:,n1) = nanmean(cell2mat(cellfun(@(x) x(1:min_length), tmp_cell(number_samples > 0 & number_samples > 550), 'UniformOutput', false)), 2);
                        catch
                            fprintf('Skipped participants %i epoch %i\n', n1, e1)
                        end
                    end
                end
                
            
            
        end
        
    end
    
end

end