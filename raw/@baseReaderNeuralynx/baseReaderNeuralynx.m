function br = baseReaderNeuralynx(varargin)
% Base reader for electrophysiology recordings
%   br = baseReaderElectrophysiology(fileName) opens a base reader for the
%   file given in fileName.
%
%   br = baseReaderElectrophysiology(fileName, channels) opens a reader for
%   only the given channels, where channels is either a numerical vector of
%   channel indices, a string containing a channel name or a cell array of
%   stings containig multiple channel names.
%
%   br = baseReaderElectrophysiology(fileName, pattern) opens a reader for
%   a group of channels matching the given pattern. Channel groups can be
%   for instance tetrodes. In this case the pattern would be 't10c*'.
%
% Example
% br = baseReaderNeuralynx('y:\ephys\2014-09-09_11-10-12\tt*.ncs) - This
% will read all ncs files starting with tt.
% br = baseReaderNeuralynx('y:\ephys\2014-09-09_11-10-12\tt_1_2.ncs) - This
% will read only the channel named tt_1_2.
% br = baseReaderNeuralynx('y:\ephys\2014-09-09_11-10-12\tt_1_*.ncs) - This
% will read all 4 channels of tetrode 1.
% 
% To open processed field potential files which are in hdf5 format, use the
% following sytle: 
% To read a file named fp0_0, 
% br = baseReaderNeuralynx('fp0_%d').
% MS 2014-09-09
fileName = varargin{1};
[~,~,ext] = fileparts(fileName);
if strcmp(ext,'.ncs')
    br = getNCSreader(varargin{:});
else
    br = getHdf5Reader(varargin{:});
end

function br = getNCSreader(fileName,channels)
br.fileName = fileName;

basePath = fileparts(fileName);
% Get all file names specified by the input fileName
d = dir(fileName);
allFileNames = arrayfun(@(x) fullfile(basePath,x.name),d,'uni',false);


br.fp = []; % file pointer
theFile = allFileNames{1};
for iF = 1:length(allFileNames)
    oneFile = allFileNames{iF};
    [br.t0,br.Fs,~] = Nlx2MatCSC(oneFile,[1 0 1 0 0],1,3,1);
    if ~isempty(br.t0) && br.t0~=0 % Hack@#$#$%^!@!!!!!!
        theFile = oneFile;
    end
end
[br.t0,br.Fs,header] = Nlx2MatCSC(theFile,[1 0 1 0 0],1,3,1);
% Read just one channel and find total samples
br.nbSamples = getNsamples(theFile,br);

% % Find true channel indices. These are physical AD channel indices assigned by
% % Neuralynx hardware.
% br.chIndices = getChannelIndices(fileNames);
allADchanIndices = getChannelIndices(allFileNames);

allChanNames = getChanNames(allFileNames);
selFileNames = cell(1,1);
if nargin < 2
    br.chIndices = allADchanIndices;
    selFileNames = allFileNames;
    br.chNames = allChanNames;
else
    
    % If channels are numbers, then those numbers must be the AD Channel
    % numbers assigned by Neuralynx hardware
    if isnumeric(channels)
        % Find all available AD Channels
        br.chIndices = channels;
        [~,fileIndices] = intersect(allADchanIndices,channels);
        selFileNames = allFileNames(fileIndices);
        br.chNames = allChanNames(fileIndices);
    else % pattern such as t10c1 or t10c* or t*c*
        % one channel string or cell array of strings?
        if ischar(channels)
            channels = {channels};
        end
        nChanGrp = length(channels);
        for i = 1:nChanGrp
            ch = strrep(channels{i},'*','\d+'); % to make it easy for regexp
            % Find which file name(s) have these channels           
            fileInd = cellfun(@(x) ~isempty(regexp(x,ch,'start')),allFileNames);
            selFileNames{i} = allFileNames(fileInd);
            br.chIndices{i} = allADchanIndices(fileInd);
            br.chNames{i} = allChanNames(fileInd);
        end
        br.chIndices = [br.chIndices{:}];
        br.chNames = [br.chNames{:}];
        selFileNames = [selFileNames{:}];
    end
end
br.fileList = selFileNames;
% Find number of channels
br.nbChannels = length(br.chNames);



scaleInd = cellfun(@(x) ~isempty(strfind(x,'ADBitVolts')), header);
invInd = cellfun(@(x) ~isempty(strfind(x,'InputInverted')), header);
invInfo = header{invInd};
hh = header{scaleInd};
sc = regexp(hh,'ADBitVolts.+(\d+\.\d+)','tokens');
br.scale = str2double(sc{:});
br.input_inverted = false;
if ~isempty(strfind(invInfo,'True')) || ~isempty(strfind(invInfo,'true')) || ~isempty(strfind(invInfo,'TRUE'))
    br.input_inverted = true;
end
br.recordSize = size(Nlx2MatCSC(oneFile,[0 0 0 0 1],0,3,1),1);
br = orderfields(br);
br = class(br, 'baseReaderNeuralynx');

function nSamples = getNsamples(fileName,br)
% You must verify that this function returns the correct number of total
% samples by reading a whole file using Nlx2MatCSC function. Here, we will
% use some hard coded information such as headersize to determine total
% samples.
header = Nlx2MatCSC(fileName,[0 0 0 0 0],1,3,1);
hInd = cellfun(@(x) ~isempty(regexp(x,'-RecordSize\s\d+','match')),header);
hh = header{hInd};
rs = regexp(hh,'-RecordSize\s(\d+)','tokens');
recordsize = str2double(rs{:});
% the file starts with a 16*1024 bytes header in ascii, followed by a number of records
fid = fopen(fileName, 'rb', 'ieee-le');

% determine the length of the file
fseek(fid, 0, 'eof'); % move pointer to the end of file
headersize = 16384; % DANGER! - you got to make sure that Neuralynx doesn't change these numbers when they
% change their acquisition software.
NRecords   = floor((ftell(fid) - headersize)/recordsize);
% Note that there can be more Records than one needs for the true number of
% samples in the recording. So we will use the total number of records
% first to get the timestamps and then accurately calculate the number of
% samples from the timestamps.

[ts,nvs] = Nlx2MatCSC(fileName,[1 0 0 1 0],0,3,[1 NRecords]);
tEnd = ts(end)+((nvs(end))*1e6*1/br.Fs);
nSamples = round(((tEnd-ts(1))*1e-6)*br.Fs);
fclose(fid);


function chNames = getChanNames(fileNames)
nFiles = length(fileNames);
chNames = cell(1,nFiles);
for i = 1:nFiles
    [~,chNames{i}] = fileparts(fileNames{i});
end

function chIndices = getChannelIndices(fileNames)

% Get entire header info first
nFiles = length(fileNames);
chIndices = nan(1,nFiles);
for i = 1:nFiles
    fn = fileNames{i};
    h = Nlx2MatCSC(fn,[0 0 0 0 0],1,3,1);
    adInd = cellfun(@(x) ~isempty(regexp(x,'-ADChannel\s','start')), h);
    hh = h{adInd};
    ci = regexp(hh,'-ADChannel\s+(\d+)','tokens');
    ci = ci{:};
    chIndices(i) = str2double(ci);
end

%--------------------------------------------------------------------------
function br = getHdf5Reader(fileName,channels)
% Base reader for electrophysiology recordings
%   br = baseReaderNeuralynx(fileName) opens a base reader for the
%   file given in fileName.
%
%   br = baseReaderNeuralynx(fileName, channels) opens a reader for
%   only the given channels, where channels is either a numerical vector of
%   channel indices, a string containing a channel name or a cell array of
%   stings containig multiple channel names.
%
%   br = baseReaderNeuralynx(fileName, pattern) opens a reader for
%   a group of channels matching the given pattern. Channel groups can be
%   for instance tetrodes. In this case the pattern would be 't10c*'.
%
% AE 2011-04-11
% MS 2015-04-10 - This is just a copy-pasted version of
% baseReaderElectrophysiology

br.fileName = fileName;
br.fp = H5Tools.openFamily(fileName);
% br.fp = H5F.open(fileName, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
sz = H5Tools.getDatasetDim(br.fp, 'data');
br.nbChannels = sz(1);
br.nbSamples = sz(2);
if nargin < 2
    channels = 1:br.nbChannels;
end
if isnumeric(channels)
    br.chIndices = channels;
    br.chNames = H5Tools.getChannelNames(br.fp, channels);
else
    [br.chIndices, br.chNames] = H5Tools.matchChannels(br.fp, channels);
end

br.nbChannels = length(br.chIndices);

br.Fs = H5Tools.readAttribute(br.fp, 'Fs');
if(H5Tools.existAttribute(br.fp, 't0'))
    br.t0 = H5Tools.readAttribute(br.fp, 't0');
else
    br.t0 = 0;
end
br.scale = H5Tools.readAttribute(br.fp, 'scale');
% Make sure that the two type of baseReaders created by the function calls
% getNCSReader and getHDF5Reader have the same fields. Otherwise, matlab
% will complain. Here we add these fields to stop that complain.
br.recordSize = [];
br.fileList = {br.fileName};
br.input_inverted = []; % does not apply.
br = orderfields(br);
br = class(br, 'baseReaderNeuralynx');