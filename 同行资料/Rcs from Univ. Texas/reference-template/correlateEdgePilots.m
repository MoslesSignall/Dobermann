function [Cy, lags, localReplica] = correlateEdgePilots(yVec, Fdoppler)
% correlateEdgePilots : Correlate IQ samples against edge pilot local replica
%                       in the time domain.
%
% The edge pilots are 16 subcarriers (8 on each side of DC) that carry a
% deterministic 4QAM pattern identical across all frames and all satellites.
% This function generates a time-domain local replica of the edge pilots and
% correlates it against the input signal.
%
% INPUTS
%
% yVec ------- Ny-by-1 complex vector of IQ samples at 240 MHz sample rate,
%              frequency-shifted to channel center.
%
% Fdoppler --- (Optional) Doppler offset in Hz to apply to local replica.
%              Default is 0.
%
% OUTPUTS
%
% Cy --------- (Ny + Nlr - 1)-by-1 complex correlation result. Peaks indicate
%              frame boundaries where edge pilots align.
%
% lags ------- Lag indices corresponding to Cy. Positive lags indicate the
%              local replica is delayed relative to yVec.
%
% localReplica (Nlr)-by-1 time-domain edge pilot local replica (300 symbols).
%
%+==============================================================================+
% Reference: Qin et al., "Pilots and Other Predictable Elements of the
%            Starlink Ku-Band Downlink", Section VI.
%+==============================================================================+

arguments
    yVec (:,1)
    Fdoppler (1,1) = 0
end

starlinkConstants;

% Generate edge pilot matrix in frequency domain
[edgePilotMatrix, ~] = genEdgePilots();

% Build time-domain local replica from edge pilots (symbols 3-302, i.e., i=2:301)
% Symbol indices 1-2 (PSS and SSS) do not have edge pilots defined.
numSymbols = 300;
localReplica = zeros((sl.N + sl.Ng) * numSymbols, 1);

for iSym = 3:302
    % Extract frequency-domain edge pilot symbols for this OFDM symbol
    freqSymbols = edgePilotMatrix(:, iSym);

    % IFFT to time domain with proper scaling
    timeDomain = sqrt(sl.N) * ifft(freqSymbols);

    % Add cyclic prefix
    withCP = [timeDomain(end-sl.Ng+1:end); timeDomain];

    % Place in local replica vector
    idx = (iSym - 3) * (sl.N + sl.Ng) + (1:(sl.N + sl.Ng));
    localReplica(idx) = withCP;
end

Nlr = length(localReplica);

% Apply Doppler shift to local replica if specified
if Fdoppler ~= 0
    tReplica = (0:Nlr-1)' / sl.Fs;
    localReplica = localReplica .* exp(1j * 2 * pi * Fdoppler * tReplica);
end

% Perform FFT-based cross-correlation
[Cy, lags] = fftcorr(yVec, localReplica);

end
