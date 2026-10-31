function [confidence, RT, responseKey] = ns203_getConfidence(responseDuration, key1, key2, key3, key4, keyEscape)
% Collects a 1-4 confidence response, following the TA's KbCheck/KbReleaseWait style.
confidence = NaN;
RT = NaN;
responseKey = "timeout";
startTime = tic;
while toc(startTime) < responseDuration
    [keyIsDown, secs, keyCode] = KbCheck;
    if keyIsDown
        if keyCode(keyEscape)
            error('Experiment aborted by participant.');
        elseif keyCode(key1)
            confidence = 1;
            responseKey = "1";
        elseif keyCode(key2)
            confidence = 2;
            responseKey = "2";
        elseif keyCode(key3)
            confidence = 3;
            responseKey = "3";
        elseif keyCode(key4)
            confidence = 4;
            responseKey = "4";
        end
        if ~isnan(confidence)
            RT = toc(startTime);
            KbReleaseWait;
            return;
        end
        KbReleaseWait;
    end
end
end
