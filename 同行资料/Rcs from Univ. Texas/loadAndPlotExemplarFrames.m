% loadAndPlotExemplarFrames.m
%
% Quick visualization of the Exemplar Frames dataset (1009 decoded frames
% from STARLINK-31848, v2.0-mini, captured Jan. 21, 2025).
%
% This script loads the decoded frames and generates diagnostic plots:
%   Fig 1   Modulation map across all frames
%   Fig 2   Frame structure diagram (PSS, SSS, T-code, edge pilots)
%   Fig 3   Signal quality (SINR) distribution and Doppler shift over time
%   Fig 4   Decoded symbol constellation (soft and hard decisions)
%   Fig 5   Reference template comparison (decoded QPSK, template, deviation)
%   Fig 6   T-code extraction and diversity analysis
%
% T-Code Extraction:
%   - Extracts 60-bit T-codes from each frame using deviation from template
%   - Validates via 60-subcarrier periodicity (autocorrelation check)
%   - Ensures BPSK constraint: deviations must be in {0, 2} mod 4
%   - Uses majority voting across T-code symbols for robustness
%   - Outputs: frameTcodes [60 x nFrames], frameTcodeValid [1 x nFrames]
%
% Dataset details:
%   - Satellite:    STARLINK-31848
%   - Hardware:     v2.0-mini
%   - Frame count:  1009
%   - Capture date: January 21, 2025

clearvars
clc

starlinkConstants;

%% Use the LaTeX interpreter for all text (labels, titles, ticks, legends).
set(groot, 'defaultTextInterpreter',              'latex');
set(groot, 'defaultAxesTickLabelInterpreter',     'latex');
set(groot, 'defaultColorbarTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter',            'latex');

%% Load dataset.
fprintf('[loadAndPlotExemplarFrames] Loading dataset...\n');

% Load the dataset directly by relative path so this section can be run
% standalone (mfilename('fullpath') returns '' when evaluating by section).
datasetFile = fullfile('exemplar-frames-data', 'decodedExemplarFrames_20251019T2214.mat');
load(datasetFile);

nSubc    = size(yDataDec, 1);
nSymbols = size(yDataDec, 2);
nFrames  = size(yDataDec, 3);

fprintf('[loadAndPlotExemplarFrames] Loaded %d frames (%d subcarriers × %d symbols each)\n', ...
    nFrames, nSubc, nSymbols);

%% Define subcarrier masks.
Knz = 3:1022;            % Nonzero subcarriers
Kep = [489:496 529:536]; % Edge pilot subcarriers
Knp = setdiff(Knz, Kep); % Non-pilot subcarriers

%% 1. Modulation map.
fprintf('[loadAndPlotExemplarFrames] Generating modulation map...\n');

[~, modNames, modValues] = modEnum();
symModulations = modulationMap(modEst);

figure(1), clf
imagesc(symModulations)
axis xy

% Set up colormap.
defaultColors = get(groot, 'defaultAxesColorOrder');
N = numel(modValues);
cm = defaultColors(1:N, :);
colormap(gca, cm)
clim([-0.5 4.5])

cb = colorbar;
cb.Ticks = modValues;
cb.TickLabels = modNames;
ylabel(cb, 'Modulation Type', 'Interpreter', 'latex')

title(sprintf('Exemplar Frames: Modulation Map (%d frames)', nFrames))
xlabel('Frame Index ($m$)')
ylabel('OFDM Symbol Index ($i$)')
grid on

%% 2. Frame structure diagram.
fprintf('[loadAndPlotExemplarFrames] Plotting frame structure diagram...\n');

% Build a categorical frame map over the paper's 0-based OFDM symbol index i:
% i=0 is the PSS (time-domain), i=1 is the SSS, and i=2..301 are the 300 data
% symbols. Categories: 0 = null, 1 = PSS, 2 = SSS, 3 = data (T-code), 4 = edge
% pilot.
nSymTot  = nSymbols + 1;             % i = 0..301 (PSS + SSS + 300 data)
nullSubc = setdiff(1:sl.N, Knz);     % DC-gutter / guard-band null subcarriers
frameMap = 3 * ones(sl.N, nSymTot);  % default: data
frameMap(:, 1)       = 1;            % PSS (i=0)
frameMap(:, 2)       = 2;            % SSS (i=1)
frameMap(Kep, 3:end) = 4;            % edge pilots on data symbols (i=2..301)
frameMap(nullSubc, :) = 0;           % nulls override all columns

