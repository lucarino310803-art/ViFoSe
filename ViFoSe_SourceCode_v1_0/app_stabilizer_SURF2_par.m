% AUTHOR: Abdelrahman Abdelaziz Mohamed (E-mail: abdu.abdelaziz46@gmail.com)
%
% DATE: 21/04/2026
%
% DESCRIPTION: This MATLAB function stabilizes a video by aligning each frame to a user-selected reference frame using the SURF (Speeded-Up Robust Features) algorithm
%              with optimized parallel processing and memory-efficient techniques. The function detects and matches SURF features between the reference frame and each 
%              other frame to compute an affine geometric transformation. It applies this transformation to align each frame to the reference, effectively stabilizing 
%              the video. The stabilized frames are saved as a new video file in the specified output folder with platform-appropriate format (MP4 for Windows/Mac, AVI for Linux).
%
% KEY OPTIMIZATIONS:
%   - Downsampled Feature Detection: SURF features are detected on 25% downsampled images for 16x faster processing, with transform scaling applied afterward.
%   - Parallel Transform Computation: All geometric transforms are computed in parallel (parfor) before video writing, maximizing CPU utilization.
%   - Block-Based Video Writing: Frames are loaded and written in blocks of 20 to minimize memory footprint and prevent memory saturation.
%   - Memory Management: Frames are loaded from disk on-demand rather than using pre-loaded Frame_Data array, reducing RAM usage for long sequences.
%   - Automatic Format Selection: Chooses Motion JPEG AVI for Linux/Unix and MPEG-4 for Windows/Mac for maximum compatibility.
%
% ALGORITHM WORKFLOW:
%   1. Parallel Pool Initialization: Creates a local parallel pool with 4 workers if one doesn't exist.
%   2. Frame Loading and Sorting: Loads PNG image list from input folder and sorts numerically using natural ordering.
%   3. Reference Frame Processing: Loads reference frame, converts to grayscale, downsamples to 25%, and extracts SURF features once.
%   4. Parallel Transform Estimation: For each non-reference frame in parallel:
%      - Loads frame from disk and downsamples to 25%
%      - Detects SURF features on downsampled image
%      - Matches features with reference frame
%      - Estimates affine transform if ≥3 matches exist
%      - Rescales translation components to full resolution (rotation/scale unchanged)
%      - Stores transform or null if matching fails
%   5. Transform Remapping: Maps computed transforms back to original frame indices (reference frame has no transform).
%   6. Output Path Construction: Extracts input folder name and builds output video filename with '_stabilized_SURF' suffix.
%   7. Block-Based Video Writing: Processes frames in blocks of 20:
%      - Loads each frame from disk
%      - Applies computed transform (or uses original if transform failed)
%      - Writes block sequentially to video
%   8. Finalization: Closes video writer and reports output path.
%
% INPUT PARAMETERS:
%   - Frame_Data: (unused in optimized version - kept for API compatibility)
%   - outputFolder: Full path to directory where stabilized video will be saved
%   - fps: Desired frame rate for output video
%   - referenceFrame: Index (1-based) of the frame to use as alignment reference
%   - inputFolder: Full path to directory containing source PNG frames
%
% OUTPUT:
%   - Stabilized video file saved to outputFolder with automatic naming:
%     - Format: [inputFolderName]_stabilized_SURF.mp4 (Windows/Mac)
%     - Format: [inputFolderName]_stabilized_SURF.avi (Linux/Unix)
%   - Console message confirming output file path
%
% TECHNICAL DETAILS:
%   - Feature Detection: SURF features detected on 0.25x downsampled images (4x4 = 16x faster)
%   - Transform Type: Affine (allows translation, rotation, scaling, shearing)
%   - Transform Scaling: Translation components rescaled from downsampled to full resolution (T(3,1) and T(3,2) divided by scale factor)
%   - Rotation/Scale Handling: Rotation and scale components remain unchanged (inherently scale-invariant)
%   - Fallback Strategy: Original frame used if feature matching fails or <3 matches found
%   - Memory Strategy: Block processing (20 frames) prevents loading entire sequence into RAM
%   - Parallel Workers: 4 workers for transform computation, sequential for video writing (VideoWriter not thread-safe)
%
% ROBUSTNESS FEATURES:
%   - Try-catch blocks around transform estimation to handle degenerate geometries
%   - Minimum 3-point matching requirement prevents unreliable transforms
%   - Fallback to original frames ensures continuous video output even if stabilization fails
%   - Natural number sorting handles frame sequences like [img1, img2, ..., img10, img11] correctly
%   - Platform-aware codec selection ensures cross-platform compatibility
%
% PERFORMANCE CHARACTERISTICS:
%   - Speed: ~16x faster feature detection via downsampling + parallel processing
%   - Memory: O(blockSize) frame storage instead of O(numFrames)
%   - Scalability: Handles sequences of any length without memory issues
%   - CPU Utilization: Near-linear speedup with number of cores during transform computation
%
% DEPENDENCIES:
%   - MATLAB Computer Vision Toolbox (for detectSURFFeatures, extractFeatures, matchFeatures, estimateGeometricTransform2D, imwarp)
%   - MATLAB Parallel Computing Toolbox (for parfor, parpool, gcp)
%   - MATLAB Image Processing Toolbox (for imresize, im2gray, imref2d)
%
% USAGE EXAMPLE:
%   app_stabilizer_SURF2_par([], '/path/to/output', 30, 1, '/path/to/frames')
%   % Stabilizes PNG frames in '/path/to/frames' using frame 1 as reference
%   % Outputs 30fps video to '/path/to/output'
%
% LIMITATIONS:
%   - Assumes all frames are same size (reference frame size used for output)
%   - Works only with PNG input frames (hardcoded '*.png' pattern)
%   - Affine transform cannot correct for perspective distortion or lens distortion
%   - SURF may fail on low-texture or extremely blurred regions
%   - Requires sufficient overlap between frames for feature matching



