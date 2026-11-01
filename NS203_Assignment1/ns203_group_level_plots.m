%% NS203 Assignment 1: Group-level plots
% This script reads the already-computed group summary and consolidated raw data.
% It does not modify raw data or recalculate participant-level d-prime/bias metrics.
% ROC coordinates are calculated separately for each participant and then averaged.

clear;
clc;
close all;

fprintf('NS203 group-level plotting script started.\n');
fprintf('Select the folder containing group_summary_by_set_size.csv.\n');

metricsFolder = uigetdir(pwd, 'Select the Group_Level_Analysis metrics folder');

if isequal(metricsFolder, 0)
    fprintf('No folder selected. Plotting cancelled.\n');
    return;
end

summaryFile = fullfile(metricsFolder, 'group_summary_by_set_size.csv');
participantMetricsFile = fullfile(metricsFolder, 'participant_metrics_by_set_size.csv');
rawDataFile = fullfile(metricsFolder, 'all_participants_raw_data.csv');

% In the current folder structure, the consolidated raw CSV is one level above
% the nested metrics output folder. Check that location if needed.
if ~isfile(rawDataFile)
    parentFolder = fileparts(metricsFolder);
    rawDataFile = fullfile(parentFolder, 'all_participants_raw_data.csv');
end

if ~isfile(summaryFile)
    error('Could not find group_summary_by_set_size.csv at this path: %s', summaryFile);
end

if ~isfile(participantMetricsFile)
    error('Could not find participant_metrics_by_set_size.csv at this path: %s', participantMetricsFile);
end

if ~isfile(rawDataFile)
    error('Could not find all_participants_raw_data.csv in the selected folder or its parent folder.');
end

fprintf('[1/6] Loading group summary, participant metrics, and raw responses...\n');
groupSummary = readtable(summaryFile);
participantMetrics = readtable(participantMetricsFile);
trialData = readtable(rawDataFile);

requiredSummary = {'setSize','dPrime_mean','dPrime_SD','bias_c_mean','bias_c_SD', ...
    'accuracy_mean','accuracy_SD','meanRT_seconds_mean','meanRT_seconds_SD'};
missingSummary = setdiff(requiredSummary, groupSummary.Properties.VariableNames);

if ~isempty(missingSummary)
    error('Group summary is missing required columns: %s', strjoin(missingSummary, ', '));
end

requiredParticipant = {'participantID','setSize'};
missingParticipant = setdiff(requiredParticipant, participantMetrics.Properties.VariableNames);

if ~isempty(missingParticipant)
    error('Participant metrics file is missing required columns: %s', strjoin(missingParticipant, ', '));
end

requiredRaw = {'participantID','setSize','isOld','confidence','completed'};
missingRaw = setdiff(requiredRaw, trialData.Properties.VariableNames);

if ~isempty(missingRaw)
    error('Consolidated raw data is missing required columns: %s', strjoin(missingRaw, ', '));
end

setSizes = sort(unique(groupSummary.setSize(:)))';
if ~isequal(setSizes, [4 6 8])
    warning('Expected set sizes [4 6 8], but found: %s', mat2str(setSizes));
end

participantIDs = unique(participantMetrics.participantID);
participantIDs = sort(participantIDs(:))';

fprintf('      Loaded %d participants and set sizes %s.\n', numel(participantIDs), mat2str(setSizes));

%% Common plot formatting
fontName = 'Arial';
fontSize = 12;
lineWidth = 1.8;
markerSize = 7;

%% 1. Psychophysical function: d-prime by set size
fprintf('[2/6] Creating group d-prime plot...\n');
fig1 = figure('Color', 'w', 'InvertHardcopy', 'off', 'Position', [100 100 760 560]);
errorbar(groupSummary.setSize, groupSummary.dPrime_mean, groupSummary.dPrime_SD, ...
    '-o', 'LineWidth', lineWidth, 'MarkerSize', markerSize, 'CapSize', 10);
hold on;
ax = gca;
set(ax, 'Color', 'w', 'FontName', fontName, 'FontSize', fontSize, 'LineWidth', 1.1, ...
    'XTick', setSizes, 'XColor', 'k', 'YColor', 'k', 'Box', 'on');
