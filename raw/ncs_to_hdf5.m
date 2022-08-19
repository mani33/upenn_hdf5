function ncs_to_hdf5(ncs_filename, outfile_name)
% Convert neuralynx ncs data file format to hdf5 (h5) format. By default, 
% % data will be compressed.
% 
% ncs_to_hdf5(ncs_filename, outfile_name)
%
% EXAMPLE:
%        ncs_to_hdf5('R:\projects\t1c1.ncs','N:\projects\temp\t1c1.h5')
%
% Copyright: Mani Subramaniyan
% First created: 2022-08-18
% 
tic
[~, ~, ext] = fileparts(outfile_name);
assert(strcmp(ext, '.h5'), 'You must provide outfile name with .h5 as extension')

compression_level = 5; % 0 = no compression
ncol = 1;
chunk_size = [10000, ncol]; % nRows-by-nCol data chunk size for storage
write_start_pos = [1, 1]; % we write from the beginning location (row=1, col=1) of the data array
loc = '/';

br = baseReaderNeuralynx(ncs_filename);
% Get all samples
disp('Reading all available data from disk ...')
n = getNbSamples(br);
sig_data = br(1:n,1); % This will read data with units Volts.
disp('Done')

% Get important attributes
t0 = getT0(br);
fs = getSamplingRate(br);
chan = getChannelNames(br);
sig_name = chan{:};
siz = [n,1]; % size argument of h5create function
h5group_name = [loc sig_name];
h5create(outfile_name, h5group_name, siz, "Chunksize", chunk_size, 'Deflate',compression_level);
disp('Writing output file ...')
h5write(outfile_name, h5group_name, sig_data, write_start_pos, [n, ncol])
fprintf('Done with signal:(%0.0f data points) %s\n', n, sig_name)

% Write attributes at the root level in the h5 hierarchy
disp('Writing attributes ...')
h5writeatt(outfile_name, loc, 'chan_name', chan)
h5writeatt(outfile_name, loc, 'fs', fs)
h5writeatt(outfile_name, loc, 'nbsamples', n)
h5writeatt(outfile_name, loc, 't0', t0)
h5writeatt(outfile_name, loc, 'units', 'Volts')
fprintf('Done (took %0.0f s)\n',toc)