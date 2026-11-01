%% NS203 group-level metric calculations
% Uses the consolidated raw probe-level CSV.
% Participant-level metrics are calculated first; group summaries use
% the mean and SAMPLE standard deviation (N-1) across participants.
% Missing responses are excluded, not scored as incorrect.

clear;
clc;

fprintf('NS203 group-level metric calculation started.\n\n');

%% Select consolidated data
[dataFile, dataFolder] = uigetfile( ...
    '*.csv', ...
    'Select all_participants_raw_data.csv');

if isequal(dataFile, 0)
    fprintf('No file selected. Group analysis cancelled.\n');
    return;
end

inputPath = fullfile(dataFolder, dataFile);
fprintf('Reading: %s\n', inputPath);

T = readtable(inputPath);

requiredVariables = {'participantID','session','setSize','isOld', ...
    'confidence','responseOld','correct','RT','completed'};

missingVariables = setdiff(requiredVariables, T.Properties.VariableNames);

if ~isempty(missingVariables)
    error('Missing required columns: %s', strjoin(missingVariables, ', '));
end

%% Validate participants and rows
expectedParticipants = [203 205 207 210 211];
participantIDs = unique(T.participantID(:))';

if ~isequal(sort(participantIDs), expectedParticipants)
    error('Unexpected participant IDs. Found: %s', mat2str(sort(participantIDs)));
end

if height(T) ~= 1200
    error('Expected 1200 raw rows, but found %d.', height(T));
end

setSizes = [4 6 8];

if ~all(ismember(setSizes, unique(T.setSize)))
    error('One or more expected set sizes (4, 6, 8) are missing.');
end

if any(~ismember(T.isOld(~isnan(T.isOld)), [0 1]))
    error('isOld must contain only 0 and 1.');
end

if any(~ismember(T.confidence(~isnan(T.confidence)), 1:4))
    error('Confidence ratings must be integers from 1 to 4.');
end

fprintf('Validated %d rows from participants %s.\n', ...
    height(T), mat2str(expectedParticipants));

%% Define valid responses
validResponse = T.completed == 1 & ...
    isfinite(T.confidence) & ...
    isfinite(T.responseOld);

fprintf('Total raw rows: %d\n', height(T));
fprintf('Valid responses: %d\n', sum(validResponse));
fprintf('Missing/invalid responses: %d\n\n', sum(~validResponse));

%% Calculate participant-level metrics by set size
nParticipants = numel(expectedParticipants);
nSetSizes = numel(setSizes);

nRows = nParticipants * nSetSizes;

participantIDColumn = zeros(nRows, 1);
sessionColumn = zeros(nRows, 1);
setSizeColumn = zeros(nRows, 1);
nValidColumn = zeros(nRows, 1);
nOldColumn = zeros(nRows, 1);
nNewColumn = zeros(nRows, 1);
hitsColumn = zeros(nRows, 1);
missesColumn = zeros(nRows, 1);
falseAlarmsColumn = zeros(nRows, 1);
correctRejectionsColumn = zeros(nRows, 1);
hitRateColumn = nan(nRows, 1);
falseAlarmRateColumn = nan(nRows, 1);
dPrimeColumn = nan(nRows, 1);
biasColumn = nan(nRows, 1);
accuracyColumn = nan(nRows, 1);
meanRTColumn = nan(nRows, 1);
medianRTColumn = nan(nRows, 1);
rocAUCColumn = nan(nRows, 1);

rowIndex = 0;

