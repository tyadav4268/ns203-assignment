%% NS 203 Assignment 1: Sequential word-recognition working-memory task
% Requires Psychtoolbox, Paivio.csv, and the Task Functions folder.

sca;
close all;
clearvars;
clc;

addpath('Task Functions');

%% Participant and session-specific output folder
participantID = strtrim(input('Enter participant ID (e.g., P001): ', 's'));
if isempty(participantID) || any(~isstrprop(participantID, 'alphanum') & participantID ~= '_' & participantID ~= '-')
    error('Participant ID must contain only letters, numbers, underscores, or hyphens.');
end

rootFolder = 'NS203_Beh_Results';
if ~exist(rootFolder, 'dir')
    mkdir(rootFolder);
end
participantFolder = fullfile(rootFolder, participantID);
if ~exist(participantFolder, 'dir')
    mkdir(participantFolder);
end
sessionNumber = 1;
while exist(fullfile(participantFolder, sprintf('Session_%02d', sessionNumber)), 'dir')
    sessionNumber = sessionNumber + 1;
end
sessionFolder = fullfile(participantFolder, sprintf('Session_%02d', sessionNumber));
mkdir(sessionFolder);
fprintf('Saving data to: %s\n', sessionFolder);

%% Design
setSizes = [4 6 8];
NumberOfBlocks = 4;
TrialsPerSetSize = 20;
TrialsPerBlock = 15;
TrialsPerSetSizePerBlock = 5;
NumberOfTrials = numel(setSizes) * TrialsPerSetSize;
ProbesPerTrial = 4;
OldProbesPerTrial = 2;
NewProbesPerTrial = 2;
PracticeTrials = 3;
practiceSetSizes = [4 6 4];

%% Timing in seconds
fixationDuration = 0.5;
wordDuration = 0.7;
interWordDuration = 0.3;
retentionDuration = 1.0;
responseDuration = 5.0;
interProbeDuration = 0.5;
interTrialDuration = 1.0;

%% Display settings
PsychDefaultSetup(2);
screens = Screen('Screens');
screenNumber = max(screens);
black = [0 0 0];
backgroundColor = [80 80 80];

%% Load Paivio word list and word-length information
wordTable = readtable('Paivio.csv');
if ~ismember('word', wordTable.Properties.VariableNames) || ~ismember('letters', wordTable.Properties.VariableNames)
    error('Paivio.csv must contain both word and letters columns.');
end
wordPool = cellstr(string(wordTable.word));
wordPool = cellfun(@strtrim, wordPool, 'UniformOutput', false);
wordPool = cellfun(@lower, wordPool, 'UniformOutput', false);
wordLengths = double(wordTable.letters);
validRows = ~cellfun(@isempty, wordPool) & ~isnan(wordLengths) & wordLengths >= 4 & wordLengths <= 9;
wordPool = wordPool(validRows);
wordLengths = wordLengths(validRows);
[wordPool, uniqueIndices] = unique(wordPool, 'stable');
wordLengths = wordLengths(uniqueIndices);

requiredWords = sum(setSizes) * TrialsPerSetSize + ...
    NumberOfTrials * NewProbesPerTrial;
if numel(wordPool) < requiredWords
    error('Paivio word pool has %d usable words; at least %d are required.', numel(wordPool), requiredWords);
end
fprintf('Loaded %d unique words with length norms from Paivio.csv.\n', numel(wordPool));

%% Generate study lists and four sequential probes per study-list trial
rng('shuffle');
trialSetSize = zeros(NumberOfTrials, 1);
for blockNo = 1:NumberOfBlocks
    blockStart = (blockNo - 1) * TrialsPerBlock + 1;
    blockEnd = blockNo * TrialsPerBlock;
    blockSetSizes = repelem(setSizes(:), TrialsPerSetSizePerBlock);
    blockSetSizes = blockSetSizes(randperm(TrialsPerBlock));
    trialSetSize(blockStart:blockEnd) = blockSetSizes;
end

