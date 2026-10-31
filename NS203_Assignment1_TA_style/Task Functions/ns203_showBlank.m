function ns203_showBlank(window, backgroundColor)
% Displays a blank background with one screen flip.
Screen('FillRect', window, backgroundColor);
Screen('Flip', window);
end