% Frequency-order the subcarriers for display (DC at center).
frameMap = fftshift(frameMap, 1);

% Category colors (indexed 0..4).
colNull  = [0.9 0.9 0.9];  % Light gray
colPSS   = [0.8 0.2 0.2];  % Red
colSSS   = [0.2 0.6 0.2];  % Green
colTcode = [0.3 0.5 0.8];  % Blue
colEdge  = [0.9 0.6 0.1];  % Orange

figure(2), clf
imagesc(0:nSymTot-1, 0:sl.N-1, frameMap)
axis xy
colormap(gca, [colNull; colPSS; colSSS; colTcode; colEdge])
clim([-0.5 4.5])
xlim([-1 302])
ylim([0 sl.N-1])

xticks([0 50 100 150 200 250 300])
xlabel('OFDM Symbol Index ($i$)')
title('Starlink Frame Structure')
grid on
set(gca, 'Layer', 'top')

% Left y-axis: Frequency (position p maps to frequency (p-512)*Fs/N)
freqTicks  = [0 256 512 768 1023];
freqLabels = {'$-120$', '$-60$', '$0$', '$60$', '$120$'};
yticks(freqTicks)
yticklabels(freqLabels)
ylabel('Frequency (MHz)')

% Right y-axis: Subcarrier index k (position p maps to k = mod(p+512, 1024))
yyaxis right
ylim([0 sl.N-1])
kTicks  = [0 256 512 768 1023];
kLabels = {'$512$', '$768$', '$0$', '$256$', '$511$'};
yticks(kTicks)
yticklabels(kLabels)
ylabel('Subcarrier Index ($k$)')
ax = gca;
ax.YAxis(2).Color = 'k';

% Legend (dummy patches carry the categorical colors).
yyaxis left
h = zeros(5, 1);
h(1) = patch(NaN, NaN, colPSS);
h(2) = patch(NaN, NaN, colSSS);
h(3) = patch(NaN, NaN, colTcode);
h(4) = patch(NaN, NaN, colEdge);
h(5) = patch(NaN, NaN, colNull);
legend(h, {'PSS', 'SSS', 'T-code (Data)', 'Edge Pilots', 'Null'}, ...
    'Location', 'southeast')

%% 3. Signal quality and Doppler.
fprintf('[loadAndPlotExemplarFrames] Plotting signal quality and Doppler...\n');

figure(3), clf
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'tight')

% SINR distribution.
nexttile
histogram(SINRs, 'BinWidth', 1, 'FaceColor', [0.3 0.5 0.8])
grid on
xlabel('SINR (dB)')
ylabel('Frame Count')
title(sprintf('Signal Quality Distribution (%d frames)', nFrames))
xlim([0 max(SINRs)+5])

% Doppler shift over time.
nexttile
plot(TOAs, betas * 1e6, '.-')
grid on
xlabel('Time (s)')
ylabel('Doppler $\beta$ (ppm)')
title('Carrier Frequency Offset (Doppler)')

%% 4. Decoded symbol constellation (sample frame).
fprintf('[loadAndPlotExemplarFrames] Plotting decoded symbol constellation...\n');

sampleIdx = 1;  % Use first frame as sample

figure(4), clf
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'tight')

% Plot several OFDM symbols from a sample frame. Symbol i=1 is the SSS (the
% first OFDM symbol, identical in every frame); the rest are data symbols.
symbolsToPlot = [1 50 100 150 200 250];

for idx = 1:6
    m = symbolsToPlot(idx);

    nexttile
    hold on, grid on, axis equal

    % Plot soft (noisy) symbols.
    hSoft = plot(real(yDataSoft(Knp, m, sampleIdx)), ...
         imag(yDataSoft(Knp, m, sampleIdx)), 'k.', 'MarkerSize', 4);

    % Plot hard decoded symbols.
    hHard = plot(real(yDataDec(Knp, m, sampleIdx)), ...
         imag(yDataDec(Knp, m, sampleIdx)), 'ro', 'MarkerSize', 6);

    % Unit circle.
    th = linspace(0, 2*pi, 200);
    hCirc = plot(cos(th), sin(th), 'k--', 'LineWidth', 0.5);

    xlim([-1.5 1.5])
    ylim([-1.5 1.5])
    xlabel('In-Phase')
    ylabel('Quadrature')
    if m == 1
        title('SSS ($i=1$)')
    else
        title(sprintf('Symbol $i=%d$', m))
    end

    % Legend on the last (bottom-right) panel only.
    if idx == 6
        legend([hSoft hHard hCirc], {'Soft', 'Hard', 'Unit circle'}, ...
            'Location', 'southeast')
    end
