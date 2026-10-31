%% NS 203 Assignment 1: Offline analysis of word-recognition task
% This script analyzes previously collected data only.
% It does NOT run the experiment or modify the original raw data files.

clear;
clc;
close all;
fprintf('NS203 offline analysis started.\n');
fprintf('[1/7] Waiting for you to select the final trial-data CSV...\n');

%% Select a completed session's raw CSV file
[fileName, dataFolder] = uigetfile( ...
    '*.csv', ...
    'Select the final trial-data CSV file');

if isequal(fileName, 0)
    fprintf('No file selected. Analysis cancelled.\n');
    return;
end

inputFile = fullfile(dataFolder, fileName);
fprintf('[2/7] Reading CSV: %s\n', inputFile);
drawnow;
trialData = readtable(inputFile);
fprintf('      CSV loaded successfully (%d rows, %d columns).\n', height(trialData), width(trialData));
drawnow;

%% Check required columns
requiredVariables = {'participantID','session','block','trialNum','setSize', ...
    'probeNumber','probeWord','isOld','confidence','responseOld','correct','RT','completed'};

missingVariables = setdiff(requiredVariables, trialData.Properties.VariableNames);

if ~isempty(missingVariables)
    error('The selected CSV is missing required columns: %s', strjoin(missingVariables, ', '));
end

%% Create a separate analysis output folder
[~, baseName, ~] = fileparts(fileName);
analysisFolder = fullfile(dataFolder, ['Analysis_' baseName]);

if ~exist(analysisFolder, 'dir')
    mkdir(analysisFolder);
end
fprintf('[3/7] Output folder ready: %s\n', analysisFolder);
drawnow;

%% Basic data validation
fprintf('[4/7] Validating row counts, trials, and responses...\n');
drawnow;
nRows = height(trialData);
nTrials = numel(unique(trialData.trialNum));
nCompleted = sum(trialData.completed);
validResponse = trialData.completed & ~isnan(trialData.confidence);
nValidResponses = sum(validResponse);
nMissingResponses = sum(trialData.completed & isnan(trialData.confidence));

fprintf('\nSelected data file: %s\n', inputFile);
fprintf('Rows in file: %d\n', nRows);
fprintf('Unique main-task trials: %d\n', nTrials);
fprintf('Completed probe rows: %d\n', nCompleted);
fprintf('Rows with a valid confidence response: %d\n', nValidResponses);
fprintf('Completed rows with no recorded response: %d\n', nMissingResponses);

if nRows ~= 240
    warning('Expected 240 main-task probe rows, but found %d.', nRows);
end

if nTrials ~= 60
    warning('Expected 60 main-task trials, but found %d.', nTrials);
end

if any(~ismember(trialData.isOld, [0 1]))
    warning('The isOld column contains values other than 0 and 1.');
end

if any(~ismember(trialData.confidence(isfinite(trialData.confidence)), 1:4))
    warning('Some confidence values are outside the expected range 1 to 4.');
end

fprintf('      Data validation finished.\n');
drawnow;

%% Overall probe-level summary
fprintf('[5/7] Calculating overall performance and signal-detection measures...\n');
drawnow;
oldMaskAll = validResponse & trialData.isOld == 1;
newMaskAll = validResponse & trialData.isOld == 0;

nOld = sum(oldMaskAll);
nNew = sum(newMaskAll);
nHits = sum(trialData.responseOld(oldMaskAll) == 1);
nFalseAlarms = sum(trialData.responseOld(newMaskAll) == 1);

hitRate = (nHits + 0.5) / (nOld + 1);
falseAlarmRate = (nFalseAlarms + 0.5) / (nNew + 1);
zHit = ns203_norminv_local(hitRate);
zFA = ns203_norminv_local(falseAlarmRate);
dPrime = zHit - zFA;
bias_b = -(zHit + zFA) / 2;

overallAccuracy = mean(trialData.correct(validResponse), 'omitnan');
overallMeanRT = mean(trialData.RT(validResponse), 'omitnan');
overallMedianRT = median(trialData.RT(validResponse), 'omitnan');

