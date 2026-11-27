function [r, lags] = fftcorr(x, y)
% FFTCORR  Fast cross-correlation using FFT
%
%   [r, lags] = fftcorr(x, y) computes the full cross-correlation between
%   two input signals x and y using the FFT (Fast Fourier Transform). This
%   function is equivalent to xcorr(x, y) but significantly faster for long
%   vectors, especially when using power-of-two FFT lengths.
%
%   The output is aligned with xcorr(x, y, 'full'), producing lags from
%   -length(y)+1 to length(x)-1.
%
%   To extract only the positive-lag portion (where y is aligned to x),
%   use:
%
%       N = length(y);
%       r = r(N:end);
%       lags = lags(N:end);
%
%   This matches the behavior of:
%
%       [r, lags] = xcorr(x, y);
%       r = r(length(x):end);
%       lags = lags(length(x):end);
%
% INPUTS:
%   x    - First input vector (e.g., received signal)
%   y    - Second input vector (e.g., known template or sync sequence)
%
% OUTPUTS:
%   r    - Cross-correlation result (complex)
%   lags - Corresponding lag vector
%
% EXAMPLE:
%   x = randn(1000,1); y = randn(200,1);
%   [r, lags] = fftcorr(x, y);
%   plot(lags, abs(r));
%
% AUTHOR:
%   Wenkai Qin

Nx = length(x);
Ny = length(y);
Ncorr = Nx+Ny-1;
Nfft = 2^nextpow2(Ncorr);

X = fft(x, Nfft);
Y = fft(flipud(conj(y)), Nfft);

r = ifft(X.*Y, Nfft);
r = r(1:Ncorr);
lags = -Ny+1:Nx-1;

end