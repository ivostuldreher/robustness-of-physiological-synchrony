function [p, tbl, stats] = statitical_testing(data, r_to_group, epoch_order_overview, epoch_condition_overview, independent_variables, signals)

number_participants = max(cellfun(@(x) length(x), r_to_group));
participant_idc = find(cellfun(@(x) ~isempty(x), {data.marker}));
number_epochs = max(cellfun(@(x) length(x), {data(:).epoch}));

for sig = 1 : length(signals)
   
    for e1 = 1 : number_epochs
        
        epoch_idc = epoch_order_overview == e1;
        epoch_condition = epoch_condition_overview(epoch_idc);
        
        X{sig}((e1-1)*number_participants+1 : e1*number_participants, 1) = e1;
        X{sig}((e1-1)*number_participants+1 : e1*number_participants, 2) = epoch_condition;
%         X{sig}((e1-1)*number_participants+1 : e1*number_participants, 3) = 1 : number_participants;
        
    end
    
    r_to_group_column{sig} = reshape(r_to_group{sig}, [], 1);
    
    [p{sig}, tbl{sig}, stats{sig}] = anovan(r_to_group_column{sig}, X{sig}, 'varnames', independent_variables, 'model', 'interaction');
    
end

end