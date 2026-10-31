function ns203_waitForSpace(keySpace, keyEscape)
% Wait until SPACE is pressed. ESC aborts the task.
KbReleaseWait;
while true
    [keyIsDown, ~, keyCode] = KbCheck;
    if keyIsDown
        if keyCode(keyEscape)
            error('Experiment aborted by participant.');
        end
        if keyCode(keySpace)
            break;
        end
    end
    WaitSecs(0.01);
end
KbReleaseWait;
end
