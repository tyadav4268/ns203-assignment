% combine_participant_plots.m
% Select one participant folder, then select all four plot images at once.
% The combined 2x2 summary is saved in the selected participant folder.

clear;
clc;
close all;

% Select the participant folder.
participantFolder = uigetdir(pwd, 'Select participant folder');

if isequal(participantFolder, 0)
    fprintf('No folder selected. Exiting.\n');
    return;
end

% Infer participant ID from the selected folder name.
[~, folderName] = fileparts(participantFolder);
participantMatch = regexp(folderName, '\d+', 'match', 'once');

if isempty(participantMatch)
    answer = inputdlg('Enter the participant ID:', ...
                      'Participant ID', [1 40], {''});
    if isempty(answer) || isempty(strtrim(answer{1}))
        fprintf('No participant ID provided. Exiting.\n');
        return;
    end
    participantID = strtrim(answer{1});
else
    participantID = participantMatch;
end

% Select all four plot images in a single file-picker operation.
[fileNames, filePath] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', ...
     'Image files (*.png, *.jpg, *.jpeg, *.tif, *.tiff, *.bmp)'}, ...
    'Select all four plot images (Ctrl-click or Shift-click)', ...
    participantFolder, ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    fprintf('No files selected. Exiting.\n');
    return;
end

% MATLAB returns a character vector for one file and a cell array for
% multiple files. Normalize to a cell array.
if ischar(fileNames)
    fileNames = {fileNames};
end

if numel(fileNames) ~= 4
    error('Exactly four plot images must be selected. You selected %d.', ...
          numel(fileNames));
end

% Try to arrange files by recognizable words in their filenames.
% If a filename does not match, the original file-picker order is retained
% for that plot position.
plotKeywords = { ...
    {'sensitivity', 'dprime', 'd_prime', 'psychophysical'}, ...
    {'criterion', 'response_criterion'}, ...
    {'roc'}, ...
    {'accuracy', 'response_time', 'mean_rt', 'meanrt'}};

orderedFiles = cell(1, 4);
used = false(1, 4);

for plotIndex = 1:4
    for fileIndex = 1:4
        if used(fileIndex)
            continue;
        end

        lowerName = lower(fileNames{fileIndex});

        for keywordIndex = 1:numel(plotKeywords{plotIndex})
            if contains(lowerName, plotKeywords{plotIndex}{keywordIndex})
                orderedFiles{plotIndex} = fileNames{fileIndex};
                used(fileIndex) = true;
                break;
            end
        end

        if used(fileIndex)
            break;
        end
    end
end

% Fill any unmatched positions using the remaining selected files.
remainingFiles = fileNames(~used);
remainingIndex = 1;

for plotIndex = 1:4
    if isempty(orderedFiles{plotIndex})
        orderedFiles{plotIndex} = remainingFiles{remainingIndex};
        remainingIndex = remainingIndex + 1;
    end
end

% Create the combined figure.
fig = figure( ...
    'Color', 'white', ...
    'Units', 'pixels', ...
    'Position', [100 100 1500 1100], ...
    'Name', ['Participant ', participantID, ' summary']);

layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

for i = 1:4
    ax = nexttile(layout);
    imageFile = fullfile(filePath, orderedFiles{i});
    plotImage = imread(imageFile);

    imshow(plotImage, 'Parent', ax);
    axis(ax, 'image');
    axis(ax, 'off');
end

title(layout, ...
    ['Participant ', participantID, ': individual results'], ...
    'FontSize', 20, ...
    'FontWeight', 'bold', ...
    'Color', 'black');

% Save the summary in the selected participant folder.
outputFile = fullfile( ...
    participantFolder, ...
    ['participant_', participantID, '_summary.png']);

exportgraphics(fig, outputFile, ...
    'Resolution', 300, ...
    'BackgroundColor', 'white');

fprintf('\nCombined participant figure saved successfully:\n%s\n', outputFile);
