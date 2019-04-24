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

% - Modify these parameters: - %
vName = ('test4.mp4');
Cropped = 1; % 1 for cropped video, 0 for uncropped video.
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
r = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');
g = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');
b = zeros(vHeight, vWidth, vNumberOfFrames, 'uint8');

% ------------------------------------------ %
%| CREATE ANOTHER VIDEO OBJECT FOR ANALYSIS |%
% ------------------------------------------ %

v = VideoReader(vName);

% EXTRACT FRAMES
k = 1;
while hasFrame(v)
    img = readFrame(v);
    r(:,:,k) = img(:,:,1);
    g(:,:,k) = img(:,:,2);
    b(:,:,k) = img(:,:,3);
    k = k + 1;
end

% TEMP METHOD FOR CROPPING
if Cropped == 1
    gcrop = g; % Do not crop if already cropped.
else
    gcrop = g(100:140,290:330,:);
end

% INITIALISE GREEN CHANNEL MEAN VALUE MATRIX
gMeanAllFrames = zeros(vNumberOfFrames,2);

for l = 1:vNumberOfFrames
    gMeanAllFrames(l,1) = l;
    gMeanAllFrames(l,2) = mean2(gcrop(:,:,l));
%     l = l + 1;
end

% NORMALISE CROPPED GREEN CHANNEL MEAN VALUE MATRIX
gMeanAllFramesNorm = gMeanAllFrames;
gMeanAllFramesNorm(:,2) = gMeanAllFrames(:,2)/norm(gMeanAllFrames(:,2));

% ------------ %
%| FRAME SHOW |%
% ------------ %

figure(1)
imshow(g(:,:,1));
hold on
figure(1)
rectangle('Position', [290, 100, 40, 40], 'LineWidth', 1, 'LineStyle', '-')
hold off

% --------- %
%| FILTERS |%
% --------- %

% FOURIER TRANSFORM
G_mags = abs(fft(gMeanAllFramesNorm(:,2)));
figure(2)
stem([0:2/(length(G_mags) -1):2], G_mags);
xlabel('Normalised Frequency (\pi rad/frame)');
ylabel('Magnitude');

% FILTER - ORIGINAL SINGLE FILTER
% [b a] = butter(5, [0.111], 'low') % Butterworth lowpass filter
% H = freqz(b,a, vFrameRate); % Frequency response
% hold on
% plot([0:1/(vFrameRate -1):1], abs(H), 'r');
% hold off

% NEW CASCADED FILTER
% FILTER 1 - LOW PASS
[b1 a1] = butter(5, [0.111], 'low') % Butterworth lowpass filter
H1 = freqz(b1,a1, vFrameRate); % Frequency response
hold on
plot(0:1/(vFrameRate -1):1, abs(H1), 'r');

% FILTER 2 - NOTCH
wo = 0.0001;  bw = 0.04;
[b2,a2] = iirnotch(wo,bw);
H2 = freqz(b2,a2, vFrameRate);
plot(0:1/(vFrameRate -1):1, abs(H2), 'b');
hold off

% FILTER CASCADING
H1=dfilt.df2t(b1,a1);
H2=dfilt.df2t(b2,a2);
Hcas=dfilt.cascade(H1,H2)  
info(Hcas.Stage(1))
hfvt= fvtool(Hcas,'Color','white');

% APPLY FILTER
g_filtered = filter(Hcas,gMeanAllFramesNorm(:,2));

figure(4)
plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)); % without subtracting the green channel mean
plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2)-mean(gMeanAllFramesNorm(:,2))); % minus the green channel mean so comparason easier
xlabel('Time (s)'); ylabel('Green Channel Intensity - Intensity Mean');
hold on
plot(gMeanAllFramesNorm(:,1)/vFrameRate, g_filtered, 'r')

[PKS, LOCS] = findpeaks(g_filtered(find_peaks_start*vFrameRate:vNumberOfFrames));
HR = length(PKS)/((vNumberOfFrames-find_peaks_start*vFrameRate)/vFrameRate) * 60
plot((LOCS+find_peaks_start*vFrameRate)/vFrameRate, PKS, 'g*');
hold off

% g_filtered_1 = diff(g_filtered);
% PKS_2 = findpeaks(g_filtered_1);

% secs_measured = floor(vDuration);
% 
% for m = find_peaks_start + secs_per_measure -1:secs_measured - secs_per_measure +1
%     