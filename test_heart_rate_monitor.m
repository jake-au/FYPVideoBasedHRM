% ----------------------------------------------------------- %
%| JIAKAI REN, ID:22925971                                   |%
%| DEPARTMENT OF ELECTRICAL AND COMPUTER SYSTEMS ENGINEERING |%
%| MONASH UNIVERSITY                                         |%
%| FINAL YEAR PROJECT                                        |%
%| VIDEO BASED HEARTRATE MONITOR                             |%
% ----------------------------------------------------------- %

close all; clear; clc

% - Modify these parameters: - %
max_time = 45; % How long should the software run for? (in seconds)
measurefreq = 15; % How often should the software estimate HR? (in seconds)
find_peaks_start = 5; % On which second should the peak findings start for each section. (in seconds).
% ----------END--------------- %

% INITIALISATION AND FLAG SETTINGS
flag = 1;
clipcounter = 0;
totalframenum = max_time * 30;
totalframecounter = 0;
gcrop = zeros(41,41,totalframenum); % area of interest dimension 41 x 41
cam = webcam(1);
preview(cam);
clipframecounter = 0;
oldframeElapsed = 0;
P = 1;
L = 0;
gMeanAllFrames = zeros(totalframenum,2); % initialise green value mean matrix 
g_filtered = zeros(totalframenum,1); % initialise green value filtered matrix
runorder = 0;

% --------- %
%| FILTERS |%
% --------- %

vFrameRate = 30;

% NEW CASCADED FILTER
% FILTER 1 - LOW PASS
[b1 a1] = butter(5, [0.111], 'low'); % Butterworth lowpass filter
H1 = freqz(b1,a1, vFrameRate); % Frequency response

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
        
while flag == 1

    frameElapsed = 0;  
    takevideo = 1;

    % if total frames recorded is less than user requested, record more
    % frames
    
    while totalframecounter < totalframenum
            
        while takevideo == 1
            videoobj_save = VideoWriter('video_save'); 
            open(videoobj_save)
            
            % record a clip according to user setting (interval)
            while clipframecounter < measurefreq * 30
                f=snapshot(cam);
                writeVideo(videoobj_save,f);
                clipframecounter = clipframecounter + 1;
            end
            frameElapsed = frameElapsed + clipframecounter;
            clipframecounter = 0;
            close(videoobj_save)

            % READ THIS CLIP
            vName = ('video_save.avi');
            Cropped = 0; % 1 for cropped video, 0 for uncropped video.
            vForInfo = VideoReader(vName);
            vNumberOfFrames = get(vForInfo, 'NumberOfFrames');
            vHeight = get(vForInfo, 'Height');
            vWidth = get(vForInfo, 'Width');
            vFrameRate = get(vForInfo, 'FrameRate');
            vDuration = get(vForInfo, 'Duration');

            % INITIALISE GREEN Matrix
            g = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');

            % ------------------------------------------ %
            %| CREATE ANOTHER VIDEO OBJECT FOR ANALYSIS |%
            % ------------------------------------------ %

            v = VideoReader(vName);

            % EXTRACT FRAMES
            k = 1;
            while hasFrame(v)
                img = readFrame(v);
                g(:,:,k) = img(:,:,2);
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

       % FOURIER TRANSFORM
% %             G_mags = abs(fft(gMeanAllFramesNorm(frameElapsed - measurefreq * 30 + 1:frameElapsed,2)));
% %             figure(2)
% %             stem([0:2/(length(G_mags) -1):2], G_mags);
% %             xlabel('Normalised Frequency (\pi rad/frame)');
% %             ylabel('Magnitude');

        % APPLY FILTER
        runorder = runorder + 1;
        if runorder == 1
            g_filtered(frameElapsed - measurefreq * 30 + 1:frameElapsed,1) = filter(Hcas,gMeanAllFramesNorm(frameElapsed - measurefreq * 30 + 1:frameElapsed,2));
        end
        if runorder > 1
            g_filtered2(frameElapsed - measurefreq * 30 - 249:frameElapsed,1) = filter(Hcas,gMeanAllFramesNorm(frameElapsed - measurefreq * 30 - 249:frameElapsed,2));
            g_filtered(frameElapsed - measurefreq * 30 + 1:frameElapsed,1) = g_filtered2(frameElapsed - measurefreq * 30 + 1:frameElapsed,1);
        end
% %         figure(4)
% %         plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)); % without subtracting the green channel mean
% %         plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)-mean(gMeanAllFramesNorm(:,2))); % minus the green channel mean so comparason easier
% %         xlabel('Time (s)'); ylabel('Green Channel Intensity - Intensity Mean');
% %         hold on
% %         plot(gMeanAllFramesNorm(:,1)/vFrameRate, g_filtered, 'r')        
         
        % results of different clips are cascaded into one array, so all
        % previous calculations retained
        if runorder == 1
            [PKS, LOCS] = findpeaks(g_filtered(find_peaks_start*vFrameRate:frameElapsed));
            HR = length(PKS)/((vNumberOfFrames-find_peaks_start*vFrameRate)/vFrameRate) * 60;
        end
        if runorder > 1
            [PKS, LOCS] = findpeaks(g_filtered(oldframeElapsed+1:frameElapsed));
            HR = length(PKS)/(measurefreq) * 60;
        end     
                
        fprintf('Heart Rate: %.1f\n', HR);
        
        if runorder == 1
            PKSplot = PKS;         
            LOCSplot = LOCS+find_peaks_start*vFrameRate;
        end
        
        if runorder > 1
            PKSplot = cat(1,PKSplot,PKS);
            LOCSplot = cat(1,LOCSplot,LOCS+oldframeElapsed);
        end
        
        oldframeElapsed = frameElapsed;
        totalframecounter = totalframecounter + measurefreq * 30;
        
        % if total number of frames reached, set flag to 0 and exit
        % program
        
        if totalframecounter >= totalframenum
            flag = 0;
            takevideo = 0;
            close(videoobj_save)
            clear cam;
        end        
        end
    end  
end
figure(4)
plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)-mean(gMeanAllFramesNorm(:,2))); % minus the green channel mean so comparason easier
xlabel('Time (s)'); ylabel('Green Channel Intensity - Intensity Mean');
hold on
plot(gMeanAllFramesNorm(:,1)/vFrameRate, g_filtered, 'r')
plot(LOCSplot/vFrameRate, PKSplot, 'g*');
hold off