oldCountByTrial = ones(NumberOfTrials, 1);
incrementSlots = repelem((1:NumberOfTrials)', 2);
selectedSlots = incrementSlots(randperm(numel(incrementSlots), NumberOfTrials));
for countNo = 1:numel(selectedSlots)
    oldCountByTrial(selectedSlots(countNo)) = oldCountByTrial(selectedSlots(countNo)) + 1;
end

usedWords = false(numel(wordPool), 1);
studyWordsByTrial = cell(NumberOfTrials, 1);
probeWordsByTrial = cell(NumberOfTrials, 1);
probeOldByTrial = zeros(NumberOfTrials, ProbesPerTrial);

for trialNo = 1:NumberOfTrials
    nStudyWords = trialSetSize(trialNo);
    [studyIndices, usedWords] = selectSimilarLengthWords(wordPool, wordLengths, usedWords, nStudyWords);
    studyWords = wordPool(studyIndices);
    studyWordsByTrial{trialNo} = studyWords;
    nOldProbes = oldCountByTrial(trialNo);
    nNewProbes = ProbesPerTrial - nOldProbes;

oldProbeIndices = studyIndices(randperm(nStudyWords, nOldProbes));
oldProbeWords = wordPool(oldProbeIndices);
usedWords(oldProbeIndices) = true;

newProbeWords = cell(nNewProbes, 1);

for probeNo = 1:nNewProbes
    targetLength = wordLengths(oldProbeIndices(min(probeNo, nOldProbes)));
    available = find(~usedWords & abs(wordLengths - targetLength) <= 1);
    if isempty(available)
        available = find(~usedWords & abs(wordLengths - targetLength) <= 2);
    end
    if isempty(available)
        available = find(~usedWords);
    end
    chosenIndex = available(randi(numel(available)));
    newProbeWords{probeNo} = wordPool{chosenIndex};
    usedWords(chosenIndex) = true;
end

combinedProbeWords = [oldProbeWords(:); newProbeWords(:)];
combinedProbeOld = [ones(nOldProbes, 1); zeros(nNewProbes, 1)];
probeOrder = randperm(ProbesPerTrial);
probeWordsByTrial{trialNo} = combinedProbeWords(probeOrder);
probeOldByTrial(trialNo, :) = combinedProbeOld(probeOrder);
end

% One row per probe response; the study-list trial ID links the four probes.
NumberOfProbeRows = NumberOfTrials * ProbesPerTrial;
participantColumn = repmat(string(participantID), NumberOfProbeRows, 1);
sessionColumn = repmat(sessionNumber, NumberOfProbeRows, 1);
blockColumn = repelem((1:NumberOfBlocks)', TrialsPerBlock * ProbesPerTrial);
trialColumn = repelem((1:NumberOfTrials)', ProbesPerTrial);
probeColumn = repmat((1:ProbesPerTrial)', NumberOfTrials, 1);
setSizeColumn = repelem(trialSetSize, ProbesPerTrial);
studyWordsColumn = strings(NumberOfProbeRows, 1);
probeWordColumn = strings(NumberOfProbeRows, 1);
isOldColumn = zeros(NumberOfProbeRows, 1);
for trialNo = 1:NumberOfTrials
    rows = (trialNo - 1) * ProbesPerTrial + (1:ProbesPerTrial);
    studyWordsColumn(rows) = strjoin(studyWordsByTrial{trialNo}, ';');
    probeWordColumn(rows) = string(probeWordsByTrial{trialNo});
    isOldColumn(rows) = probeOldByTrial(trialNo, :)';
end
trialData = table(participantColumn, sessionColumn, blockColumn, trialColumn, setSizeColumn, ...
    studyWordsColumn, probeColumn, probeWordColumn, isOldColumn, nan(NumberOfProbeRows, 1), ...
    nan(NumberOfProbeRows, 1), nan(NumberOfProbeRows, 1), nan(NumberOfProbeRows, 1), ...
    strings(NumberOfProbeRows, 1), false(NumberOfProbeRows, 1), ...
    'VariableNames', {'participantID','session','block','trialNum','setSize','studyWords', ...
    'probeNumber','probeWord','isOld','confidence','responseOld','correct','RT','responseKey','completed'});

%% Calculate estimated duration before opening the experiment
expectedStudySeconds = sum(trialSetSize .* (wordDuration + interWordDuration));
fixedPerTrialSeconds = fixationDuration + retentionDuration + ...
    (ProbesPerTrial - 1) * interProbeDuration + interTrialDuration;
maxProbeSeconds = NumberOfProbeRows * responseDuration;
maxExperimentSeconds = expectedStudySeconds + NumberOfTrials * fixedPerTrialSeconds + maxProbeSeconds;
practiceStudySeconds = sum(practiceSetSizes) * (wordDuration + interWordDuration);
maxPracticeSeconds = practiceStudySeconds + PracticeTrials * ...
    (fixationDuration + retentionDuration + (ProbesPerTrial - 1) * interProbeDuration + ...
    ProbesPerTrial * responseDuration + ProbesPerTrial * 1.0);
estimatedMinimumSeconds = expectedStudySeconds + NumberOfTrials * fixedPerTrialSeconds + ...
    NumberOfProbeRows * 1.0 + practiceStudySeconds + PracticeTrials * ...
    (fixationDuration + retentionDuration + (ProbesPerTrial - 1) * interProbeDuration + ...
    ProbesPerTrial * 1.0 + ProbesPerTrial * 1.0);
maxTotalSeconds = maxExperimentSeconds + maxPracticeSeconds + 180;
fprintf('\nEstimated task duration (including practice and ~3 min for instructions/breaks):\n');
fprintf('  Approximate duration with 1-second average probe responses: %.1f minutes\n', estimatedMinimumSeconds / 60 + 3);
fprintf('  Conservative upper estimate if responses take the full %.0f seconds: %.1f minutes\n\n', responseDuration, maxTotalSeconds / 60);

%% Open full-screen Psychtoolbox window
[window, windowRect] = Screen('OpenWindow', screenNumber, backgroundColor);
Screen('TextFont', window, 'Arial');
Screen('TextSize', window, 24);
HideCursor;
KbName('UnifyKeyNames');
keySpace = KbName('space');
keyEscape = KbName('ESCAPE');
key1 = KbName('1!');
key2 = KbName('2@');
key3 = KbName('3#');
key4 = KbName('4$');

try
    MessageString = sprintf(['WORD RECOGNITION / WORKING-MEMORY TASK\n\n' ...
        'You will see a list of words, one at a time.\n' ...
        'Try to remember the words.\n' ...
        'After a short pause, test words will appear one by one.\n' ...
        'For each test word, decide how likely it is that you saw it\n' ...
        'in the earlier list.\n\n' ...
        '1 = Definitely NEW     2 = Probably NEW\n' ...
        '3 = Probably OLD       4 = Definitely OLD\n\n' ...
        'Respond using the keys 1, 2, 3, or 4.\n' ...
        'Press SPACE to begin practice. Press ESC to quit.']);
    ns203_dispTextMessage(window, backgroundColor, black, MessageString);
    ns203_waitForSpace(keySpace, keyEscape);

    %% Practice: 3 study lists, each followed by four sequential probes
    practicePool = {'apple','river','chair','cloud','garden','pencil','window','planet','button','forest', ...
        'candle','mirror','pocket','camera','rabbit','castle','bridge','orange','silver','carpet', ...
        'hammer','bottle','basket','kitten','tunnel','marble','flower','ladder','ticket','pillow', ...
        'anchor','beacon','copper','desert','engine','fabric','guitar','helmet','island','jacket', ...
        'lemon','magnet','napkin','ocean','parrot','quartz','rocket','saddle','temple','velvet', ...
        'wallet','yellow','zebra','artist','branch','circle','dinner','energy','frozen','golden', ...
        'honest','insect','jungle','kernel','little','market','number','object','people','quietly'};
    practiceCursor = 1;
    for practiceNo = 1:PracticeTrials
        nStudyWords = practiceSetSizes(practiceNo);
        studyWords = practicePool(practiceCursor:practiceCursor + nStudyWords - 1);
        practiceCursor = practiceCursor + nStudyWords;
        oldProbeWords = studyWords(randperm(nStudyWords, OldProbesPerTrial));
        newProbeWords = practicePool(practiceCursor:practiceCursor + NewProbesPerTrial - 1);
        practiceCursor = practiceCursor + NewProbesPerTrial;
        practiceProbeWords = [oldProbeWords(:); newProbeWords(:)];
        practiceProbeOld = [ones(OldProbesPerTrial, 1); zeros(NewProbesPerTrial, 1)];
        practiceOrder = randperm(ProbesPerTrial);
        practiceProbeWords = practiceProbeWords(practiceOrder);
        practiceProbeOld = practiceProbeOld(practiceOrder);
        ns203_showText(window, backgroundColor, black, '+');
        WaitSecs(fixationDuration);
        for wordNo = 1:numel(studyWords)
            ns203_showText(window, backgroundColor, black, upper(studyWords{wordNo}));
            WaitSecs(wordDuration);
            ns203_showBlank(window, backgroundColor);
            WaitSecs(interWordDuration);
        end
        ns203_showText(window, backgroundColor, black, '+');
        WaitSecs(retentionDuration);
        for probeNo = 1:ProbesPerTrial
            MessageString = sprintf('TEST WORD\n\n%s\n\n1  Definitely NEW   \n\n  2  Probably NEW\n\n3  Probably OLD   \n\n    4  Definitely OLD', ...
                upper(practiceProbeWords{probeNo}));
            ns203_showText(window, backgroundColor, black, MessageString);
            [practiceConfidence, ~, ~] = ns203_getConfidence(responseDuration, key1, key2, key3, key4, keyEscape);
            if isnan(practiceConfidence)
                practiceIsCorrect = NaN;
            else
                practiceResponseOld = practiceConfidence >= 3;
                practiceIsCorrect = double(practiceResponseOld == practiceProbeOld(probeNo));
            end
            if isnan(practiceConfidence)
                feedbackMessage = 'No response recorded.';
            elseif practiceIsCorrect
                feedbackMessage = 'Correct!';
            else
                feedbackMessage = 'Incorrect.';
            end
            ns203_showText(window, backgroundColor, black, feedbackMessage);
            WaitSecs(1.0);
            
            if probeNo < ProbesPerTrial
                ns203_showBlank(window, backgroundColor);
                WaitSecs(interProbeDuration);
            end
        end
        ns203_showBlank(window, backgroundColor);
        WaitSecs(interTrialDuration);
    end

    ns203_dispTextMessage(window, backgroundColor, black, sprintf('Practice finished.\n\nThe main task estimated duration: about %.0f–%.0f minutes.\n\nPress SPACE to begin Block 1.', ...
        estimatedMinimumSeconds / 60 + 3, maxTotalSeconds / 60));
    ns203_waitForSpace(keySpace, keyEscape);
    experimentClock = tic;

    %% Main experiment
    for blockNumber = 1:NumberOfBlocks
        ns203_dispTextMessage(window, backgroundColor, black, sprintf('Block %d of %d\n\nWhen you are ready, press SPACE to begin.', blockNumber, NumberOfBlocks));
        ns203_waitForSpace(keySpace, keyEscape);
        blockStart = (blockNumber - 1) * TrialsPerBlock + 1;
        blockEnd = blockNumber * TrialsPerBlock;
        for trialNo = blockStart:blockEnd
            studyWords = studyWordsByTrial{trialNo};
            ns203_showText(window, backgroundColor, black, '+');
            WaitSecs(fixationDuration);
            for wordNo = 1:numel(studyWords)
                ns203_showText(window, backgroundColor, black, upper(studyWords{wordNo}));
                WaitSecs(wordDuration);
                ns203_showBlank(window, backgroundColor);
                WaitSecs(interWordDuration);
            end
            ns203_showText(window, backgroundColor, black, '+');
            WaitSecs(retentionDuration);
            for probeNo = 1:ProbesPerTrial
                row = (trialNo - 1) * ProbesPerTrial + probeNo;
                MessageString = sprintf('TEST WORD\n\n%s\n\n1  Definitely NEW \n\n    2  Probably NEW\n\n3  Probably OLD  \n\n     4  Definitely OLD', ...
                    upper(char(trialData.probeWord(row))));
                ns203_showText(window, backgroundColor, black, MessageString);
                [confidence, RT, responseKey] = ns203_getConfidence(responseDuration, key1, key2, key3, key4, keyEscape);
                responseOld = double(confidence >= 3);
                if isnan(confidence)
                    responseOld = NaN;
                    isCorrect = NaN;
                else
                    isCorrect = double(responseOld == trialData.isOld(row));
                end
                trialData.confidence(row) = confidence;
                trialData.responseOld(row) = responseOld;
                trialData.correct(row) = isCorrect;
                trialData.RT(row) = RT;
                trialData.responseKey(row) = responseKey;
                trialData.completed(row) = true;
                writetable(trialData, fullfile(sessionFolder, 'trial_data_checkpoint.csv'));
                save(fullfile(sessionFolder, 'trial_data_checkpoint.mat'), 'trialData', 'setSizes', ...
                    'NumberOfBlocks', 'TrialsPerSetSize', 'TrialsPerBlock', 'TrialsPerSetSizePerBlock', 'ProbesPerTrial', 'participantID', 'sessionNumber', 'blockNumber', 'trialNo', 'probeNo');
                if probeNo < ProbesPerTrial
                    ns203_showBlank(window, backgroundColor);
                    WaitSecs(interProbeDuration);
                end
            end
            ns203_showBlank(window, backgroundColor);
            WaitSecs(interTrialDuration);
        end
        if blockNumber < NumberOfBlocks
            ns203_dispTextMessage(window, backgroundColor, black, sprintf(['Block %d of %d is complete.\n\n' ...
                'Please take a short break.\n\n' ...
                'Press SPACE when you are ready to begin Block %d.'], ...
                blockNumber, NumberOfBlocks, blockNumber + 1));
            ns203_waitForSpace(keySpace, keyEscape);
        end
    end
    elapsedSeconds = toc(experimentClock);

    %% Save final probe-level data
    dateTime = datestr(now, 'yyyymmdd_HHMMSS');
    writetable(trialData, fullfile(sessionFolder, ['trial_data_' dateTime '.csv']));
    save(fullfile(sessionFolder, ['trial_data_' dateTime '.mat']), 'trialData', 'setSizes', ...
        'NumberOfBlocks', 'TrialsPerSetSize', 'TrialsPerBlock', 'TrialsPerSetSizePerBlock', 'ProbesPerTrial', 'participantID', 'sessionNumber', 'elapsedSeconds');

    %% Data collection only: no summary analysis or plots are generated here.
    % Raw probe-level responses have already been saved to CSV and MAT files above.

    fprintf('\nExperiment completed. Elapsed main-task time: %.1f minutes.\n', elapsedSeconds / 60);
    fprintf('Raw data saved in: %s\n', sessionFolder);
    ns203_dispTextMessage(window, backgroundColor, black, ...
        sprintf('Experiment completed!\n\nElapsed time: %.1f minutes\n\nYour results have been saved.', elapsedSeconds / 60));
    WaitSecs(5);
    sca;
    ShowCursor;
catch ME
    sca;
    ShowCursor;
    rethrow(ME);
end

%% Local helper: choose words with similar lengths and mark them as used
function [chosenIndices, usedWords] = selectSimilarLengthWords(wordPool, wordLengths, usedWords, numberToChoose)
available = find(~usedWords);
if numel(available) < numberToChoose
    error('Not enough unused words remain in the word pool.');
end
anchorIndex = available(randi(numel(available)));
anchorLength = wordLengths(anchorIndex);
candidates = available(abs(wordLengths(available) - anchorLength) <= 1);
if numel(candidates) < numberToChoose
    candidates = available(abs(wordLengths(available) - anchorLength) <= 2);
end
if numel(candidates) < numberToChoose
    candidates = available;
end
candidates = candidates(randperm(numel(candidates)));
chosenIndices = candidates(1:numberToChoose);
usedWords(chosenIndices) = true;
end