for participantIndex = 1:nParticipants
    participantID = expectedParticipants(participantIndex);
    participantMask = T.participantID == participantID;

    participantSessions = unique(T.session(participantMask));
    if numel(participantSessions) ~= 1
        error('Participant %d has inconsistent session values.', participantID);
    end

    for setIndex = 1:nSetSizes
        thisSetSize = setSizes(setIndex);
        rowIndex = rowIndex + 1;

        responseMask = participantMask & ...
            T.setSize == thisSetSize & validResponse;

        oldMask = responseMask & T.isOld == 1;
        newMask = responseMask & T.isOld == 0;

        nOld = sum(oldMask);
        nNew = sum(newMask);
        nHits = sum(T.responseOld(oldMask) == 1);
        nMisses = sum(T.responseOld(oldMask) == 0);
        nFalseAlarms = sum(T.responseOld(newMask) == 1);
        nCorrectRejections = sum(T.responseOld(newMask) == 0);

        hitRate = NaN;
        falseAlarmRate = NaN;
        dPrime = NaN;
        bias = NaN;

        if nOld > 0 && nNew > 0
            hitRate = (nHits + 0.5) / (nOld + 1);
            falseAlarmRate = (nFalseAlarms + 0.5) / (nNew + 1);

            zHit = ns203_norminv_local(hitRate);
            zFA = ns203_norminv_local(falseAlarmRate);

            dPrime = zHit - zFA;
            bias = -(zHit + zFA) / 2;
        end

        accuracy = mean(T.correct(responseMask), 'omitnan');
        meanRT = mean(T.RT(responseMask), 'omitnan');
        medianRT = median(T.RT(responseMask), 'omitnan');

        % ROC AUC from confidence ratings:
        % 1 = definitely NEW; 2 = probably NEW;
        % 3 = probably OLD; 4 = definitely OLD.
        thresholds = [5 4 3 2 1];
        rocHit = nan(size(thresholds));
        rocFA = nan(size(thresholds));

        if nOld > 0 && nNew > 0
            for thresholdIndex = 1:numel(thresholds)
                threshold = thresholds(thresholdIndex);
                rocHit(thresholdIndex) = ...
                    sum(T.confidence(oldMask) >= threshold) / nOld;
                rocFA(thresholdIndex) = ...
                    sum(T.confidence(newMask) >= threshold) / nNew;
            end

            [sortedFA, sortIndex] = sort(rocFA);
            sortedHit = rocHit(sortIndex);
            rocAUC = trapz(sortedFA, sortedHit);
        else
            rocAUC = NaN;
        end

        participantIDColumn(rowIndex) = participantID;
        sessionColumn(rowIndex) = participantSessions(1);
        setSizeColumn(rowIndex) = thisSetSize;
        nValidColumn(rowIndex) = sum(responseMask);
        nOldColumn(rowIndex) = nOld;
        nNewColumn(rowIndex) = nNew;
        hitsColumn(rowIndex) = nHits;
        missesColumn(rowIndex) = nMisses;
        falseAlarmsColumn(rowIndex) = nFalseAlarms;
        correctRejectionsColumn(rowIndex) = nCorrectRejections;
        hitRateColumn(rowIndex) = hitRate;
        falseAlarmRateColumn(rowIndex) = falseAlarmRate;
        dPrimeColumn(rowIndex) = dPrime;
        biasColumn(rowIndex) = bias;
        accuracyColumn(rowIndex) = accuracy;
        meanRTColumn(rowIndex) = meanRT;
        medianRTColumn(rowIndex) = medianRT;
        rocAUCColumn(rowIndex) = rocAUC;
    end
end

participantMetrics = table( ...
    participantIDColumn, sessionColumn, setSizeColumn, nValidColumn, ...
    nOldColumn, nNewColumn, hitsColumn, missesColumn, ...
    falseAlarmsColumn, correctRejectionsColumn, hitRateColumn, ...
    falseAlarmRateColumn, dPrimeColumn, biasColumn, accuracyColumn, ...
    meanRTColumn, medianRTColumn, rocAUCColumn, ...
    'VariableNames', {'participantID','session','setSize','nValidResponses', ...
    'nOldProbes','nNewProbes','hits','misses','falseAlarms', ...
    'correctRejections','hitRate','falseAlarmRate','dPrime','bias_c', ...
    'accuracy','meanRT_seconds','medianRT_seconds','rocAUC'});

%% Group summaries by set size: mean and sample SD across participants
metricNames = {'nValidResponses','hitRate','falseAlarmRate','dPrime', ...
    'bias_c','accuracy','meanRT_seconds','medianRT_seconds','rocAUC'};

summaryRows = cell(nSetSizes, 1);

for setIndex = 1:nSetSizes
    thisSetSize = setSizes(setIndex);
    setMask = participantMetrics.setSize == thisSetSize;

    row = table(thisSetSize, ...
        'VariableNames', {'setSize'});

    for metricIndex = 1:numel(metricNames)
        metricName = metricNames{metricIndex};
        values = participantMetrics.(metricName)(setMask);

        validValues = values(isfinite(values));
        nValid = numel(validValues);

        if nValid > 0
            metricMean = mean(validValues);
        else
            metricMean = NaN;
        end

        if nValid >= 2
            metricSD = std(validValues, 0);
        else
            metricSD = NaN;
        end

        row.([metricName '_N']) = nValid;
        row.([metricName '_mean']) = metricMean;
        row.([metricName '_SD']) = metricSD;
    end

    summaryRows{setIndex} = row;
