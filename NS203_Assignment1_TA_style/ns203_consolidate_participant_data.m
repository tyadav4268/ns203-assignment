%% NS203 Assignment 1: Consolidate participant raw data
% Select the five original trial_data CSV files.
% This script validates the files and combines them without imputing
% missing responses. It does not perform group-level statistics or plots.

clear;
clc;

fprintf('NS203 participant-data consolidation started.\n');

expectedParticipantIDs = [203, 205, 207, 210, 211];
expectedRowsPerParticipant = 240;
expectedSetSizes = [4, 6, 8];

[fileNames, dataFolder] = uigetfile( ...
    '*.csv', ...
    'Select the five participant trial-data CSV files', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    fprintf('No files selected. Consolidation cancelled.\n');
    return;
end

if ischar(fileNames)
    fileNames = {fileNames};
end

if numel(fileNames) ~= numel(expectedParticipantIDs)
    error('Expected exactly %d CSV files, but selected %d.', ...
        numel(expectedParticipantIDs), numel(fileNames));
end

allData = table();
qualityRows = table();
seenParticipantIDs = [];

for fileIndex = 1:numel(fileNames)
    currentFile = fullfile(dataFolder, fileNames{fileIndex});

    if ~isfile(currentFile)
        error('Raw data file not found: %s', currentFile);
    end

    fprintf('\nReading file: %s\n', currentFile);
    currentData = readtable(currentFile);

    requiredVariables = { ...
        'participantID', 'session', 'trialNum', 'setSize', ...
        'probeNumber', 'isOld', 'confidence', 'responseOld', ...
        'correct', 'RT', 'completed'};

    missingVariables = setdiff(requiredVariables, ...
        currentData.Properties.VariableNames);

    if ~isempty(missingVariables)
        error('File %s is missing required columns: %s', ...
            fileNames{fileIndex}, strjoin(missingVariables, ', '));
    end

    participantIDsInFile = unique(currentData.participantID);

    if numel(participantIDsInFile) ~= 1
        error('File %s contains more than one participant ID.', ...
            fileNames{fileIndex});
    end

    participantID = participantIDsInFile(1);

    if ismember(participantID, seenParticipantIDs)
        error('Participant ID %d appears in more than one selected file.', ...
            participantID);
    end

    seenParticipantIDs(end + 1) = participantID;

    if height(currentData) ~= expectedRowsPerParticipant
        error('Participant %d has %d rows; expected %d.', ...
            participantID, height(currentData), expectedRowsPerParticipant);
    end

    observedSetSizes = sort(unique(currentData.setSize(:)))';

    if ~isequal(observedSetSizes, expectedSetSizes)
        error('Participant %d has unexpected set sizes: %s', ...
            participantID, mat2str(observedSetSizes));
    end

    rowsPerSetSize = zeros(numel(expectedSetSizes), 1);

    for setIndex = 1:numel(expectedSetSizes)
        rowsPerSetSize(setIndex) = sum( ...
            currentData.setSize == expectedSetSizes(setIndex));
    end

    if any(rowsPerSetSize ~= 80)
        error('Participant %d does not have exactly 80 rows per set size.', ...
            participantID);
    end

    validResponse = ~ismissing(currentData.responseOld);
    validRT = ~ismissing(currentData.RT);
    completedRows = currentData.completed == 1;

    qualityRow = table( ...
        participantID, ...
        currentData.session(1), ...
        height(currentData), ...
        sum(completedRows), ...
        sum(validResponse), ...
        sum(~validResponse), ...
        sum(validRT), ...
        'VariableNames', { ...
        'participantID', 'session', 'totalRows', 'completedRows', ...
        'validResponses', 'missingResponses', 'validRTs'});

    qualityRows = [qualityRows; qualityRow];
    allData = [allData; currentData];

    fprintf('Participant %d: %d rows, %d valid responses, %d missing.\n', ...
        participantID, height(currentData), sum(validResponse), ...
        sum(~validResponse));
end

if ~isequal(sort(seenParticipantIDs), expectedParticipantIDs)
    error('Selected participant IDs do not match the expected IDs. Found: %s', ...
        mat2str(sort(seenParticipantIDs)));
end

allData = sortrows(allData, {'participantID', 'trialNum', 'probeNumber'});
qualityRows = sortrows(qualityRows, 'participantID');

outputFolder = fullfile(dataFolder, 'Group_Level_Analysis');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

combinedFile = fullfile(outputFolder, 'all_participants_raw_data.csv');
qualityFile = fullfile(outputFolder, 'participant_data_quality.csv');

writetable(allData, combinedFile);
writetable(qualityRows, qualityFile);

fprintf('\nConsolidation completed successfully.\n');
fprintf('Participants: %s\n', mat2str(sort(seenParticipantIDs)));
fprintf('Total raw rows: %d\n', height(allData));
fprintf('Total valid responses: %d\n', sum(~ismissing(allData.responseOld)));
fprintf('Total missing responses: %d\n', sum(ismissing(allData.responseOld)));
fprintf('Combined data: %s\n', combinedFile);
fprintf('Data quality table: %s\n', qualityFile);
