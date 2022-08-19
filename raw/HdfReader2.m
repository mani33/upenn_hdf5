classdef (Sealed) HdfReader
    properties
        filename
        chan_name
        unit % units for each signal (e.g. uV, % etc)       
        fs % sampling rate (Hz)
        nbsamples % total number of samples per signal
        t0 % hardware counter value corresponding to the first data point of signals

    end
    methods
        function self = HdfReader(filename)
            % This is a constructor. Read basic info for later use.
            self.chan_name = h5readatt(filename, '/', 'chan_name');
            self.filename = filename;
            % Pull meta data
            self.signal_names = h5readatt(filename,'/','SignalLabels');
            self.signal_units = h5readatt(filename, '/', 'PhysicalDimensions');
            self.Fs = h5readatt(filename,'/','Fs');
            self.nbsamples_per_sig = h5readatt(filename,'/','NbsamplesPerSignal');
            sdate = h5readatt(filename,'/','StartDate');
            stime = h5readatt(filename,'/','StartTime');
            tstr = strcat(sdate, '.', stime);
            self.t0_datenum = datenum(tstr, 'dd.mm.yy.HH.MM.SS');
        end
        function d = get_signal(self, signal_name, start_index, nsamples)
            % Get signal data.
            % d = get_signal(hReader, signal_name, start_index, nsamples)
            %
            % Inputs:
            %   hReader - reader object (e.g: hReader =
            %   HdfReader('H:\EEG\test.h5'))
            %   signal_name - name of signal. e.g: 'Fz'
            %   start_index - starting position index of the signal. e.g: 1001
            %                 nsamples - number of samples needed. e.g: 10000
            % Output:
            %   d - vector of data points requested
            % Example:
            %   hReader = HdfReader('H:\EEG\test.h5')
            %   d = get_signal(hReader, 'Fz', 1001, 10000);
            %   d = hReader.get_signal('Fz',1001, 10000);
            % To get all available data:
            %   d = hReader.get_signal('Fz');

            % Get data for a given signal
            assert(any(strcmp(self.signal_names, signal_name)),...
                'Requested signal does not exits in the data file')
            group_loc = strcat('/', signal_name);
            col_num = 1; % Data is in column vector form

            % If use wants all the availble data:
            if nargin < 3
                nsamples = self.nbsamples_per_sig;
                start_index = 1;
            end
            d = h5read(self.filename, group_loc, [start_index, col_num], [nsamples,col_num]);
        end
    end
end