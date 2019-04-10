% ----------------------------------------------------------- %
%| JIAKAI REN, ID:22925971                                   |%
%| DEPARTMENT OF ELECTRICAL AND COMPUTER SYSTEMS ENGINEERING |%
%| MONASH UNIVERSITY                                         |%
%| FINAL YEAR PROJECT                                        |%
%| VIDEO BASED HEARTRATE MONITOR                             |%
% ----------------------------------------------------------- %

close all
clear all
clc

% ------------------------- %
%| READ VIDEO & VIDEO INFO |%
% ------------------------- %

% - Modify these parameters: - %
vName = ('1.mp4');
Cropped = 1; % 1 for cropped video, 0 for uncropped video.
find_peaks_start = 3; % on which second should the peak findings start.
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

% -------- %
%| GRAPHS |%
% -------- %

figure(1)
imshow(g(:,:,1));
hold on
figure(1)
rectangle('Position', [290, 100, 40, 40], 'LineWidth', 1, 'LineStyle', '-')
hold off

figure(2)
plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2));
xlabel('Time (s)'); ylabel('Green Channel Intensity');

% --------- %
%| FILTERS |%
% --------- %

% FOURIER TRANSFORM
G_mags = abs(fft(gMeanAllFramesNorm(:,2)));
figure(3)
stem([0:2/(length(G_mags) -1):2], G_mags);
xlabel('Normalised Frequency (\pi rad/frame)');
ylabel('Magnitude');

% FILTER
[b a] = butter(2, [0.12], 'low') % Butterworth lowpass filter
H = freqz(b,a, vFrameRate); % Frequency response
hold on
plot([0:1/(vFrameRate -1):1], abs(H), 'r');
hold off

% APPLY FILTER
g_filtered = filter(b,a,gMeanAllFramesNorm(:,2));

figure(2)
plot(gMeanAllFramesNorm(:,1)/vFrameRate,gMeanAllFramesNorm(:,2));
xlabel('Time (s)'); ylabel('Green Channel Intensity');
hold on
plot(gMeanAllFramesNorm(:,1)/vFrameRate, g_filtered, 'r')

[PKS, LOCS] = findpeaks(g_filtered(150:vNumberOfFrames));
HR = length(PKS)/((vNumberOfFrames-150)/vFrameRate) * 60
plot((LOCS+150)/vFrameRate, PKS, 'g*');
hold off

% g_filtered_1 = diff(g_filtered);
% PKS_2 = findpeaks(g_filtered_1);

% secs_measured = floor(vDuration);
% 
% for m = find_peaks_start + secs_per_measure -1:secs_measured - secs_per_measure +1
%     