overallSummary = table(nRows, nTrials, nCompleted, nValidResponses, nMissingResponses, ...
    nOld, nNew, nHits, nFalseAlarms, hitRate, falseAlarmRate, dPrime, bias_b, ...
    overallAccuracy, overallMeanRT, overallMedianRT, ...
    'VariableNames', {'nProbeRows','nTrials','nCompletedRows','nValidResponses', ...
    'nMissingResponses','nOldProbes','nNewProbes','hits','falseAlarms','hitRate', ...
    'falseAlarmRate','dPrime','bias_b','accuracy','meanRT_seconds','medianRT_seconds'});

writetable(overallSummary, fullfile(analysisFolder, 'overall_summary.csv'));
fprintf('      Saved overall_summary.csv\n');
drawnow;

%% Summary and ROC data by study-list set size
fprintf('[6/7] Calculating results by set size and ROC/AUC...\n');
drawnow;
setSizes = sort(unique(trialData.setSize(:)))';
summaryRows = nan(numel(setSizes), 14);
rocRows = [];

for setIndex = 1:numel(setSizes)
    thisSetSize = setSizes(setIndex);
    fprintf('      Processing set size %g (%d of %d)...\n', thisSetSize, setIndex, numel(setSizes));
    drawnow;
    mask = validResponse & trialData.setSize == thisSetSize;
    oldMask = mask & trialData.isOld == 1;
    newMask = mask & trialData.isOld == 0;

    nOld = sum(oldMask);
    nNew = sum(newMask);
    nHits = sum(trialData.responseOld(oldMask) == 1);
    nFalseAlarms = sum(trialData.responseOld(newMask) == 1);

    hitRate = (nHits + 0.5) / (nOld + 1);
    falseAlarmRate = (nFalseAlarms + 0.5) / (nNew + 1);
    zHit = ns203_norminv_local(hitRate);
    zFA = ns203_norminv_local(falseAlarmRate);
    dPrime = zHit - zFA;
    bias_b = -(zHit + zFA) / 2;

    accuracy = mean(trialData.correct(mask), 'omitnan');
    meanRT = mean(trialData.RT(mask), 'omitnan');
    medianRT = median(trialData.RT(mask), 'omitnan');

    summaryRows(setIndex, 1:13) = [thisSetSize, sum(mask), nOld, nNew, nHits, nFalseAlarms, ...
        hitRate, falseAlarmRate, dPrime, bias_b, accuracy, meanRT, medianRT];

    % Confidence rating scale: 1 = definitely NEW; 2 = probably NEW;
    % 3 = probably OLD; 4 = definitely OLD.
    % A threshold of >= k counts ratings k through 4 as "old".
    thresholds = [5 4 3 2 1];
    rocHit = nan(size(thresholds));
    rocFA = nan(size(thresholds));

    for thresholdIndex = 1:numel(thresholds)
        threshold = thresholds(thresholdIndex);
        if nOld > 0
            rocHit(thresholdIndex) = sum(trialData.confidence(oldMask) >= threshold) / nOld;
        end
        if nNew > 0
            rocFA(thresholdIndex) = sum(trialData.confidence(newMask) >= threshold) / nNew;
        end
    end

    validROC = isfinite(rocHit) & isfinite(rocFA);
    [sortedFA, sortIndex] = sort(rocFA(validROC));
    sortedHit = rocHit(validROC);
    sortedHit = sortedHit(sortIndex);
    rocAUC = NaN;

    if numel(sortedFA) >= 2
        rocAUC = trapz(sortedFA, sortedHit);
    end

    summaryRows(setIndex, 14) = rocAUC;

    for thresholdIndex = 1:numel(thresholds)
        rocRows = [rocRows; thisSetSize, thresholds(thresholdIndex), ...
            rocFA(thresholdIndex), rocHit(thresholdIndex)]; %#ok<AGROW>
    end
end

summaryTable = array2table(summaryRows, 'VariableNames', ...
    {'setSize','nValidResponses','nOldProbes','nNewProbes','hits','falseAlarms', ...
    'hitRate','falseAlarmRate','dPrime','bias_b','accuracy','meanRT_seconds', ...
    'medianRT_seconds','rocAUC'});

writetable(summaryTable, fullfile(analysisFolder, 'summary_by_set_size.csv'));

rocTable = array2table(rocRows, 'VariableNames', ...
    {'setSize','oldResponseThreshold','falseAlarmRate','hitRate'});