end

groupSummary = vertcat(summaryRows{:});

%% Calculate participant-level overall metrics across all set sizes
overallRows = cell(nParticipants, 1);

for participantIndex = 1:nParticipants
    participantID = expectedParticipants(participantIndex);
    participantMask = T.participantID == participantID;
    responseMask = participantMask & validResponse;

    oldMask = responseMask & T.isOld == 1;
    newMask = responseMask & T.isOld == 0;

    nOld = sum(oldMask);
    nNew = sum(newMask);
    nHits = sum(T.responseOld(oldMask) == 1);
    nFalseAlarms = sum(T.responseOld(newMask) == 1);

    hitRate = (nHits + 0.5) / (nOld + 1);
    falseAlarmRate = (nFalseAlarms + 0.5) / (nNew + 1);

    zHit = ns203_norminv_local(hitRate);
    zFA = ns203_norminv_local(falseAlarmRate);

    dPrime = zHit - zFA;
    bias = -(zHit + zFA) / 2;
    accuracy = mean(T.correct(responseMask), 'omitnan');
    meanRT = mean(T.RT(responseMask), 'omitnan');
    medianRT = median(T.RT(responseMask), 'omitnan');

    sessionValue = unique(T.session(participantMask));

    overallRows{participantIndex} = table( ...
        participantID, sessionValue(1), sum(responseMask), ...
        nOld, nNew, nHits, nFalseAlarms, hitRate, falseAlarmRate, ...
        dPrime, bias, accuracy, meanRT, medianRT, ...
        'VariableNames', {'participantID','session','nValidResponses', ...
        'nOldProbes','nNewProbes','hits','falseAlarms','hitRate', ...
        'falseAlarmRate','dPrime','bias_c','accuracy', ...
        'meanRT_seconds','medianRT_seconds'});
end

participantOverall = vertcat(overallRows{:});

%% Group overall summary
overallMetricNames = {'nValidResponses','hitRate','falseAlarmRate', ...
    'dPrime','bias_c','accuracy','meanRT_seconds','medianRT_seconds'};

groupOverall = table();

for metricIndex = 1:numel(overallMetricNames)
    metricName = overallMetricNames{metricIndex};
    values = participantOverall.(metricName);
    validValues = values(isfinite(values));

    groupOverall.([metricName '_N']) = numel(validValues);
    groupOverall.([metricName '_mean']) = mean(validValues, 'omitnan');

    if numel(validValues) >= 2
        groupOverall.([metricName '_SD']) = std(validValues, 0);
    else
        groupOverall.([metricName '_SD']) = NaN;
    end
end

%% Save outputs
outputFolder = fullfile(dataFolder, 'Group_Level_Analysis');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

writetable(participantMetrics, ...
    fullfile(outputFolder, 'participant_metrics_by_set_size.csv'));

writetable(groupSummary, ...
    fullfile(outputFolder, 'group_summary_by_set_size.csv'));

writetable(participantOverall, ...
    fullfile(outputFolder, 'participant_overall_metrics.csv'));

writetable(groupOverall, ...
    fullfile(outputFolder, 'group_overall_summary.csv'));

save(fullfile(outputFolder, 'group_level_metrics.mat'), ...
    'participantMetrics','groupSummary','participantOverall','groupOverall', ...
    'expectedParticipants','setSizes','inputPath');

%% Display results
fprintf('\nParticipant-level metrics by set size:\n');
disp(participantMetrics);

fprintf('\nGroup summary by set size (mean and sample SD):\n');
disp(groupSummary);

fprintf('\nParticipant-level overall metrics:\n');
disp(participantOverall);

fprintf('\nGroup overall summary (mean and sample SD):\n');
disp(groupOverall);

fprintf('\nGroup-level calculations completed successfully.\n');
fprintf('Output folder: %s\n', outputFolder);

%% Local helper: inverse standard normal CDF without Statistics Toolbox
function z = ns203_norminv_local(p)

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
