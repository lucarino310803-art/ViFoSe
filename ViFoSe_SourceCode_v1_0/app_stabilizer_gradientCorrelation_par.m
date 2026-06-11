% AUTHOR: Abdelrahman Abdelaziz Mohamed (E-mail: abdu.abdelaziz46@gmail.com)
%
% DATE: 21/04/2026
%
% DESCRIPTION: This MATLAB function stabilizes a video by aligning each frame to a user-selected reference frame using gradient-based correlation alignment
%              with optimized parallel processing and memory-efficient techniques. The function uses imregcorr to compute translation-only transformations
%              by maximizing the correlation between image gradients. This method is particularly effective for pure translational camera motion and is
%              computationally faster than feature-based approaches. The stabilized frames are saved as a new video file in the specified output folder
%              with platform-appropriate format (MP4 for Windows/Mac, AVI for Linux).
%
% KEY OPTIMIZATIONS:
%   - Downsampled Correlation: Gradient correlation computed on 25% downsampled images for 16x faster processing, with transform scaling applied afterward.
%   - Parallel Transform Computation: All geometric transforms are computed in parallel (parfor) before video writing, maximizing CPU utilization.
%   - Block-Based Video Writing: Frames are loaded and written in blocks of 20 to minimize memory footprint and prevent memory saturation.
%   - Memory Management: Frames are loaded from disk on-demand rather than using pre-loaded Frame_Data array, reducing RAM usage for long sequences.
%   - Translation-Only Transform: Uses pure translation (no rotation/scaling) for faster, more stable alignment in cases of camera shake.
%   - Automatic Format Selection: Chooses Motion JPEG AVI for Linux/Unix and MPEG-4 for Windows/Mac for maximum compatibility.
%
% ALGORITHM WORKFLOW:
%   1. Parallel Pool Initialization: Creates a local parallel pool with 4 workers if one doesn't exist.
%   2. Frame Loading and Sorting: Loads PNG image list from input folder and sorts numerically using natural ordering.
%   3. Reference Frame Processing: Loads reference frame, converts to grayscale, downsamples to 25%, and creates output coordinate system.
%   4. Parallel Transform Estimation: For each non-reference frame in parallel:
%      - Loads frame from disk and downsamples to 25%
%      - Computes translation transform using gradient correlation (imregcorr) on downsampled images
%      - Rescales translation components to full resolution (divides by 0.25)
%      - Stores transform for later application
%   5. Transform Remapping: Maps computed transforms back to original frame indices (reference frame has no transform).
%   6. Output Path Construction: Extracts input folder name and builds output video filename with '_stabilized_GRADIENT' suffix.
%   7. Block-Based Video Writing: Processes frames in blocks of 20:
%      - Loads each frame from disk
%      - Applies computed transform to align with reference
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
%     - Format: [inputFolderName]_stabilized_GRADIENT.mp4 (Windows/Mac)
%     - Format: [inputFolderName]_stabilized_GRADIENT.avi (Linux/Unix)
%   - Console message confirming output file path
%
% TECHNICAL DETAILS:
%   - Registration Method: imregcorr (intensity-based gradient correlation)
%   - Transform Type: Translation only (rigid shift in x and y, no rotation or scaling)
%   - Downsampling Factor: 0.25 (processes images at 25% resolution for 16x speedup)
%   - Transform Scaling: Translation components (T(3,1) and T(3,2)) rescaled from downsampled to full resolution
%   - Memory Strategy: Block processing (20 frames) prevents loading entire sequence into RAM
%   - Parallel Workers: 4 workers for transform computation and frame warping, sequential for video writing (VideoWriter not thread-safe)
%
% ADVANTAGES OVER FEATURE-BASED METHODS:
%   - No feature detection required - works on low-texture or homogeneous regions
%   - Faster computation due to direct gradient correlation
%   - More robust to illumination changes
%   - Simpler algorithm with fewer parameters to tune
%   - Translation-only constraint improves stability for pure camera shake scenarios
%
% PERFORMANCE CHARACTERISTICS:
%   - Speed: ~16x faster correlation via downsampling + parallel processing
%   - Memory: O(blockSize) frame storage instead of O(numFrames)
%   - Scalability: Handles sequences of any length without memory issues
%   - CPU Utilization: Near-linear speedup with number of cores during transform computation
%
% DEPENDENCIES:
%   - MATLAB Image Processing Toolbox (for imregcorr, imwarp, im2gray, imresize, imref2d)
%   - MATLAB Parallel Computing Toolbox (for parfor, parpool, gcp)
%
% USAGE EXAMPLE:
%   app_stabilizer_gradientCorrelation_par([], '/path/to/output', 30, 1, '/path/to/frames')
%   % Stabilizes PNG frames in '/path/to/frames' using frame 1 as reference
%   % Outputs 30fps video to '/path/to/output'
%
% LIMITATIONS:
%   - Translation-only transform cannot correct for rotation, scaling, or perspective distortion
%   - Assumes all frames are same size (reference frame size used for output)
%   - Works only with PNG input frames (hardcoded '*.png' pattern)
%   - May fail on scenes with very low gradient content (uniform regions)
%   - Requires sufficient overlap between frames for accurate alignment
%   - Best suited for small translational camera shake, not large motion
%
% CUSTOMIZATION OPTIONS:
%   - Downsampling factor can be adjusted (current: 0.25) - lower values = faster but less accurate
%   - Block size can be modified (current: 20) - larger blocks use more memory but may be faster
%   - Transform type could be changed from 'translation' to 'rigid' or 'affine' in imregcorr for more complex motion
%   - Number of parallel workers can be adjusted in parpool initialization
%
% NOTES FOR THE DEVELOPER:
%   - Parallel Processing: Uses parfor to parallelize transform computation. Ensure Parallel Computing Toolbox is available.
%   - Platform Compatibility: Automatically selects video codec based on OS (Motion JPEG AVI for Linux, MPEG-4 for others).
%   - Error Handling: No explicit try-catch blocks. imregcorr may fail on extremely low-contrast regions - consider adding error handling in production use.
%   - Memory Efficiency: Block-based approach ensures stable memory usage even for very long sequences (1000+ frames).



