function [r, r_overall] = ps_mwa( data1, data2, varargin )
% PS_MWA() - Compute physiological synchrony (PS) using a moving window
%            approach from (Marci et al., 2007). Compute Pearson
%            correlations between two datasets in a moving window.
% Usage:
%   >> [rho] = mwa(data1, data2)
%
% Inputs:
%   data1:  Structure of data channel 1. Should contain fields
%           'fs' (scalar) and 'data' (array).
%   data2:  Similar to data1, containing data channel 2
%
%   [...] = mwa(...,'param1',val1,'param2',val2,...) specifies 
%   additional parameters and their values.  Valid parameters are the 
%   following:
%
%        Parameter         Value
%         'BartlettWindow'  1.5 (default) Bartlett running window size [s]
%         'CorWindow'   	15 (default) Pearson correlation running window
%                           size [s].
%         'CorStep'         1 (default) Pearson correlation running window
%                           step increment [s].
%         'SlopeWindow'     5 (default) moving slope running window size
%                           [s].
%         'SlopeStep'       1 (default) moving slope running window step
%                           increment [s].
%         'filtFlag'        false (default) / true filter data using 
%                           bartlett window
%         'slopeFlag'       false (default) / true differentiate data 
%                           before correlation calculation
%         'logCorrect'      false (defaults) / true Correct overall 
%                           synchrony using log
%         'maxTime'         use only up to maxTime seconds of data for
%         synchrony computation
%
%   Author: Ivo Stuldreher, TNO, 15 April 2019
%
%   03-07-2019 add flags for filtering and derivation, set standard to not
%       filter and not differentiate data
%   02-07-2020 fix such that input data can be row and column array
%   08-01-2021 add statement for automatic log correction
%   12-01-2021 replace field name samplerate by fs
%   03-06-2022 also accept two matrices as data input
%
% References:
%   Marci, C. D., Ham, J., Moran, E., & Orr, S. P. (2007). Physiologic 
%   correlates of perceived therapist empathy and social-emotional process 
%   during psychotherapy. The Journal of nervous and mental disease, 
%   195(2), 103-111.

% specify name value input arguments
p = inputParser;

defaultValue = 1.5;
errorMsg = 'Value must be positive, scalar and numeric.'; 
validationFcn = @(x) assert(isnumeric(x) && isscalar(x) ...
    && (x > 0), errorMsg);
addParameter(p, 'BartlettWindow', defaultValue, validationFcn);

defaultValue = 15;
errorMsg = 'Value must be positive, scalar and numeric.'; 
validationFcn = @(x) assert(isnumeric(x) && isscalar(x) ...
    && (x > 0), errorMsg);
addParameter(p, 'CorWindow', defaultValue, validationFcn);

defaultValue = 1;
errorMsg = 'Value must be positive, scalar and numeric.'; 
validationFcn = @(x) assert(isnumeric(x) && isscalar(x) ...
    && (x > 0), errorMsg);
addParameter(p, 'CorStep', defaultValue, validationFcn);

defaultValue = 5;
errorMsg = 'Value must be positive, scalar and numeric.'; 
validationFcn = @(x) assert(isnumeric(x) && isscalar(x) ...
    && (x > 0), errorMsg);
addParameter(p, 'SlopeWindow', defaultValue, validationFcn);

defaultValue = Inf;
errorMsg = 'Value must be positive and numeric.'; 
% validationFcn = @(x) assert(isnumeric(x) && (x > 0), errorMsg);
addParameter(p, 'maxTime', defaultValue);

defaultValue = 1;
errorMsg = 'Value must be positive, scalar and numeric.'; 
validationFcn = @(x) assert(isnumeric(x) && isscalar(x) ...
    && (x > 0), errorMsg);
addParameter(p, 'SlopeStep', defaultValue, validationFcn);

defaultValue = false;
errorMsg = 'Value must be logical.'; 
validationFcn = @(x) assert(islogical(x), errorMsg);
addParameter(p, 'filtFlag', defaultValue, validationFcn);

