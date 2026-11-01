%% NS203 Assignment 1: Plot saved offline-analysis results
% This script reads existing analysis CSVs only.
% It does not rerun the experiment or recalculate participant responses.
% Figures are formatted for inclusion in a LaTeX report.

clear;
clc;
close all;

fprintf('NS203 plotting script started.\n');
fprintf('Select the analysis folder containing summary_by_set_size.csv and roc_points.csv.\n');

analysisFolder = uigetdir(pwd, 'Select the Analysis_* folder');

if isequal(analysisFolder, 0)
    fprintf('No folder selected. Plotting cancelled.\n');
    return;
end

summaryFile = fullfile(analysisFolder, 'summary_by_set_size.csv');
rocFile = fullfile(analysisFolder, 'roc_points.csv');

if ~isfile(summaryFile)
    error('Could not find summary_by_set_size.csv in the selected folder.');
end

if ~isfile(rocFile)
    error('Could not find roc_points.csv in the selected folder.');
end

fprintf('[1/5] Loading saved summary tables...\n');
summaryTable = readtable(summaryFile);
rocTable = readtable(rocFile);
fprintf('      Loaded summary and ROC points.\n');

% Consistent report-ready figure formatting.
fontName = 'Arial';
fontSize = 12;
titleSize = 14;
lineWidth = 2;
markerSize = 8;
figurePosition = [100 100 900 650];

fprintf('[2/5] Creating d-prime plot...\n');
fig1 = figure('Color', 'w', 'Units', 'pixels', 'Position', figurePosition);
ax1 = axes(fig1);
plot(ax1, summaryTable.setSize, summaryTable.dPrime, '-o', ...
    'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
    'MarkerFaceColor', [0.12 0.47 0.71]);
xlabel(ax1, 'Study-list set size', 'Color', 'k');
ylabel(ax1, 'Sensitivity (d-prime)', 'Color', 'k');
title(ax1, 'Recognition sensitivity by set size', 'Color', 'k', 'FontWeight', 'bold');
grid(ax1, 'on');
box(ax1, 'on');
set(ax1, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1, 'GridAlpha', 0.18);
ax1.Title.FontSize = titleSize;
xlim(ax1, [min(summaryTable.setSize) - 0.5, max(summaryTable.setSize) + 0.5]);
exportgraphics(fig1, fullfile(analysisFolder, 'dPrime_by_set_size.png'), 'Resolution', 300);
fprintf('      Saved dPrime_by_set_size.png\n');

fprintf('[3/5] Creating response-bias plot...\n');
fig2 = figure('Color', 'w', 'Units', 'pixels', 'Position', figurePosition);
ax2 = axes(fig2);
hold(ax2, 'on');
plot(ax2, summaryTable.setSize, summaryTable.bias_b, '-o', ...
    'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
    'MarkerFaceColor', [0.12 0.47 0.71]);
yline(ax2, 0, '--', 'LineWidth', 1.3, 'Color', [0.35 0.35 0.35]);
xlabel(ax2, 'Study-list set size', 'Color', 'k');
ylabel(ax2, 'Response criterion (c)', 'Color', 'k');
title(ax2, 'Response bias by set size', 'Color', 'k', 'FontWeight', 'bold');
grid(ax2, 'on');
box(ax2, 'on');
set(ax2, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1, 'GridAlpha', 0.18);
ax2.Title.FontSize = titleSize;
xlim(ax2, [min(summaryTable.setSize) - 0.5, max(summaryTable.setSize) + 0.5]);
exportgraphics(fig2, fullfile(analysisFolder, 'bias_by_set_size.png'), 'Resolution', 300);
fprintf('      Saved bias_by_set_size.png\n');

fprintf('[4/5] Creating ROC curves...\n');
fig3 = figure('Color', 'w', 'Units', 'pixels', 'Position', figurePosition);
ax3 = axes(fig3);
hold(ax3, 'on');
plot(ax3, [0 1], [0 1], '--', 'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.3, 'DisplayName', 'Chance');

setSizes = sort(unique(rocTable.setSize(:)))';
curveColors = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.49 0.18 0.56];

for setIndex = 1:numel(setSizes)
    thisSetSize = setSizes(setIndex);
    thisROC = rocTable(rocTable.setSize == thisSetSize, :);
    [sortedFA, sortIndex] = sort(thisROC.falseAlarmRate);
    sortedHit = thisROC.hitRate(sortIndex);
    colorIndex = mod(setIndex - 1, size(curveColors, 1)) + 1;
    plot(ax3, sortedFA, sortedHit, '-o', ...
        'Color', curveColors(colorIndex, :), ...
        'MarkerFaceColor', curveColors(colorIndex, :), ...
        'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
        'DisplayName', sprintf('Set size %d', thisSetSize));
end

xlabel(ax3, 'False-alarm rate', 'Color', 'k');
ylabel(ax3, 'Hit rate', 'Color', 'k');
title(ax3, 'ROC curves from confidence ratings', 'Color', 'k', 'FontWeight', 'bold');
legend(ax3, 'Location', 'southeast');
axis(ax3, 'square');
xlim(ax3, [0 1]);
ylim(ax3, [0 1]);
grid(ax3, 'on');
box(ax3, 'on');
set(ax3, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1, 'GridAlpha', 0.18);
ax3.Title.FontSize = titleSize;
set(legend(ax3), 'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.3 0.3 0.3]);
exportgraphics(fig3, fullfile(analysisFolder, 'roc_curves.png'), 'Resolution', 300);
fprintf('      Saved roc_curves.png\n');

fprintf('[5/5] Creating accuracy and reaction-time plot...\n');
fig4 = figure('Color', 'w', 'Units', 'pixels', 'Position', figurePosition);
ax4 = axes(fig4);

yyaxis(ax4, 'left');
plot(ax4, summaryTable.setSize, summaryTable.accuracy, '-o', ...
    'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
    'MarkerFaceColor', [0.12 0.47 0.71]);
ylabel(ax4, 'Accuracy', 'Color', [0.12 0.47 0.71]);
ylim(ax4, [0 1]);

yyaxis(ax4, 'right');
plot(ax4, summaryTable.setSize, summaryTable.meanRT_seconds, '-s', ...
    'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
    'MarkerFaceColor', [0.85 0.33 0.10]);
ylabel(ax4, 'Mean reaction time (seconds)', 'Color', [0.85 0.33 0.10]);

xlabel(ax4, 'Study-list set size', 'Color', 'k');
title(ax4, 'Accuracy and reaction time by set size', 'Color', 'k', 'FontWeight', 'bold');
grid(ax4, 'on');
box(ax4, 'on');
xlim(ax4, [min(summaryTable.setSize) - 0.5, max(summaryTable.setSize) + 0.5]);
set(ax4, 'Color', 'w', 'XColor', 'k', 'FontName', fontName, 'FontSize', fontSize, ...
    'LineWidth', 1, 'GridAlpha', 0.18, 'Box', 'on');
ax4.YAxis(1).Color = [0.12 0.47 0.71];
ax4.YAxis(2).Color = [0.85 0.33 0.10];
ax4.XColor = 'k';
ax4.Title.Color = 'k';
ax4.Title.FontSize = titleSize;
exportgraphics(fig4, fullfile(analysisFolder, 'accuracy_and_reaction_time.png'), 'Resolution', 300);
fprintf('      Saved accuracy_and_reaction_time.png\n');

fprintf('\nPlotting completed. Files saved in:\n%s\n', analysisFolder);