function app_stabilizer_gradientCorrelation_par(Frame_Data, outputFolder, fps, referenceFrame, inputFolder)
% This function stabilizes a video sequence using gradient-based correlation
% alignment with parallel processing for improved performance

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
    % STEP 3: LOAD AND PREPARE REFERENCE FRAME
    % ========================================================================
    fixed_image  = imread(fullfile(inputFolder, imageFiles(referenceFrame).name));
    fixed_gray   = im2gray(fixed_image);
    
    % Downsample reference frame to 25% for faster correlation computation
    fixed_small  = imresize(fixed_gray, 0.25);
    
    % Define output coordinate system based on reference frame size
    Rfixed_image = imref2d(size(fixed_image));
    
    % ========================================================================
    % STEP 4: PREPARE FRAMES FOR PARALLEL PROCESSING
    % ========================================================================
    % Exclude reference frame from processing (it doesn't need alignment)
    framesToProcess = setdiff(1:numFrames, referenceFrame);
    numToProcess    = length(framesToProcess);
    
    % ========================================================================
    % STEP 5: COMPUTE TRANSFORMS IN PARALLEL
    % ========================================================================
    % Calcola solo le trasformazioni in parallelo
    tempTforms = cell(1, numToProcess);
    
    parfor k = 1:numToProcess
        i            = framesToProcess(k);
        
        % Load current frame and downsample to 25%
        moving       = imread(fullfile(inputFolder, imageFiles(i).name));
        moving_small = imresize(im2gray(moving), 0.25);
        
        % Compute translation transform using gradient correlation on downsampled images
        tform_small  = imregcorr(moving_small, fixed_small, 'translation');
        
        % Rescale translation components from downsampled to full resolution
        tform_full   = tform_small;
        tform_full.T(3,1) = tform_small.T(3,1) / 0.25;
        tform_full.T(3,2) = tform_small.T(3,2) / 0.25;
        
        tempTforms{k} = tform_full;
    end
    
    % ========================================================================
    % STEP 6: REMAP TRANSFORMS TO ORIGINAL FRAME INDICES
    % ========================================================================
    % Rimappa su array indicizzato per frame
    allTforms = cell(1, numFrames);
    for k = 1:numToProcess
        allTforms{framesToProcess(k)} = tempTforms{k};
    end
    
    % ========================================================================
    % STEP 7: BUILD OUTPUT VIDEO PATH
    % ========================================================================
    % Build output video
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
        outputVideoName = [folderName '_stabilized_GRADIENT.avi'];
        profile = 'Motion JPEG AVI';
    else
        outputVideoName = [folderName '_stabilized_GRADIENT.mp4'];
        profile = 'MPEG-4';
    end
    
    % ========================================================================
    % STEP 8: INITIALIZE VIDEO WRITER
    % ========================================================================
    outputVideoPath = fullfile(outputFolder, outputVideoName);
    writer = VideoWriter(outputVideoPath, profile);
    writer.FrameRate = fps;
    
    % ========================================================================
    % STEP 9: WRITE VIDEO IN PARALLEL BLOCKS
    % ========================================================================
    % Scrivi il video a blocchi di 20 frame alla volta
    blockSize = 20;  % Process 20 frames at a time for memory efficiency
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
                blockFrames{j} = imwarp(moving, allTforms{i}, 'OutputView', Rfixed_image);
            end
        end
        
        % Write block to video sequentially
        for j = 1:n
            writeVideo(writer, blockFrames{j});
        end
    end
    
    % ========================================================================
    % STEP 10: FINALIZE VIDEO
    % ========================================================================
    close(writer);
    fprintf('Stabilized video saved as: %s\n', outputVideoPath);
end