defaultValue = false;
errorMsg = 'Value must be logical.'; 
validationFcn = @(x) assert(islogical(x), errorMsg);
addParameter(p, 'slopeFlag', defaultValue, validationFcn);

defaultValue = false;
errorMsg = 'Value must be logical.'; 
validationFcn = @(x) assert(islogical(x), errorMsg);
addParameter(p, 'logCorrect', defaultValue, validationFcn);

parse(p, varargin{:});

% check fs from both inputs
if ~(data1.fs - data2.fs == 0)
    warning('Dissimilar fss, downsampling to %i \n', min(data1.fs, data2.fs))
    if data1.fs > data2.fs
        [data1.data] = downsample(data1.data, data2.fs, data1.fs);
    else
        [data2.data] = downsample(data2.data, data1.fs, data2.fs);
    end
end

if length(data1.data) ~= length(data2.data)
%     warning('Dissimilar data length, length(data1) = %i, length(data2) = %i \n', length(data1.data), length(data2.data));
    
    cutoff_idx = min(length(data1.data), length(data2.data))+1;
    
    data1.data(cutoff_idx:end) = [];
    data2.data(cutoff_idx:end) = [];
end    

input = data1;
if diff(size(data1.data)) > 0
    input.data = [data1.data(1:min(length(data1.data),p.Results.maxTime*data1.fs))', data2.data(1:min(length(data2.data),p.Results.maxTime*data2.fs))'];
else
    if diff(size(data2.data)) > 0
        data2.data = data2.data';
    end
    input.data = [data1.data(1:min(length(data1.data),p.Results.maxTime*data1.fs)), data2.data(1:min(length(data2.data),p.Results.maxTime*data2.fs))];
end

% smoothen input data using a Bartlett window filter of length wt with step
% size st
if p.Results.filtFlag
    wl = p.Results.BartlettWindow * input.fs; % window length [num. samples]
    window = bartlett(wl);
    input.data = filter(window, 1, input.data);
end

% moving window slope calculation
if p.Results.slopeFlag
    input = movingslope(input, p.Results.SlopeWindow, p.Results.SlopeStep);
end

% moving window correlation calculation
r = movingcorrelation(input, p.Results.CorWindow, p.Results.CorStep);
if p.Results.logCorrect
    r_overall = log(sum(r.data(r.data > 0)) / sum(abs(r.data(r.data < 0))));
else
    r_overall = nanmean(r.data(ceil(p.Results.CorWindow / 2) : end - ceil(p.Results.CorWindow / 2)));
end

end

% ---------------------------------------------------------------------- %

function [slope] = movingslope(input, wt, st)

ws = wt * input.fs;
ss = st * input.fs;

% build filter coefficient to estimate the slope
p = mod(ws, 2);
s = (ws - p) / 2;
t = ((-s+1-p):s)';
slope.fs = st;

% calculate moving window slope with window size 'ws' and step increment of
% 'ss' by taking the mean of the gradient within 'ws'
slope.data = zeros(ceil(length(input.data)/ss), size(input.data,2));
slope.time = linspace(0, ceil(input.time(end)), length(slope.data))';
for i = 1 : size(input.data,2)
    for j = s+1 : ss : length(input.data) - s
        slope.data(ceil(j/ss), i) = mean(gradient(input.data(j-s:j+s, i)));
    end
end

end

% ---------------------------------------------------------------------- %

function [rho] = movingcorrelation(input, wt, st)

% convert seconds to samples
ws = wt * input.fs;
ss = st * input.fs;

% build filter coefficient to estimate the slope
p = mod(ws, 2);
s = (ws - p) / 2;
t = ((-s+1-p):s)';
rho.fs = st;

% calculate moving window correlation with window size 'ws' and step increment of
% 'ss' by taking the mean of the gradient within 'ws'
rho.data = zeros(ceil(length(input.data)/ss), 1);
% rho.time = linspace(0, ceil(input.time(end)), length(rho.data))';
for j = s+1 : ss : length(input.data) - s
    rho.data(ceil(j/ss)) = corr(input.data(j-s:j+s,1), input.data(j-s:j+s,2));
end

end