xlabel('Study-list set size', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');
ylabel('Sensitivity (d'')', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');
title('Group sensitivity by set size', 'FontName', fontName, 'FontSize', 14, ...
    'FontWeight', 'bold', 'Color', 'k');
grid on;
ax.GridColor = [0.82 0.82 0.82];
ax.GridAlpha = 0.35;
exportgraphics(fig1, fullfile(metricsFolder, 'group_dPrime_by_set_size.png'), ...
    'Resolution', 300, 'BackgroundColor', 'white');

%% 2. Response bias by set size
fprintf('[3/6] Creating group response-bias plot...\n');
fig2 = figure('Color', 'w', 'InvertHardcopy', 'off', 'Position', [100 100 760 560]);
errorbar(groupSummary.setSize, groupSummary.bias_c_mean, groupSummary.bias_c_SD, ...
    '-o', 'LineWidth', lineWidth, 'MarkerSize', markerSize, 'CapSize', 10);
hold on;
yline(0, '--k', 'LineWidth', 1.2, 'HandleVisibility', 'off');
ax = gca;
set(ax, 'Color', 'w', 'FontName', fontName, 'FontSize', fontSize, 'LineWidth', 1.1, ...
    'XTick', setSizes, 'XColor', 'k', 'YColor', 'k', 'Box', 'on');
xlabel('Study-list set size', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');
ylabel('Response criterion (c)', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');
title('Group response bias by set size', 'FontName', fontName, 'FontSize', 14, ...
    'FontWeight', 'bold', 'Color', 'k');
grid on;
ax.GridColor = [0.82 0.82 0.82];
ax.GridAlpha = 0.35;
exportgraphics(fig2, fullfile(metricsFolder, 'group_bias_by_set_size.png'), ...
    'Resolution', 300, 'BackgroundColor', 'white');

%% 3. Group ROC curves
fprintf('[4/6] Calculating participant ROC coordinates and creating group ROC plot...\n');
thresholds = [5 4 3 2 1];
numThresholds = numel(thresholds);
numParticipants = numel(participantIDs);
numSetSizes = numel(setSizes);

meanHit = nan(numSetSizes, numThresholds);
meanFA = nan(numSetSizes, numThresholds);
sdHit = nan(numSetSizes, numThresholds);
sdFA = nan(numSetSizes, numThresholds);
individualHit = nan(numParticipants, numSetSizes, numThresholds);
individualFA = nan(numParticipants, numSetSizes, numThresholds);

for setIndex = 1:numSetSizes
    thisSetSize = setSizes(setIndex);

    for participantIndex = 1:numParticipants
        thisParticipant = participantIDs(participantIndex);
        participantMask = trialData.participantID == thisParticipant;
        validMask = participantMask & trialData.setSize == thisSetSize & ...
            trialData.completed & isfinite(trialData.confidence);
        oldMask = validMask & trialData.isOld == 1;
        newMask = validMask & trialData.isOld == 0;
        nOld = sum(oldMask);
        nNew = sum(newMask);

        if nOld == 0 || nNew == 0
            warning('Participant %g has no old or new probes at set size %g. ROC omitted.', ...
                thisParticipant, thisSetSize);
            continue;
        end

        for thresholdIndex = 1:numThresholds
            threshold = thresholds(thresholdIndex);
            individualHit(participantIndex, setIndex, thresholdIndex) = ...
                sum(trialData.confidence(oldMask) >= threshold) / nOld;
            individualFA(participantIndex, setIndex, thresholdIndex) = ...
                sum(trialData.confidence(newMask) >= threshold) / nNew;
        end
    end

    for thresholdIndex = 1:numThresholds
        hitValues = individualHit(:, setIndex, thresholdIndex);
        faValues = individualFA(:, setIndex, thresholdIndex);
        meanHit(setIndex, thresholdIndex) = mean(hitValues, 'omitnan');
        meanFA(setIndex, thresholdIndex) = mean(faValues, 'omitnan');
        sdHit(setIndex, thresholdIndex) = std(hitValues, 0, 'omitnan');
        sdFA(setIndex, thresholdIndex) = std(faValues, 0, 'omitnan');
    end
end

% Plot only group-mean curves. The companion zoomed panel makes the
% upper-left ROC region readable without overlaying five individual curves.
fig3 = figure('Color', 'w', 'InvertHardcopy', 'off', 'Position', [100 100 1120 520]);
colors = lines(numSetSizes);
markers = {'o', 's', '^'};

axROC1 = subplot(1, 2, 1);
hold(axROC1, 'on');
plot(axROC1, [0 1], [0 1], '--k', 'LineWidth', 1.2, 'DisplayName', 'Chance');
for setIndex = 1:numSetSizes
    plot(axROC1, meanFA(setIndex, :), meanHit(setIndex, :), ...
        '-', 'Color', colors(setIndex, :), 'Marker', markers{setIndex}, ...
        'LineWidth', 2.2, 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(setIndex, :), ...
        'DisplayName', sprintf('Set size %d', setSizes(setIndex)));
end
set(axROC1, 'Color', 'w', 'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1.1, 'XColor', 'k', 'YColor', 'k', 'Box', 'on');
xlim(axROC1, [0 1]);
ylim(axROC1, [0 1]);
xticks(axROC1, 0:0.2:1);
yticks(axROC1, 0:0.2:1);
xlabel(axROC1, 'False-alarm rate', 'Color', 'k');
ylabel(axROC1, 'Hit rate', 'Color', 'k');
title(axROC1, 'Full ROC space', 'Color', 'k', 'FontWeight', 'bold');
axis(axROC1, 'square');
grid(axROC1, 'on');
axROC1.GridColor = [0.82 0.82 0.82];
axROC1.GridAlpha = 0.35;
legend(axROC1, 'Location', 'southeast', 'Color', 'w', 'TextColor', 'k');

axROC2 = subplot(1, 2, 2);
hold(axROC2, 'on');
for setIndex = 1:numSetSizes
    plot(axROC2, meanFA(setIndex, :), meanHit(setIndex, :), ...
        '-', 'Color', colors(setIndex, :), 'Marker', markers{setIndex}, ...
        'LineWidth', 2.2, 'MarkerSize', 8, ...
        'MarkerFaceColor', colors(setIndex, :), ...
        'DisplayName', sprintf('Set size %d', setSizes(setIndex)));
end
set(axROC2, 'Color', 'w', 'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1.1, 'XColor', 'k', 'YColor', 'k', 'Box', 'on');
xlim(axROC2, [0 0.20]);
ylim(axROC2, [0.75 1.01]);
xticks(axROC2, 0:0.05:0.20);
yticks(axROC2, 0.75:0.05:1.00);
xlabel(axROC2, 'False-alarm rate', 'Color', 'k');
ylabel(axROC2, 'Hit rate', 'Color', 'k');
title(axROC2, 'Upper-left region (zoomed)', 'Color', 'k', 'FontWeight', 'bold');
grid(axROC2, 'on');
axROC2.GridColor = [0.82 0.82 0.82];
axROC2.GridAlpha = 0.35;
sgtitle(fig3, 'Group ROC curves from confidence ratings', ...
    'FontName', fontName, 'FontSize', 15, 'FontWeight', 'bold', 'Color', 'k');
exportgraphics(fig3, fullfile(metricsFolder, 'group_roc_curves.png'), ...
    'Resolution', 300, 'BackgroundColor', 'white');

% Save the group-mean ROC coordinates and participant-level coordinates.
rocRows = [];
for setIndex = 1:numSetSizes
    for thresholdIndex = 1:numThresholds
        rocRows = [rocRows; setSizes(setIndex), thresholds(thresholdIndex), ...
            meanFA(setIndex, thresholdIndex), meanHit(setIndex, thresholdIndex), ...
            sdFA(setIndex, thresholdIndex), sdHit(setIndex, thresholdIndex)]; %#ok<AGROW>
    end
end

groupROC = array2table(rocRows, 'VariableNames', ...
    {'setSize','oldResponseThreshold','meanFalseAlarmRate','meanHitRate', ...
    'sdFalseAlarmRate','sdHitRate'});
writetable(groupROC, fullfile(metricsFolder, 'group_mean_roc_points.csv'));

%% 4. Accuracy and response time by set size
fprintf('[5/6] Creating group accuracy and response-time plot...\n');
fig4 = figure('Color', 'w', 'InvertHardcopy', 'off', 'Position', [100 100 820 560]);

yyaxis left;
errorbar(groupSummary.setSize, groupSummary.accuracy_mean, groupSummary.accuracy_SD, ...
    '-o', 'LineWidth', lineWidth, 'MarkerSize', markerSize, 'CapSize', 10);
ylabel('Accuracy', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');
ylim([0 1.05]);

yyaxis right;
errorbar(groupSummary.setSize, groupSummary.meanRT_seconds_mean, ...
    groupSummary.meanRT_seconds_SD, '-s', 'LineWidth', lineWidth, ...
    'MarkerSize', markerSize, 'CapSize', 10);
ylabel('Mean response time (s)', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');

ax = gca;
set(ax, 'Color', 'w', 'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1.1, 'XTick', setSizes, 'XColor', 'k', 'Box', 'on');
ax.YAxis(1).Color = 'k';
ax.YAxis(2).Color = 'k';
xlabel('Study-list set size', 'FontName', fontName, 'FontSize', fontSize, 'Color', 'k');
title('Group accuracy and response time by set size', 'FontName', fontName, ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', 'k');
legend({'Accuracy', 'Mean response time'}, 'Location', 'best', ...
    'Color', 'w', 'TextColor', 'k');
grid on;
ax.GridColor = [0.82 0.82 0.82];
ax.GridAlpha = 0.35;
exportgraphics(fig4, fullfile(metricsFolder, 'group_accuracy_and_RT_by_set_size.png'), ...
    'Resolution', 300, 'BackgroundColor', 'white');

%% Finish
fprintf('[6/6] Saving complete.\n');
fprintf('Group plots and group_mean_roc_points.csv saved in:\n%s\n', metricsFolder);
fprintf('Created files:\n');
fprintf('  group_dPrime_by_set_size.png\n');
fprintf('  group_bias_by_set_size.png\n');
fprintf('  group_roc_curves.png\n');
fprintf('  group_accuracy_and_RT_by_set_size.png\n');
fprintf('  group_mean_roc_points.csv\n');
fprintf('\nNote: error bars on d-prime, bias, accuracy, and RT show between-participant sample SD.\n');
fprintf('The ROC figure shows the mean participant-level ROC coordinates at each confidence threshold.\n');
fprintf('Only group-mean ROC curves are plotted; raw responses are not pooled.\n');
