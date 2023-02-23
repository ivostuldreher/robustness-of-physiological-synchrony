function [r, r_in_time] = epoch_synchrony(data, signals, varargin)

% 17-05-2021: add option for compution of synchrony in multiple frequency
%             bands
% 23-12-2021: add option to obtain inter-subject correaltions in time

% variable input arguments
synchrony_function = 'ps_mwa';
max_time = [];
for ii = 1 : length(varargin)/2
    switch varargin{2*ii-1}
        case 'synchrony_function', synchrony_function = varargin{2*ii}; 
        case 'maxTime', max_time = varargin{2*ii};
        otherwise, error(['Unknown option ' varargin{2*ii-1} ])
    end
end

if nargout > 1
    flag_time_resolved = true;
end

if ~isempty(max_time)
    
    function_to_eval = sprintf('%s(data(n1).epoch(e1).(signals{sig}), data(n2).epoch(e1).(signals{sig}), ''maxTime'', %i)', synchrony_function, max_time);
    
else

    function_to_eval = sprintf('%s(data(n1).epoch(e1).(signals{sig}), data(n2).epoch(e1).(signals{sig}))', synchrony_function);
    
end

if strcmp(synchrony_function, 'wavelet_ps')
    number_freq = 3;
else
    number_freq = 1;
end

number_participants = length(data);
number_epochs = max(cellfun(@(x) length(x), {data(:).epoch}));


for sig = 1 : length(signals)
    
    r{sig} = nan(number_participants, number_participants, number_epochs, number_freq);
    
%     if flag_time_resolved
%         r_in_time{sig} = {nan(number_participants, number_participants, number_freq)};
%     end
        
    
    % initialize progress bar
    textprogressbar(sprintf('Computing synchrony for %s: \n', signals{sig}));
   
    for n1 = 1 : number_participants
        
        % update progress bar
        textprogressbar(n1/number_participants*100)
        
        % check if data is empty, if so, skip
        if isempty(data(n1).marker) | isempty(data(n1).(signals{sig})) 
            continue
        end
        
        for n2 = n1 : number_participants
            
            % check if data is empty, if so, skip
            if isempty(data(n2).marker) | isempty(data(n2).(signals{sig}))
                continue
            end
            
            if isempty(data(n1).epoch) | isempty(data(n2).epoch)
                continue
            end
       
            for e1 = 1 : min(min(number_epochs, length(data(n1).epoch)), length(data(n2).epoch))
                
%                 fprintf('%i_%i_%i\n', n1, n2, e1);
                
                if isempty(data(n1).epoch(e1).(signals{sig}).data) | isempty(data(n2).epoch(e1).(signals{sig}).data)
                    continue
                end
               
                    % compute synchrony r between participant n1 in epoch
                    % e1 and participant n2 in epoch e2
                    [~, r{sig}(n1,n2,e1,:)] = eval(function_to_eval);
                    
                    if flag_time_resolved
                        [r_in_time{sig}(n1,n2,e1,:), r{sig}(n1,n2,e1,:)] = eval(function_to_eval);
                    end

            end
        end
    end
    
    for e1 = 1 : number_epochs
        
        for f1 = 1 : number_freq
        
            % mirror the computed synchrony over the diagonal to complete the
            % matrix       
            tmp_r = triu(r{sig}(:,:,e1,f1))' + triu(r{sig}(:,:,e1,f1));
            tmp_r(1:length(data)+1:end) = diag(r{sig}(:,:,e1,f1));
            r{sig}(:,:,e1,f1) = tmp_r;
        end

    end
    
    textprogressbar(sprintf('Finishined synchrony for %s: \n', signals{sig}));
    
end

end