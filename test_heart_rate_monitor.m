% ----------------------------------------------------------- %
%| JIAKAI REN, ID:22925971                                   |%
%| DEPARTMENT OF ELECTRICAL AND COMPUTER SYSTEMS ENGINEERING |%
%| MONASH UNIVERSITY                                         |%
%| FINAL YEAR PROJECT                                        |%
%| VIDEO BASED HEARTRATE MONITOR                             |%
% ----------------------------------------------------------- %

close all; clear; clc

% ------------------------- %
%| READ VIDEO & VIDEO INFO |%
% ------------------------- %
flag = 1;
clipcounter = 0;
max_time = 45; % in seconds
measurefreq = 15; % in seconds
totalframenum = max_time * 30;
totalframecounter = 0;
gcrop = zeros(41,41,totalframenum);
cam = webcam(1);
clipframecounter = 0;
oldframeElapsed = 0;

P = 1;
L = 0;


% INITIALISE GREEN CHANNEL MEAN VALUE MATRIX
        gMeanAllFrames = zeros(totalframenum,2);
        
        g_filtered = zeros(totalframenum,1);
        
while flag == 1

    frameElapsed = 0;
    preview(cam)
    takevideo = 1;

    while totalframecounter < totalframenum

        while takevideo == 1
            videoobj_save = VideoWriter('video_save'); 
            open(videoobj_save)
            while clipframecounter < measurefreq * 30
                f=snapshot(cam);
                writeVideo(videoobj_save,f);
                clipframecounter = clipframecounter + 1;
            end
            frameElapsed = frameElapsed + clipframecounter;
            clipframecounter = 0;
            close(videoobj_save)
            % % clear cam;

            % - Modify these parameters: - %
            vName = ('video_save.avi');
            Cropped = 0; % 1 for cropped video, 0 for uncropped video.
            find_peaks_start = 5; % on which second should the peak findings start.
            secs_per_measure = 5; % number of seconds used to read one HR out.
            % ----------END--------------- %

            vForInfo = VideoReader(vName);
            vNumberOfFrames = get(vForInfo, 'NumberOfFrames');
            vHeight = get(vForInfo, 'Height');
            vWidth = get(vForInfo, 'Width');
            vFrameRate = get(vForInfo, 'FrameRate');
            vDuration = get(vForInfo, 'Duration');

            % INITIALISE RGB MATRICES
            % r = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');
            g = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');
            % b = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');

            % ------------------------------------------ %
            %| CREATE ANOTHER VIDEO OBJECT FOR ANALYSIS |%
            % ------------------------------------------ %

            v = VideoReader(vName);

            % EXTRACT FRAMES
            k = 1;
            while hasFrame(v)
                img = readFrame(v);
            %     r(:,:,k) = img(:,:,1);
                g(:,:,k) = img(:,:,2);
            %     b(:,:,k) = img(:,:,3);
                k = k + 1;
            end

            % TEMP METHOD FOR CROPPING
            if Cropped == 1
                    gcrop(:,:,frameElapsed - measurefreq * 30 + 1:frameElapsed) = g; % Do not crop if already cropped.
                else
                    gcrop(:,:,frameElapsed - measurefreq * 30 + 1:frameElapsed) = g(180:220,620:660,:);
            end

        for l = frameElapsed - measurefreq * 30 + 1:frameElapsed
            gMeanAllFrames(l,1) = l;
            gMeanAllFrames(l,2) = mean2(gcrop(:,:,l));
        %     l = l + 1;
        end

        % NORMALISE CROPPED GREEN CHANNEL MEAN VALUE MATRIX
        gMeanAllFramesNorm(frameElapsed - measurefreq * 30 + 1:frameElapsed, :)= gMeanAllFrames(frameElapsed - measurefreq * 30 + 1:frameElapsed, :);
        gMeanAllFramesNorm(frameElapsed - measurefreq * 30 + 1:frameElapsed, 2) = gMeanAllFrames(frameElapsed - measurefreq * 30 + 1:frameElapsed, 2)/norm(gMeanAllFrames(frameElapsed - measurefreq * 30 + 1:frameElapsed, 2));

        % ------------ %
        %| FRAME SHOW |%
        % ------------ %

