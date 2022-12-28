function [data, discard] = hr_outlier_detection(data, fs, pp, varargin)
% HR_OUTLIER_DETECTION() - Detect outliers from HR
%
% Usage:
%   >> [data, discard] = hr_outlier_detection( data, fs, pp, ...
%                   'param1', val1, 'param2', val2... )
%
% Inputs:
%   data:   Heart rate time series
%   fs:     Sampling frequency [Hz]
%   pp:     Participant number (optional)  
%
%   [...] = hr_outlier_detection(...,'param1',val1,'param2',val2,...) specifies 
%   additional parameters and their values.  Valid parameters are the 
%   following:

%	'MaxHR'     -	200 (default) maximum heart rate 
%	'MinHR'     -	30 (default) minimum heart rate 
%	'HRChange'  -	0.25 (default) maximum percentual secondly heart rate
%                   change
%
% Requirements:

% Author: Ivo Stuldreher, TNO, 11 January 2021
% 12-01-2021: add data discarding criteria

% variable input arguments
upper_threshold = 200;
lower_threshold = 30;
relative_threshold = 0.5;
for i = 1 : length(varargin)/2
    switch varargin{2*i-1}
        case 'MaxHR', upper_threshold = varargin{2*i};
        case 'MinHR', lower_threshold = varargin{2*i};
        case 'HRChange', relative_threshold = varargin{2*i};
        otherwise, error(['Unknown option ' varargin{2*i-1} ])
    end
end

if nargin < 3
    pp = [];
end

% discard heart rate if variability in the data is too low
discard = false;
data_diff = diff(data);
if (sum(data_diff == 0) / sum(data_diff ~= 0)) > 50
   discard = true;
   warning(sprintf('Discarded data %i based on variability criterion', pp));
end

if ~discard

    % correct irrealistic values
    data(data > upper_threshold | data < lower_threshold) = nan;

    % approximate for beat-to-beat abnormalities by using a maximum change in a
    % set window size
    for n = fs+1 : length(data)

        if abs((data(n) - data(n-fs)) / data(n-fs)) > relative_threshold

            data(n) = nan;

        end
    end
    
    if length(find(isnan(data)))/length(data) > 0.3
        discard = 1;
        data(1:end) = nan;
    end
    
end

end