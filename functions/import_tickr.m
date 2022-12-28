function [data] = import_tickr( filepath )
% IMPORT_TICKR() - Import data from Wahoo Tickr
%
% Usage:
%   >> [data] = import_tickr( filepath )
%
% Inputs:
%   filepath:   Path towards to-be-imported .csv or .fit file 
%
% Requirements:
%   >> java FITCSVTOOl

% Author: Ivo Stuldreher, TNO, 9 October 2018

% 09-03-2020 update function description
% 10-03-2020 add channel information
% 16-10-2020 update function to work with .fit file
% 26-11-2020 fix bug with java path
% 30-03-2021 manually fix year to 2021
% 29-07-2021 manually add 20 years to imported date to match year

fprintf('Reading data from tickr...\n')

[~, filename, ext] = fileparts(filepath);

if strcmp(ext, '.csv')
    
    % open file header
    fid = fopen(filepath);
    hline = fgetl(fid);
    hline = strsplit(hline, ',');

    % find heart rate data
    tmp = strfind(hline, 'Heartrate');
    hr_i = find(cellfun(@(x) ~isempty(x), tmp));

    % import data
    format = ['%f%s%s%f%f%f%f%f%f%f%f%f%s'];
    d = textscan(fid, format, 'Delimiter', ',', 'HeaderLines', 1);

    % add time
    t = datetime(d{1}/1000, 'ConvertFrom', 'posixTime', 'TimeZone', 'local','Format','dd-MMM-yyyy HH:mm:ss.SSS');
    data.tstart = t(1);
    data.fs = 1 / etime(datevec(t(2)), datevec(t(1)));
    data.time = (0 : (length(d{1})-1))/data.fs';

    % save heartrate data
    data.data =  d{6};

    % add channel information
    data.chans(1).label = 'hr';

    % save metadata
    data.meta.filename = filename;
    data.meta.filepath = filepath;

    % close header
    fclose(fid);
    
elseif strcmp(ext, '.fit')
    
    % check existence of FitCSVTool.jar
    path2function = which('import_tickr');
    path2folder = fileparts(path2function);
    path2java = fullfile(path2folder, 'java/FitCSVTool.jar');
   
    tmpname = [tempname, '.csv'];
    
    % run java script to convert .fit to .csv file
    system(['java -jar "', path2java, '" -b "', filepath, '" ', tmpname]);
    
    fid = fopen(tmpname);
    
    hline = fgetl(fid);
    lnum = 1;
    cnt = 1;
    while ~isnumeric(hline)
        
        hline = strsplit(hline, ',');
        
        if any(cellfun(@(x) strcmp(x, 'Data'), hline)) & any(cellfun(@(x) strcmp(x, 'timestamp'), hline)) & any(cellfun(@(x) strcmp(x, 'heart_rate'), hline))
            
            i_ts = find(cellfun(@(x) strcmp(x, 'timestamp'), hline));
            tmp_time = datevec(datetime(str2num(hline{i_ts+1}(2:end-1)), 'ConvertFrom', 'posixTime', 'TimeZone', 'Europe/Amsterdam','Format','dd-MMM-yyyy HH:mm:ss.SSS') - days(1));
            tmp_time(1) = tmp_time(1) + 20;
            data.time(cnt) = datetime(tmp_time, 'TimeZone', 'Europe/Amsterdam','Format','dd-MMM-yyyy HH:mm:ss.SSS');
            
            i_hr = find(cellfun(@(x) strcmp(x, 'heart_rate'), hline));
            data.data(cnt) = str2num(hline{i_hr+1}(2:end-1));
            cnt = cnt + 1;
        end
        
        hline = fgetl(fid);
        lnum = lnum + 1;
        
    end
    
    data.fs = 1 / etime(datevec(data.time(2)), datevec(data.time(1)));
    
    fclose(fid);
    delete(tmpname);
end

fprintf('Succesfully loaded data\n')
