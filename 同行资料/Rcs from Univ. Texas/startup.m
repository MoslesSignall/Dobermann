% startup.m
%
% Starlink Exemplar Frames Dataset
% University of Texas at Austin - Radionavigation Laboratory
%
% Paper: "Pilots and Other Predictable Elements of the Starlink Ku-Band
%         Downlink"
clear;
clc;
close all;

fprintf('================================================================\n');
fprintf('  Starlink Exemplar Frames Dataset\n');
fprintf('  University of Texas at Austin\n');
fprintf('  Radionavigation Laboratory\n\n');
fprintf('  Paper: "Pilots and Other Predictable Elements of the\n');
fprintf('          Starlink Ku-Band Downlink"\n');
fprintf('================================================================\n\n');

% Get the directory containing this startup script
startupDir = fileparts(mfilename('fullpath'));

% Add necessary subdirectories to MATLAB path
addpath(fullfile(startupDir, 'utils', 'signalProcessing'));
addpath(fullfile(startupDir, 'utils', 'complexConstellations'));
addpath(fullfile(startupDir, 'reference-template'));
addpath(startupDir);

fprintf('Paths configured.\n\n');

fprintf('Available functions:\n');
fprintf('  - loadAndPlotExemplarFrames : Visualize the exemplar frames dataset\n');
fprintf('  - genReferenceTemplate      : Generate the reference template\n');
fprintf('  - genPss                    : Generate the PSS sequence\n');
fprintf('  - genSss                    : Generate the SSS sequence\n');
fprintf('  - genEdgePilots             : Generate edge pilot matrix\n');
fprintf('  - correlateEdgePilots       : Correlate against edge pilots\n');
fprintf('  - modulationMap             : Map modulation estimates to types\n');
fprintf('  - qpsk2rotations            : Convert QPSK symbols to rotations\n\n');
