function r_rand = circular_shuffled_synchrony(data, signals, number_rand)

number_participants = length(data);
number_epochs = max(cellfun(@(x) length(x), {data(:).epoch}));

% pre-assign variables for faster processing
rand_data = data;

for sig = 1 : length(signals)
    
    % pre-assign variables for faster processing
    r_rand{sig} = nan(number_participants, number_participants, number_rand, number_epochs);
    
    % initialize progress bar
    textprogressbar(sprintf('Computing random synchrony for %s: \n', signals{sig}));
    
    for r1 = 1 : number_rand
        
        % update progress bar
        textprogressbar(r1/number_rand*100)
    
        for e1 = 1 : number_epochs

            for n1 = 1 : number_participants
                
                % check if data is empty, if so, skip
                if isempty(data(n1).marker) | ~isfield(data(n1).epoch(1), signals{sig}) | isempty(data(n1).epoch(e1).(signals{sig}).data)
                    continue
                end

                % circular shuffle data of participant n1
                shuffle_posisition = randi(length(data(n1).epoch(e1).(signals{sig}).data));
                rand_data(n1).epoch(e1).(signals{sig}).data = circshift(data(n1).epoch(e1).(signals{sig}).data, shuffle_posisition);

                for n2 = n1 : number_participants
                    
                    % check if data is empty, if so, skip
                        if isempty(data(n2).marker) | ~isfield(data(n2).epoch(1), signals{sig}) | isempty(data(n2).epoch(e1).(signals{sig}).data)
                            continue
                        end

                    % compute synchrony between randomly shuffled data of
                    % participant n1 and normal data of participant n2
                    [~, r_rand{sig}(n1,n2,r1,e1)] = ps_mwa(rand_data(n1).epoch(e1).(signals{sig}), data(n2).epoch(e1).(signals{sig}));

                end
            end

            % mirror the computed synchrony over the diagonal to complete the
            % matrix       
            tmp_r = triu(r_rand{sig}(:,:,r1,e1))' + triu(r_rand{sig}(:,:,r1,e1));
            tmp_r(1:length(data)+1:end) = diag(r_rand{sig}(:,:,r1,e1));
            r_rand{sig}(:,:,r1,e1) = tmp_r;

        end
        
    end
    
    textprogressbar(sprintf('Finishined random synchrony for %s: \n', signals{sig}));
    
end

end