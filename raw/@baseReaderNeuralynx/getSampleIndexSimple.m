function idx = getSampleIndexSimple(br, t)
% idx = getSampleIndexSimple(br, t)
% Returns the sample indices 'idx' for the vector of timestamps 't'.
% Neurlynx timestamps are in microseconds. Otherwise, you need to update
% this function
%
% br - basereader
% t - time vector in seconds
%
% Mani Subramaniyan 2015-04-17, 2017-01-03
% Mani - I changed the code so that t0 is assumed to be zero. That is, the
% first sample will be given time 0. Input time 't' will be in seconds

%% Old code here:
% idx = round(1e-6 * (t - br.t0) * br.Fs) + 1;
% idx(idx < 1) = nan;
% idx(idx > br.nbSamples) = nan;
%% New code
idx = round(t * br.Fs) + 1;
idx(idx < 1) = nan;
idx(idx > br.nbSamples) = nan;