end

sgtitle(sprintf('Decoded Symbol Constellation (Frame $m=%d$, SINR=%.1f dB)', sampleIdx, SINRs(sampleIdx)), 'Interpreter', 'latex')

%% 5. Reference template comparison (decoded QPSK, template, deviation).
fprintf('[loadAndPlotExemplarFrames] Plotting reference template comparison...\n');

[~, rotations] = genReferenceTemplate();

% Find a reference template frame (all-QPSK) for comparison.
if exist('hasTemplate', 'var')
    templateFrameIdx = find(hasTemplate, 1);
else
    templateFrameIdx = 1;
end

% Convert decoded symbols to rotations for the sample frame.
decodedRotations = qpsk2rotations(yDataDec(:, :, templateFrameIdx));

% Compute deviation from reference template (mod 4 difference).
% rotations is [1024 x 301] from genReferenceTemplate().
deviation = mod(decodedRotations - rotations, 4);

% Grey out unloaded/null subcarriers (where the template is -1: gutters, DC
% nulls, and edge pilots) so all three panels share the same k=1:1024 support
% and null pattern.
nullMask = (rotations == -1);
decodedDisp = decodedRotations;
decodedDisp(nullMask) = -1;
deviation(nullMask)   = -1;

% Shared colormap/scale for all three panels: grey for nulls, parula for the
% four QPSK rotations.
rotCmap       = [0.7 0.7 0.7; parula(4)];
rotClim       = [-1.5 3.5];
rotTicks      = [-1 0 1 2 3];
rotTickLabels = {'Null', '$0$', '$\pi/2$', '$\pi$', '$3\pi/2$'};

figure(5), clf
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'tight')

% Decoded QPSK (top).
nexttile
imagesc(decodedDisp)
axis xy
xticks([1 50 100 150 200 250 301])
colormap(gca, rotCmap)
clim(rotClim)
cb = colorbar;
cb.Ticks = rotTicks;
cb.TickLabels = rotTickLabels;
ylabel(cb, '$\angle \hat{X}_{mik}$ (rad)', 'Interpreter', 'latex')
xlabel('OFDM Symbol Index ($i$)')
ylabel('Subcarrier Index ($k$)')
title(sprintf('Decoded QPSK $\\hat{X}_{mik}$ (Frame $m=%d$, SINR=%.1f dB)', templateFrameIdx, SINRs(templateFrameIdx)))

% Reference template (middle).
nexttile
imagesc(rotations)
axis xy
xticks([1 50 100 150 200 250 301])
colormap(gca, rotCmap)
clim(rotClim)
cb = colorbar;
cb.Ticks = rotTicks;
cb.TickLabels = rotTickLabels;
ylabel(cb, '$\angle T_{ik}$ (rad)', 'Interpreter', 'latex')
xlabel('OFDM Symbol Index ($i$)')
ylabel('Subcarrier Index ($k$)')
title('Reference Template $T_{ik}$')

% Deviation (bottom).
nexttile
imagesc(deviation)
axis xy
xticks([1 50 100 150 200 250 301])
colormap(gca, rotCmap)
clim(rotClim)
cb = colorbar;
cb.Ticks = rotTicks;
cb.TickLabels = rotTickLabels;
ylabel(cb, '$\angle D_{mik}$ (rad)', 'Interpreter', 'latex')
xlabel('OFDM Symbol Index ($i$)')
ylabel('Subcarrier Index ($k$)')
title('Deviation $D_{mik} = \hat{X}_{mik}\,T_{ik}^{*}$')

sgtitle(sprintf('Reference Template Comparison (Frame $m=%d$)', templateFrameIdx), 'Interpreter', 'latex')

%% 6a. T-code extraction for all frames.
fprintf('[loadAndPlotExemplarFrames] Extracting T-codes from all frames...\n');

% T-code constants.
NT = 60;          % T-code length (bits).
dT = 16;          % Circular shift per symbol.

% Thresholds for fault tolerance.
autocorrThreshold    = 0.7;   % Min autocorr at lag=60 to qualify as T-code.
bpskPurityThreshold  = 0.9;   % Min fraction of bits in {0,2}.
consistencyThreshold = 0.95;  % Min agreement across symbols.
minTcodeSymbols      = 2;     % Min T-code symbols needed for confidence.

% Create subcarrier mask (exclude pilots).
subcarrierMask = false(sl.N, 1);
subcarrierMask(Knp) = true;