writetable(rocTable, fullfile(analysisFolder, 'roc_points.csv'));
fprintf('      Saved summary_by_set_size.csv and roc_points.csv\n');
drawnow;

fprintf('      Set-size and ROC calculations finished.\n');
drawnow;

%% Confidence-rating counts by set size and actual probe type
fprintf('[7/7] Saving confidence counts, MAT results, and plots...\n');
drawnow;
ratingRows = [];

for setIndex = 1:numel(setSizes)
    thisSetSize = setSizes(setIndex);

    for actualType = 0:1
        for rating = 1:4
            count = sum(validResponse & trialData.setSize == thisSetSize & ...
                trialData.isOld == actualType & trialData.confidence == rating);
            ratingRows = [ratingRows; thisSetSize, actualType, rating, count]; %#ok<AGROW>
        end
    end
end

ratingTable = array2table(ratingRows, 'VariableNames', ...
    {'setSize','actualProbeIsOld','confidenceRating','count'});
writetable(ratingTable, fullfile(analysisFolder, 'confidence_rating_counts.csv'));
fprintf('      Saved confidence_rating_counts.csv\n');
drawnow;

%% Save a MATLAB analysis file (raw input remains unchanged)
fprintf('      Saving analysis_results.mat...\n');
drawnow;
save(fullfile(analysisFolder, 'analysis_results.mat'), ...
    'trialData', 'overallSummary', 'summaryTable', 'rocTable', 'ratingTable', 'inputFile');
fprintf('      Saved analysis_results.mat\n');
drawnow;

%% Plotting is intentionally omitted from this script.
% Run plotting separately after confirming the tables and MAT file are saved.
fprintf('      Plot generation skipped in this analysis-only run.\n');
drawnow;

%% Print results to the MATLAB Command Window
fprintf('      All analysis tables and MAT results saved.\n');
drawnow;

fprintf('\nOverall summary:\n');
disp(overallSummary);

fprintf('\nSummary by set size:\n');
disp(summaryTable);

fprintf('\nAnalysis complete. Outputs saved to:\n%s\n', analysisFolder);

%% Local helper: inverse standard normal CDF without requiring Statistics Toolbox
function z = ns203_norminv_local(p)
    % Acklam approximation for the inverse standard normal CDF.
    a = [-3.969683028665376e+01, 2.209460984245205e+02, ...
         -2.759285104469687e+02, 1.383577518672690e+02, ...
         -3.066479806614716e+01, 2.506628277459239e+00];
    b = [-5.447609879822406e+01, 1.615858368580409e+02, ...
         -1.556989798598866e+02, 6.680131188771972e+01, ...
         -1.328068155288572e+01];
    c = [-7.784894002430293e-03, -3.223964580411365e-01, ...
         -2.400758277161838e+00, -2.549732539343734e+00, ...
          4.374664141464968e+00, 2.938163982698783e+00];
    d = [7.784695709041462e-03, 3.224671290700398e-01, ...
         2.445134137142996e+00, 3.754408661907416e+00];

    p = min(max(p, eps), 1 - eps);
    z = zeros(size(p));
    low = p < 0.02425;
    high = p > 1 - 0.02425;
    middle = ~(low | high);

    if any(low)
        q = sqrt(-2 .* log(p(low)));
        z(low) = (((((c(1).*q + c(2)).*q + c(3)).*q + c(4)).*q + c(5)).*q + c(6)) ./ ...
            ((((d(1).*q + d(2)).*q + d(3)).*q + d(4)).*q + 1);
    end

    if any(high)
        q = sqrt(-2 .* log(1 - p(high)));
        z(high) = -(((((c(1).*q + c(2)).*q + c(3)).*q + c(4)).*q + c(5)).*q + c(6)) ./ ...
            ((((d(1).*q + d(2)).*q + d(3)).*q + d(4)).*q + 1);
    end

    if any(middle)
        q = p(middle) - 0.5;
        r = q .* q;
        z(middle) = (((((a(1).*r + a(2)).*r + a(3)).*r + a(4)).*r + a(5)).*r + a(6)) .* q ./ ...
            (((((b(1).*r + b(2)).*r + b(3)).*r + b(4)).*r + b(5)).*r + 1);
    end
end
