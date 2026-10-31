function ns203_drawTextMessage(window, backgroundColor, textColor, MessageString)
% Draw multiline text with explicit Screen('DrawText') coordinates.
% Long lines are wrapped to fit within the window.

if isstring(MessageString)
    MessageString = char(MessageString);
end

MessageString = strrep(MessageString, sprintf('\r\n'), sprintf('\n'));
MessageString = strrep(MessageString, sprintf('\r'), sprintf('\n'));
sourceLines = regexp(MessageString, sprintf('\n'), 'split');

Screen('FillRect', window, backgroundColor);
Screen('TextFont', window, 'Arial');
Screen('TextSize', window, 18);

windowRect = Screen('Rect', window);
windowWidth = windowRect(3) - windowRect(1);
windowHeight = windowRect(4) - windowRect(2);
maxTextWidth = windowWidth - 80;
lineHeight = 34;
displayLines = {};

for sourceIndex = 1:numel(sourceLines)
    currentLine = strtrim(sourceLines{sourceIndex});
    if isempty(currentLine)
        displayLines{end + 1} = '';
        continue;
    end

    words = regexp(currentLine, '\s+', 'split');
    wrappedLine = words{1};

    for wordIndex = 2:numel(words)
        candidateLine = [wrappedLine ' ' words{wordIndex}];
        candidateBounds = Screen('TextBounds', window, candidateLine);
        candidateWidth = candidateBounds(3) - candidateBounds(1);

        if candidateWidth <= maxTextWidth
            wrappedLine = candidateLine;
        else
            displayLines{end + 1} = wrappedLine;
            wrappedLine = words{wordIndex};
        end
    end

    displayLines{end + 1} = wrappedLine;
end

if isempty(displayLines)
    displayLines = {''};
end

if numel(displayLines) * lineHeight > windowHeight - 40
    lineHeight = max(22, floor((windowHeight - 40) / numel(displayLines)));
end

totalTextHeight = numel(displayLines) * lineHeight;
yStart = max(20, floor((windowHeight - totalTextHeight) / 2));

for lineIndex = 1:numel(displayLines)
    currentLine = displayLines{lineIndex};
    if isempty(currentLine)
        continue;
    end

    textBounds = Screen('TextBounds', window, currentLine);
    textWidth = textBounds(3) - textBounds(1);
    xPosition = max(20, floor((windowWidth - textWidth) / 2));
    yPosition = yStart + (lineIndex - 1) * lineHeight;
    Screen('DrawText', window, currentLine, xPosition, yPosition, textColor);
end

Screen('Flip', window);
end