% Extract rotations and compute deviation from template.
phase = angle(yDataDec);
frameRotations = mod(phase / (pi/2), 4);

% Build modulation mask: identify QPSK symbols.
[Modulation, ~, ~] = modEnum();
QPSKmask = (symModulations == Modulation.QPSK);

% Mask non-QPSK symbols.
frameRotations_2d = reshape(frameRotations, nSubc, nSymbols * nFrames);
frameRotations_2d(:, ~QPSKmask(:).') = NaN;
frameRotations = reshape(frameRotations_2d, nSubc, nSymbols, nFrames);

% Mask invalid subcarriers.
frameRotations(~subcarrierMask, :, :) = NaN;

% Compute deviation from reference template (symbols 2:end, excluding SSS).
diffRotations = mod(frameRotations(:, 2:end, :) - rotations(:, 2:end), 4);

% Initialize T-code storage.
frameTcodes = nan(NT, nFrames);
frameTcodeValid = false(1, nFrames);

for iFrame = 1:nFrames
    % Find QPSK symbols (excluding SSS at index 1).
    qpskSymbols = find(QPSKmask(2:end, iFrame));
    if isempty(qpskSymbols)
        continue
    end

    % Extract T-code candidates from each QPSK symbol.
    maxTcodeSymbols = length(qpskSymbols);
    tcodeEstimates = nan(maxTcodeSymbols, NT);
    nTcodeSymbols = 0;

    for iSym = qpskSymbols'
        devCol = diffRotations(:, iSym, iFrame);

        % Check 1: 60-subcarrier periodicity via autocorrelation.
        devColClean = devCol;
        devColClean(isnan(devColClean)) = 0;

        [acorr, lags] = xcorr(devColClean - mean(devColClean, 'omitnan'), 'coeff');
        lag60idx = find(lags == NT);
        if isempty(lag60idx) || acorr(lag60idx) < autocorrThreshold
            continue  % Not a T-code symbol, probably header.
        end

        % Extract raw T-code from first NT valid subcarriers.
        firstValid = find(~isnan(devCol), 1, 'first');
        if isempty(firstValid) || (firstValid + NT - 1) > length(devCol)
            continue
        end

        rawTcode = devCol(firstValid + (0:NT-1));

        % Check 2: BPSK validation (values must be in {0, 2} mod 4).
        rawTcodeMod4 = mod(rawTcode, 4);
        isBpsk = (rawTcodeMod4 == 0) | (rawTcodeMod4 == 2);
        bpskPurity = sum(isBpsk) / NT;

        if bpskPurity < bpskPurityThreshold
            continue
        end

        % De-rotate by symbol index to get canonical T-code.
        shiftAmt = mod(-dT * (iSym - 1), NT);
        canonicalTcode = circshift(rawTcodeMod4, shiftAmt);

        % Convert 0/2 to 0/1 binary.
        bpskTcode = mod(round(canonicalTcode / 2), 2);

        nTcodeSymbols = nTcodeSymbols + 1;
        tcodeEstimates(nTcodeSymbols, :) = bpskTcode';
    end

    % Trim to actual size.
    tcodeEstimates = tcodeEstimates(1:nTcodeSymbols, :);

    % Check 3: Minimum symbol count.
    if nTcodeSymbols < minTcodeSymbols
        continue
    end

    % Check 4: Consistency across symbols.
    if nTcodeSymbols == 1
        finalTcode = tcodeEstimates;
        consistency = 1.0;
    else
        majorityTcode = mode(tcodeEstimates, 1);
        agreementMatrix = (tcodeEstimates == majorityTcode);
        bitAgreement = mean(agreementMatrix, 1);
        consistency = mean(bitAgreement);

        if consistency < consistencyThreshold
            continue
        end

        finalTcode = majorityTcode;
    end

    % Canonicalize: normalize so first bit is 0.
    if finalTcode(1) == 1
        finalTcode = 1 - finalTcode;
    end

    % Store valid T-code.
    frameTcodes(:, iFrame) = finalTcode';
    frameTcodeValid(iFrame) = true;
end

% Print extraction statistics.
nValid = sum(frameTcodeValid);
fprintf('\n--- T-Code Extraction Statistics ---\n')
fprintf('Total frames: %d\n', nFrames)
fprintf('Valid T-codes extracted: %d (%.1f%%)\n', nValid, 100 * nValid / nFrames)

%% 6b. T-code diversity analysis.
fprintf('\n[loadAndPlotExemplarFrames] Analyzing T-code diversity...\n');

validFrames = find(frameTcodeValid);
nValidFrames = length(validFrames);

if nValidFrames > 0
    % Find unique T-codes (considering circular equivalence).
    uniqueTcodes = {};
    tcodeFrameMap = {};

    for iValid = 1:nValidFrames
        iFrame = validFrames(iValid);
        thisTcode = frameTcodes(:, iFrame)';

        % Check against existing unique T-codes.
        foundIdx = 0;
        for iUniq = 1:length(uniqueTcodes)
            if checkCircularEquivalenceLocal(thisTcode, uniqueTcodes{iUniq})
                foundIdx = iUniq;
                break
            end
        end

        if foundIdx > 0
            tcodeFrameMap{foundIdx}(end+1) = iFrame;
        else
            uniqueTcodes{end+1} = thisTcode;
            tcodeFrameMap{end+1} = iFrame;
        end
    end

    nUniqueTcodes = length(uniqueTcodes);
    occurrenceCounts = cellfun(@length, tcodeFrameMap);

    fprintf('\n--- T-Code Diversity Results ---\n')
    fprintf('Frames with valid T-codes: %d\n', nValidFrames)
    fprintf('Unique T-codes observed: %d\n', nUniqueTcodes)
    fprintf('Average occurrences per T-code: %.2f\n', mean(occurrenceCounts))
    fprintf('Max occurrences for single T-code: %d\n', max(occurrenceCounts))

    % 6c. T-code visualization.
    figure(6), clf
    tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'tight')

    % Plot 1: Occurrence histogram.
    nexttile
    histogram(occurrenceCounts, 'BinMethod', 'integers', 'FaceColor', [0.3 0.5 0.8])
    xlabel('Number of Occurrences')
    ylabel('Number of T-Codes')
    title('T-Code Occurrence Distribution')
    grid on

    % Plot 2: Discovery curve.
    nexttile
    cumUnique = zeros(nFrames, 1);
    seenSet = {};
    nSeen = 0;
    for iFrame = 1:nFrames
        if frameTcodeValid(iFrame)
            thisTcode = frameTcodes(:, iFrame)';
            isNew = true;
            for j = 1:nSeen
                if checkCircularEquivalenceLocal(thisTcode, seenSet{j})
                    isNew = false;
                    break
                end
            end
            if isNew
                nSeen = nSeen + 1;
                seenSet{nSeen} = thisTcode;
            end
        end
        cumUnique(iFrame) = nSeen;
    end
    plot(1:nFrames, cumUnique, 'b-', 'LineWidth', 2)
    hold on
    xLimits = [1 sum(frameTcodeValid)];
    plot([1 nFrames], xLimits, 'r--', 'LineWidth', 1)
    xlabel('Frame Index ($m$)')
    ylabel('Cumulative Unique T-Codes')
    title('Discovery Curve')
    legend('Observed', 'No repeats', 'Location', 'northwest')
    xlim(xLimits)
    grid on

    % Plot 3: Most common T-codes heatmap (spans the bottom row).
    nexttile([1 2])
    [~, sortIdx] = sort(occurrenceCounts, 'descend');
    nShow = min(15, nUniqueTcodes);
    topTcodes = zeros(nShow, NT);
    for i = 1:nShow
        topTcodes(i, :) = uniqueTcodes{sortIdx(i)};
    end
    imagesc(topTcodes)
    colormap(gca, [0 0.4 0.8; 0.9 0.9 0.2])
    xlabel('Bit Position ($1$ to $N_\mathrm{T}$)')
    ylabel(sprintf('T-Code Rank (top %d)', nShow))
    title('Most Frequent T-Codes')
    cb = colorbar;
    cb.Ticks = [0.25 0.75];
    cb.TickLabels = {'0', '1'};

    sgtitle(sprintf('T-Code Analysis ($N_\\mathrm{T}=%d$, $d_\\mathrm{T}=%d$)', NT, dT), 'FontWeight', 'bold', 'Interpreter', 'latex')
end

fprintf('\n[loadAndPlotExemplarFrames] Done.\n');

%% Local functions.

function areEquivalent = checkCircularEquivalenceLocal(seq1, seq2)
    % Checks if two sequences are circularly equivalent.
    seq1 = seq1(:)';
    seq2 = seq2(:)';

    if length(seq1) ~= length(seq2)
        areEquivalent = false;
        return
    end

    tempSeq = [seq1, seq1];
    areEquivalent = ~isempty(strfind(tempSeq, seq2)); %#ok<STREMP>
end