% %         figure(1)
% %         imshow(g(:,:,1));
% %         hold on
% %         figure(1)
% %         rectangle('Position', [620, 180, 40, 40], 'LineWidth', 1, 'LineStyle', '-')
% %         hold off

        % --------- %
        %| FILTERS |%
        % --------- %

        % FOURIER TRANSFORM
        G_mags = abs(fft(gMeanAllFramesNorm(frameElapsed - measurefreq * 30 + 1:frameElapsed,2)));
        % % figure(2)
        % % stem([0:2/(length(G_mags) -1):2], G_mags);
        % % xlabel('Normalised Frequency (\pi rad/frame)');
        % % ylabel('Magnitude');

        % NEW CASCADED FILTER
        % FILTER 1 - LOW PASS
        [b1 a1] = butter(5, [0.111], 'low'); % Butterworth lowpass filter
        H1 = freqz(b1,a1, vFrameRate); % Frequency response
        % % hold on
        % % plot(0:1/(vFrameRate -1):1, abs(H1), 'r');

        % FILTER 2 - NOTCH
        wo = 0.0001;  bw = 0.04;
        [b2,a2] = iirnotch(wo,bw);
        H2 = freqz(b2,a2, vFrameRate);

        % FILTER CASCADING
        H1=dfilt.df2t(b1,a1);
        H2=dfilt.df2t(b2,a2);
        Hcas=dfilt.cascade(H1,H2); 
        % info(Hcas.Stage(1))
        % hfvt= fvtool(Hcas,'Color','white');

        % APPLY FILTER
        g_filtered(frameElapsed - measurefreq * 30 + 1:frameElapsed,1) = filter(Hcas,gMeanAllFramesNorm(frameElapsed - measurefreq * 30 + 1:frameElapsed,2));

% %         figure(4)
% %         plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)); % without subtracting the green channel mean
% %         plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)-mean(gMeanAllFramesNorm(:,2))); % minus the green channel mean so comparason easier
% %         xlabel('Time (s)'); ylabel('Green Channel Intensity - Intensity Mean');
% %         hold on
% %         plot(gMeanAllFramesNorm(:,1)/vFrameRate, g_filtered, 'r')
        
         
        [PKS, LOCS] = findpeaks(g_filtered(oldframeElapsed + find_peaks_start*vFrameRate:frameElapsed));
        
        oldframeElapsed = frameElapsed;
        
        HR = length(PKS)/((vNumberOfFrames-find_peaks_start*vFrameRate)/vFrameRate) * 60;
        fprintf('Heart Rate: %.1f\n', HR);
        while P == 1
            PKSplot = PKS;         
            LOCSplot = LOCS;
            P = 0;
        end
        
        if L == 1;
            PKSplot = cat(1,PKSplot,PKS);
            LOCSplot = cat(1,LOCSplot,LOCS + frameElapsed - vNumberOfFrames);
        end
        L = 1;
        
        totalframecounter = totalframecounter + measurefreq * 30;
        if totalframecounter >= totalframenum
            flag = 0;
            takevideo = 0;
        end
        
        end
        
% %         plot((LOCS+find_peaks_start*vFrameRate)/vFrameRate, PKS, 'g*');
% %         hold off

% %         frameElapsed = 0;
        
    end  
end
figure(4)
plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)-mean(gMeanAllFramesNorm(:,2))); % minus the green channel mean so comparason easier
xlabel('Time (s)'); ylabel('Green Channel Intensity - Intensity Mean');
hold on
plot(gMeanAllFramesNorm(:,1)/vFrameRate, g_filtered, 'r')
plot((LOCSplot+find_peaks_start*vFrameRate)/vFrameRate, PKSplot, 'g*');
hold off


close(videoobj_save)
clear cam;