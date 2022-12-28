function [data] = import_bin(filepath)
% IMPORT_BIN() - Import .bin datafile to Matlab. Save data and time as well
%                as meta information about the file, all in a struct 'data'
%
% Usage:
%   >> [data] = import_bin( filepath )
%
% Inputs:
%   filepath:   Path towards to-be-imported .bin file located in a folder
%                 with a 'unisens.xml' file
%
% Requirements:
%   >> Unisens toolbox. Download available on:
%      http://www.unisens.org/downloads.php

% Author: Ivo Stuldreher, TNO, 13 November 2018

% 30-10-2019 update function description
% 26-11-2019 bug fixes; create correct unisens object and save time vector
%            in the correct format
% 10-03-2020 add channel information
% 08-04-2021 add absolute timestamp in datetime format
% 20-12-2021 add automatic install of unisens toolbox

% check existance of unisens toobox
try
    u_version = eval('unisens_version');
catch
    msgid = 'unisens:toolboxNotFound';
    errmsg = 'Unisens toolbox not found. Downloading from Github. Do you want to continue? (Y/n)';
    warning(msgid, errmsg);
    
    a = input('Do you want to continue? (y/n)\n', 's');
    disp(' ');

    if (~strcmpi(a, 'y'))
        disp('Installation aborted');
        disp(' ');
        return;
    end
    
    % download unisens toolbox from github
    str = 'https://raw.githubusercontent.com/Unisens/unisens4matlab/master/install_unisens_toolbox.m';
    content = urlread(str);
    filename = sprintf('%s%s.m', fileparts(tempname), '/unisens_install');

    % put content in a .m file and run file
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', content)
    
    folder = fileparts(filename);
    addpath(folder)
    unisens_install()

end

% check if file exists
if ~(exist(filepath, 'file') == 2)
    msgid = 'myData:noData';
    errmsg = 'Specified filepath does not point to a file';
    error(msgid, errmsg);
end

[dirpath, filename, fileext] = fileparts(filepath);

% create unisens objects and read data
fprintf('Reading .bin data...\n')
jUnisensFactory = org.unisens.UnisensFactoryBuilder.createFactory(); 
jUnisens = jUnisensFactory.createUnisens(dirpath);
dataEntry = jUnisens.getEntry([filename fileext]);
data.data = dataEntry.readScaled(dataEntry.getCount());

% save data into data structure
data.fs = dataEntry.getSampleRate();

% add time information
startTime = unisens_get_timestampstart(dirpath);  % recording start time [y, m, d, h, m, s]
data.tstart = datetime(startTime, 'TimeZone', 'Local');
data.time = data.tstart + seconds((0 : (length(data.data)-1))/data.fs');

% add channel inforamtion
data.chans(1).label = filename;

% save metadata
data.meta.filename = filename;
data.meta.filepath = filepath;

% store alphabetically
data = orderfields(data);

fprintf('Succesfully imported .bin file.\n')

end