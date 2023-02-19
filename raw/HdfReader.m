classdef (Sealed) HdfReader
    properties
        filename
        chan_name
        units % units for each signal (e.g. uV, % etc)       
        fs % sampling rate (Hz)
        nbsamples % total number of samples per signal
        t0 % hardware counter value corresponding to the first data point of signals

    end
    methods
        function self = HdfReader(filename)
            % This is a constructor. Read basic info for later use.
            fields = {'chan_name','units','fs','nbsamples','t0'};
            for iField = 1:length(fields)
                cf = fields{iField};
                self.(cf) = h5readatt(filename, '/', cf);
            end
            self.filename = filename;
        end
        function d = get_signal(self, start_index, nsamples)
            % Get signal data.
            % d = get_signal(hReader, start_index, nsamples)
            %
            % Inputs:
            %   hReader - reader object (e.g: hReader =
            %   HdfReader('H:\EEG\test.h5'))            %  
            %   start_index - starting position index of the signal. e.g: 1001
            %                 nsamples - number of samples needed. e.g: 10000
            % Output:
            %   d - vector of data points requested
            % Example:
            %   hReader = HdfReader('H:\EEG\test.h5')
            %   d = get_signal(hReader, 'Fz', 1001, 10000);
            %   d = hReader.get_signal('Fz',1001, 10000);
            % To get all available data:
            %   d = hReader.get_signal();

            % Get data 
            group_loc = strcat('/', self.chan_name);
            col_num = 1; % Data is in column vector form

            % If use wants all the availble data:
            if nargin < 3
                nsamples = self.nbsamples;
                start_index = 1;
            end
            d = h5read(self.filename, group_loc, [start_index, col_num], [nsamples,col_num]);
        end
    end
end