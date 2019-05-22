%=========================================================================%
%  JIAKAI REN, ID:22925971                                                %
%  DEPARTMENT OF ELECTRICAL AND COMPUTER SYSTEMS ENGINEERING              %
%  MONASH UNIVERSITY                                                      %
%  FINAL YEAR PROJECT                                                     %
%  VIDEO BASED HEARTRATE MONITOR                                          %
%=========================================================================%

close all; clear; clc

%=========================================================================%
%    XXXXXXX  XX     XX       XX       XXX    XX    XXXXXXX  XXXXXXXXX    %
%   XX        XX     XX     XX  XX     XXXX   XX   XX        XX           %
%  XX         XXXXXXXXX    XXXXXXXX    XX XX  XX  XX   XXXX  XXXXXXXXX    %
%   XX        XX     XX   XX      XX   XX  XX XX   XX    XX  XX           %
%    XXXXXXX  XX     XX  XX        XX  XX   XXXX    XXXXXXX  XXXXXXXXX    %
%  >> >>> >>>> >>>>> >>>>>> >>>>>>> HERE <<<<<<< <<<<<< <<<<< <<<< <<< << %
max_time = 120; % How long should the software run for? (in seconds)
window = 15; % How many seconds of data should be used for HR estimation?
HRinterval = 1; % HR update interval in seconds.
%find_peaks_start = 5; % On which second should the peak findings start for each section. (in seconds).
%=========================================================================%

%======================== VIDEO PREVIEW ==================================%
% Create axes control.
handleToAxes = axes();
% Get the handle to the image in the axes.
hImage = image(zeros(720,1280,'uint8'));
% Reset image magnification. Required if you ever displayed an image
% in the axes that was not the same size as your webcam image.
hold off;
axis auto;
axis on;
% Enlarge figure to full screen.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
% Turn on the live video.
cam = webcam(1);
preview(cam, hImage);
hold on
thisBB = [620 180 40 40];
rectangle('Position', [thisBB(1),thisBB(2),thisBB(3),thisBB(4)], ...
    'EdgeColor','r','LineWidth',2 )
hold off
%=========================================================================%

%=================== INPUT CHECK =========================================%
if window < 2
    fprintf('ERROR: Window must be at least 2 seconds!')
elseif (window >= 2) && (window <= 10)
    fprintf('WARNING: Window may be too small and Heart Rate could be inaccurate. Window larger than 10 seconds is recommended.\n')
elseif window > max_time
    fprintf('ERROR: Window size cannot be longer than Max Time!')
end
%=========================================================================%

%=================== INITIALIZATION ======================================%
framerate = 30;
windowstartpos = window * framerate;
totalframenum = max_time * framerate;
gcrop = zeros(41,41);
peakcounter = 0;
framecounter = 0;
j = 0;
peak = zeros(max_time *3,2);
HR = zeros(max_time,1);
c = zeros(6,1);
time = zeros(max_time+1,1);
%=========================================================================%

%=================== FILTER ==============================================%
% FILTER 1 - LOW PASS
[b1,a1] = butter(5, 0.111, 'low'); % Butterworth lowpass filter
% FILTER 2 - NOTCH
[b2,a2] = iirnotch(0.0001, 0.04);
%=========================================================================%

%=================== INITIALIZATION OF FILTER RELATED PARAMETERS==========%
MFO = max(length(a1), length(a2)); % max filter order
gmean = zeros(totalframenum + MFO - 1,1); % mean value of each frame
gmeanf1 = zeros(totalframenum + MFO - 1,1); % mean value after filter LOW PASS
gmeanf2 = zeros(totalframenum + MFO - 1,1); % mean value after both filter
%=========================================================================%

pause(1);

%=================== BODY ================================================%
for i = MFO : totalframenum + MFO - 1
    f = snapshot(cam); % take a frame
    c = clock;
    gcrop = f(180:220,620:660,2); % crop it
    gmean(i) = mean2(gcrop); % get the average value of that frame 
    framecounter = framecounter + 1;
    
    gmeanf1(i) = (-a1(2)*gmeanf1(i-1) - a1(3)*gmeanf1(i-2) - a1(4)*gmeanf1(i-3) - a1(5)*gmeanf1(i-4) ...
        - a1(6)*gmeanf1(i-5) + b1(1)*gmean(i) + b1(2)*gmean(i-1) + b1(3)*gmean(i-2) + b1(4)*gmean(i-3) ...
        + b1(5)*gmean(i-4) + b1(6)*gmean(i-5)) / a1(1); % apply low pass filter
    
    gmeanf2(i) = (-a2(2)*gmeanf2(i-1) - a2(3)*gmeanf2(i-2) + b2(1)*gmeanf1(i) + b2(2)*gmeanf1(i-1) + ...
        b2(3)*gmeanf1(i-2)) / a2(1); % apply notch filter
    
    % Find peaks
    if (gmeanf2(i-1) >= gmeanf2(i-2)) && (gmeanf2(i-1) >= gmeanf2(i))
        peakcounter = peakcounter + 1;
        peak(peakcounter,1) = i-MFO;
        peak(peakcounter,2) = gmeanf2(i-1);
    end
    
    % For every HRinterval the HR is calculated:
    if (framecounter == HRinterval * framerate)
       j = j + 1;
       peakselection = peak(peak(:,1) > i - MFO + 1 - windowstartpos,1);
       time(j+1) = c(6);
       if time(j+1) > time(j)
           realframerate = framerate/(time(j+1) - time(j));
       else
           realframerate = framerate/(60 + time(j+1) - time(j));
       end
       HR(j) = (length(peakselection)-1) / ((peakselection(end) - peakselection(1)) / realframerate) * 60;
       
       if j * HRinterval < window
           fprintf('Filling the window, Heart Rate in %d second(s).\n', window-j*HRinterval)
       else
       fprintf('Heart Rate: %.0f\n', HR(j));
       end
       
       framecounter = 0;     
    end
end

clear cam
close all
%=========================================================================%

%=================== PLOT ================================================%
figure(1)
plot(1:totalframenum, gmeanf2(MFO:i))
xlabel('Frame'); ylabel('Green Channel Intensity - Intensity Mean');
hold on
plot(1:totalframenum, gmean(MFO:i) - mean(gmean))
plot(peak(:,1),peak(:,2), 'g*')
hold off

figure(2)
plot(window:HRinterval:max_time, HR(ceil(window/HRinterval):floor(max_time/HRinterval)));
xlabel('Time (s)');
ylabel('HR (bpm)');
%=========================================================================%