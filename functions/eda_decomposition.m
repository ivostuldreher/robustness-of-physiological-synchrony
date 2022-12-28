function [output] = eda_decomposition(eda, time, event, varargin )
% EDA_DECOMPOSITION() - Decompose electrodermal activity into phasic and
%                       tonic components.
%
% Usage:
%   >> [output] = eda_decomposition( eda, time, event )
%
% Inputs:
%   eda:    Raw electrodermal activity input signal
%   time:   Corresponding timearray. Format can be, among others, Double, 
%           Datetime, Duration
%
%   [...] = eda_decomposition(...,'param1',val1,'param2',val2 ...) specifies 
%   additional parameters and their values.  Valid parameters are the 
%   following:
%
%        Parameter         Value
%        'decomposition'    'CDA' (default) | 'DDA', continuous
%                           decomposition analysis or discrete
%                           decomposition analysis
%        'era'              0 (default) | 1, export event related
%                           activition
%
% Outputs:
%   scr     - Skin conductance response (phasic components of the eda)
%   scl     - Skin conductance level (tonic components of eda)
%
% Requirements:
%   Ledalab (http://www.ledalab.de/)
%   Symbolic Toolbox

% Author: Ivo Stuldreher, TNO, 29 October 2019

% 29-10-19 use temporary .mat file for ledalab
% 31-10-19 update function description
% 06-03-20 fix struct pre-creation bug

if nargin < 3
    event = [];
end

% variable input arguments
decomposition = 'CDA'; era = 0; duration = 1;
for ii = 1 : length(varargin)/2
    switch varargin{2*ii-1}
        case 'decomposition', decomposition = varargin{2*ii};
        case 'era', era = varargin{2*ii};
        case 'duration', duration = varargin{2*ii};
        otherwise, error(['Unknown option ' varargin{2*ii-1} ])
    end
end

if isempty(which('Ledalab.m'))
    msgid = 'ledalab:toolboxNotFound';
    errmsg = 'Ledalab toolbox not found. Download on: http://www.ledalab.de/';
    error(msgid, errmsg);
end

% symb_available = license('checkout', 'Symbolic_Toolbox');
% if ~symb_available    
%     msgid = 'symbolic:licenseNotAvailable';
%     errmsg = 'Symbolic_Toolbox license not availble.';
%     error(msgid, errmsg);
% end

% initialize ledalab data structure
data = struct(...
    'time', {}, ...
    'conductance', {}, ...
    'timeoff', {}, ...
    'event', {});

% convert data to ledalab structure
data(1).conductance = eda;
data.time = time;
data.timeoff = 0;

% initialize ledalab event structure
data.event = struct('time', {}, ...
    'nid', {}, ...
    'name', {}, ...
    'userdata', {});

% import event information if provided
if isempty(event)
    fprintf('No events provided. Running Ledalab without event information.\n')
    data.event(1).time = 0;
    data.event.nid = 1;
    data.event.name = '';
    data.event.timeoff = 0;
else
    data.event = event;
end
    
% save temporary matlab struct for Ledalab processing
name = [tempname '.mat'];
save(name, 'data');
scriptpath = pwd;

% process data using Ledalab
Ledalab(name, 'open', 'mat', ...
    'analyze', decomposition, ...
    'overview', 0);
cd(scriptpath)

% load .mat file
load(name, 'analysis');

% save phasic data in variable phasic
output.time = data.time;
output.eda = data.conductance;
output.scr = analysis.phasicData;
output.scl = analysis.tonicData;

if era  
    output.event = eda_ledalab_variable_era(data, analysis, duration);
end

% % load optional event related activity
% [~, name_no_ext] = fileparts(name);
% if era
%     load([name_no_ext, '_era'], 'results');
%     output.results = results;
% end

end