function app_stabilizer_SURF2_par(Frame_Data, outputFolder, fps, referenceFrame, inputFolder)
% This function stabilizes a video sequence using SURF feature matching
% with parallel processing for improved performance

    % ========================================================================
    % STEP 1: INITIALIZE PARALLEL POOL
    % ========================================================================
    % Check if parallel pool exists, create one with 4 workers if not
    if isempty(gcp('nocreate'))
        parpool('local', 4);
    end

    % ========================================================================
    % STEP 2: LOAD AND SORT IMAGE FILES NATURALLY
    % ========================================================================
    % Sort image files numerically (natural ordering)
    imageFiles = dir(fullfile(inputFolder, '*.png'));
    numParts   = regexp({imageFiles.name}, '\d+', 'match');
    numVal     = cellfun(@(x) str2double(x{1}), numParts);
    [~, idx]   = sort(numVal);
    imageFiles = imageFiles(idx);

    numFrames    = length(imageFiles);
    
    % ========================================================================
    % STEP 3: LOAD REFERENCE FRAME
    % ========================================================================
    fixed_image  = imread(fullfile(inputFolder, imageFiles(referenceFrame).name));
    fixed_gray   = im2gray(fixed_image);
    Rfixed_image = imref2d(size(fixed_image));

    % ========================================================================
    % STEP 4: DETECT SURF FEATURES ON DOWNSAMPLED REFERENCE FRAME
    % ========================================================================
    % Compute SURF features on downsampled reference once for efficiency
    scale       = 0.25;  % Downsample to 25% for faster feature detection
    fixed_small = imresize(fixed_gray, scale);
    refPoints   = detectSURFFeatures(fixed_small);
    [refFeatures, refValidPoints] = extractFeatures(fixed_small, refPoints);

    % ========================================================================
    % STEP 5: PREPARE FRAMES FOR PARALLEL PROCESSING
    % ========================================================================
    % Exclude reference frame from processing (it doesn't need alignment)
    framesToProcess = setdiff(1:numFrames, referenceFrame);
    numToProcess    = length(framesToProcess);

    % ========================================================================
    % STEP 6: COMPUTE TRANSFORMS IN PARALLEL
    % ========================================================================
    % Compute transforms in parallel for all non-reference frames
    tempTforms = cell(1, numToProcess);

    parfor k = 1:numToProcess
        i            = framesToProcess(k);
        
        % Load current frame and downsample
        moving       = imread(fullfile(inputFolder, imageFiles(i).name));
        moving_small = imresize(im2gray(moving), scale);

        % Detect SURF features in current frame
        currPoints = detectSURFFeatures(moving_small);
        [currFeatures, currValidPoints] = extractFeatures(moving_small, currPoints);

        % Match features between current frame and reference
        indexPairs  = matchFeatures(currFeatures, refFeatures, 'Unique', true);
        matchedCurr = currValidPoints(indexPairs(:,1));
        matchedRef  = refValidPoints(indexPairs(:,2));

        % Estimate geometric transform if enough matches found
        if length(matchedCurr) >= 3
            try
                % Estimate affine transform on downsampled images
                tform_small = estimateGeometricTransform2D(matchedCurr, matchedRef, 'affine');

                % Rescale only translation, keep rotation/scale as-is
                tform_full = tform_small;
                tform_full.T(3,1) = tform_small.T(3,1) / scale;
                tform_full.T(3,2) = tform_small.T(3,2) / scale;

                tempTforms{k} = tform_full;
            catch
                tempTforms{k} = [];  % Fallback: no transform if estimation fails
            end
        else
            tempTforms{k} = [];  % Fallback: not enough feature matches
        end
    end

    % ========================================================================
    % STEP 7: REMAP TRANSFORMS TO ORIGINAL FRAME INDICES
    % ========================================================================
    % Remap transforms to frame index (including reference frame slot)
    allTforms = cell(1, numFrames);
    for k = 1:numToProcess
        allTforms{framesToProcess(k)} = tempTforms{k};
    end

    % ========================================================================
    % STEP 8: BUILD OUTPUT VIDEO PATH
    % ========================================================================
    % Extract folder name from input path for output filename
    pathParts  = strsplit(inputFolder, filesep);
    folderName = pathParts{end};
    if isempty(folderName) && numel(pathParts) > 1
        folderName = pathParts{end-1};
    end
    if isempty(folderName)
        folderName = 'stabilized_video';
    end

    % Platform-specific video format selection
    if isunix && ~ismac
        outputVideoName = [folderName '_stabilized_SURF.avi'];
        profile = 'Motion JPEG AVI';
    else
        outputVideoName = [folderName '_stabilized_SURF.mp4'];
        profile = 'MPEG-4';
    end

    % ========================================================================
    % STEP 9: INITIALIZE VIDEO WRITER
    % ========================================================================
    outputVideoPath = fullfile(outputFolder, outputVideoName);
    writer = VideoWriter(outputVideoPath, profile);
    writer.FrameRate = fps;

    % ========================================================================
    % STEP 10: WRITE VIDEO IN PARALLEL BLOCKS
    % ========================================================================
    % Write video in parallel blocks for memory efficiency
    blockSize = 20;  % Process 20 frames at a time
    open(writer);

    for blockStart = 1:blockSize:numFrames
        blockEnd    = min(blockStart + blockSize - 1, numFrames);
        blockIdx    = blockStart:blockEnd;
        n           = length(blockIdx);
        blockFrames = cell(1, n);

        % Process block in parallel
        parfor j = 1:n
            i = blockIdx(j);
            if i == referenceFrame
                % Reference frame: use original without transformation
                blockFrames{j} = fixed_image;
            else
                % Load frame and apply computed transform
                moving = imread(fullfile(inputFolder, imageFiles(i).name));
                if ~isempty(allTforms{i})
                    % Apply transform to align frame with reference
                    blockFrames{j} = imwarp(moving, allTforms{i}, 'OutputView', Rfixed_image);
                else
                    % Fallback: use original frame if transform failed
                    blockFrames{j} = moving;
                end
            end
        end

        % Write block to video sequentially
        for j = 1:n
            writeVideo(writer, blockFrames{j});
        end
    end

    % ========================================================================
    % STEP 11: FINALIZE VIDEO
    % ========================================================================
    close(writer);
    fprintf('Stabilized video saved as: %s\n', outputVideoPath);
end