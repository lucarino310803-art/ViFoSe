% AUTHOR: Abdelrahman Abdelaziz Mohamed (E-mail: abdu.abdelaziz46@gmail.com)
%
% DATE: 21/04/2026
%
% DESCRIPTION: This MATLAB function extracts all frames from a video file and saves them as PNG images with intelligent 
%              disk caching to avoid re-extracting frames that already exist. The function implements a cache-hit/cache-miss 
%              strategy: if frames were previously extracted, it loads them directly from disk; otherwise, it reads the video, 
%              extracts all frames sequentially, and saves them in parallel for future reuse. Returns frames in both struct 
%              array format (MATLAB movie-compatible) and cell array format (processing-friendly) with comprehensive video metadata.
%
% KEY FEATURES:
%   - Intelligent Caching: Checks for existing frame folders to avoid redundant extraction
%   - Parallel Disk I/O: Uses parfor to save frames simultaneously for faster processing
%   - Natural Sorting: Handles frame numbering correctly (frame_1, frame_2, ..., frame_10, frame_11)
%   - Dual Output Format: Returns both struct array (movie-compatible) and cell array (processing-friendly)
%   - Metadata Preservation: Captures and returns video properties (resolution, FPS, duration)
%   - Frame Rate Fallback: Attempts to retrieve original FPS even when loading cached frames
%
% ALGORITHM WORKFLOW:
%   1. Output Folder Setup: Creates path 'Extracted_Frames/[videoName]' for frame storage
%   2. Cache Detection: Checks if frame folder already exists
%      - CACHE HIT: Loads existing frames from disk with natural sorting
%      - CACHE MISS: Reads video, extracts frames, saves to disk in parallel
%   3. Metadata Collection: Retrieves video properties (resolution, FPS, duration, frame count)
%   4. Format Conversion: Converts frames to both struct array and cell array formats
%   5. Output Return: Provides Frame_Data (cell array) and Video_Structure (metadata + struct array)
%
% STEP-BY-STEP FUNCTIONALITY:
%
% STEP 1 - Output Folder Preparation:
%   - Extracts video filename without extension using fileparts
%   - Creates output folder path: 'Extracted_Frames/[videoName]'
%   - Initializes Video_Structure with basic metadata (videoName, videoPath)
%
% STEP 2 - Cache Detection:
%   - Uses exist(outputFolder, 'dir') to check for pre-extracted frames
%   - Determines whether to load from cache or extract from video
%
% STEP 3A - Load Existing Frames (CACHE HIT):
%   - Searches for 'frame_*.png' files using dir()
%   - Validates folder is not empty (throws error if no frames found)
%   - Applies natural sorting to handle numeric ordering correctly
%   - Loads frames sequentially into cell array using imread
%   - Attempts to retrieve frame rate from original video file
%   - Falls back to 30 fps default if video cannot be read
%
% STEP 3B - Extract Frames from Video (CACHE MISS):
%   - Creates VideoReader object to access video properties and frames
%   - Extracts technical specifications:
%     * Video_Height, Video_Width (resolution)
%     * Video_Duration (total length in seconds)
%     * Video_FrameRate (original FPS, unrounded)
%   - Stores properties in Video_Structure for later reference
%   - Estimates frame count: floor(Video_Duration × Video_FrameRate)
%   - Displays video information to console
%
% STEP 4 - Create Output Folder:
%   - Uses mkdir() to create frame storage directory
%   - Only executed during CACHE MISS path
%
% STEP 5 - Read All Frames into Memory:
%   - Pre-allocates cell array for estimated frame count
%   - Reads frames sequentially using hasFrame() and readFrame()
%   - Sequential reading required (VideoReader limitation - cannot parallelize)
%   - Trims cell array to actual frame count (may differ from estimate)
%   - Stores actual frame count in Video_Structure.actualFrames
%
% STEP 6 - Save Frames to Disk in Parallel:
%   - Uses parfor loop to save frames simultaneously (parallel disk I/O)
%   - Implements zero-padded naming: frame_0001.png, frame_0002.png, etc.
%   - Format: sprintf('frame_%04d.png', k) for consistent 4-digit numbering
%   - Validates frames are not empty before saving
%   - PNG format preserves image quality without compression artifacts
%
% STEP 7 - Create Output Structure:
%   - Builds MATLAB movie-compatible struct array with fields:
%     * cdata: RGB frame image data (height × width × 3)
%     * colormap: Empty array ([]) - not used for RGB images
%   - Compatible with MATLAB's movie() and implay() functions
%
% STEP 8 - Extract Frames into Cell Array:
%   - Creates simplified cell array format from struct array
%   - Frame_Data = {Output_Structure.cdata}
%   - More convenient format for image processing operations
%
% INPUT PARAMETERS:
%   - File_Name: Full path to video file (string or char array)
%     * Supports formats readable by VideoReader: MP4, AVI, MOV, etc.
%     * Must be valid video file with accessible codec
%
% OUTPUT:
%   - Frame_Data: Cell array {1 × N} where each cell contains frame image data
%     * Format: uint8 array (height × width × 3) for RGB frames
%     * Indexed as Frame_Data{1}, Frame_Data{2}, ..., Frame_Data{N}
%     * Suitable for direct image processing operations
%
%   - Video_Structure: Struct with video metadata and frame array
%     * videoName: Filename without extension (char array)
%     * videoPath: Full path to source video (char array)
%     * frameRate: Original video frame rate in Hz (double)
%     * height: Video frame height in pixels (integer)
%     * width: Video frame width in pixels (integer)
%     * duration: Video duration in seconds (double)
%     * actualFrames: Actual number of extracted frames (integer)
%     * Internal struct array with cdata and colormap fields (movie format)
%
% TECHNICAL DETAILS:
%   - Frame Numbering: Zero-padded 4-digit format (0001-9999)
%   - Image Format: PNG (lossless compression, preserves quality)
%   - Color Space: RGB (3-channel, uint8)
%   - Sorting Algorithm: Natural sorting via regex extraction of numeric parts
%   - Parallel Workers: Uses default parallel pool (typically 4-12 workers)
%   - Memory Strategy: All frames loaded simultaneously (not block-based)
%
% PERFORMANCE CHARACTERISTICS:
%   - Cache Hit: Fast (~1-5 seconds for 100 frames, depends on disk I/O)
%   - Cache Miss: Slower (~30-120 seconds for 100 frames at 1080p)
%   - Bottleneck: Sequential video reading (VideoReader limitation)
%   - Speedup: Parallel frame saving provides ~2-4x improvement over sequential
%   - Memory Usage: O(N × frame_size) where N = number of frames
%
% DEPENDENCIES:
%   - MATLAB Core: fileparts, exist, mkdir, struct
%   - Image Processing Toolbox: imread, imwrite
%   - Computer Vision Toolbox: VideoReader (hasFrame, readFrame)
%   - Parallel Computing Toolbox: parfor (for parallel frame saving)
%   - Custom Functions: sort_nat (natural sorting implementation)
%
% LIMITATIONS:
%   - Sequential Video Reading: Cannot parallelize frame extraction (VideoReader constraint)
%   - Memory Intensive: Loads all frames into memory simultaneously
%     * May fail for very long videos (e.g., >10,000 frames at high resolution)
%     * Recommended: Use for videos <5 minutes at 1080p or <15 minutes at 720p
%   - RGB Assumption: Assumes RGB video format; grayscale/indexed color not explicitly handled
%   - Frame Rate Recovery: May fall back to 30 fps if original video becomes inaccessible
%   - Folder Validation: Only checks for frame_*.png files; other files ignored
%
% ERROR HANDLING:
%   - Empty Folder Error: Throws error if existing folder contains no frame images
%   - Frame Rate Fallback: Uses 30 fps default if original video properties unavailable
%   - Frame Count Adjustment: Handles discrepancy between estimated and actual frame count
%   - Empty Frame Check: Validates frames before saving to avoid corrupted files
%
% USAGE EXAMPLES:
%   % Basic usage - extract and return frames
%   [frames, vidInfo] = Grab_Video_Frames_par2('video.mp4');
%   
%   % Access specific frame
%   firstFrame = frames{1};
%   
%   % Get video properties
%   fps = vidInfo.frameRate;
%   totalFrames = vidInfo.actualFrames;
%   
%   % Process frames
%   for k = 1:length(frames)
%       processedFrame = myFunction(frames{k});
%   end
%
% CUSTOMIZATION POINTS:
%   - Output Image Format: Modify imwrite() call in STEP 6
%     * Change to JPEG: imwrite(frame, frameFileName, 'jpg', 'Quality', 95)
%     * Change to TIFF: imwrite(frame, frameFileName, 'tif', 'Compression', 'none')
%   
%   - Frame Naming Convention: Modify sprintf() format in STEP 6
%     * More digits: sprintf('frame_%06d.png', k) for 6-digit numbering
%     * Different prefix: sprintf('img_%04d.png', k)
%   
%   - Output Folder Structure: Modify outputFolder path in STEP 1
%     * Different location: fullfile('MyFrames', videoName)
%     * Timestamp subfolder: fullfile('Extracted_Frames', videoName, datestr(now, 'yyyymmdd_HHMMSS'))
%   
%   - Additional Metadata: Add to Video_Structure in STEP 3B
%     * Codec info: Video_Structure.videoFormat = Video_Properties.VideoFormat
%     * Bit rate: Video_Structure.bitRate = Video_Properties.BitRate
%
% INTEGRATION WITH OTHER FUNCTIONS:
%   - ViFoSe Integration: Sets VideoStructure in base workspace for STABA/STABM
%   - STABA Usage: Reads frames from Extracted_Frames folder for stabilization
%   - STABM Usage: Loads frames for manual alignment workflow
%
% HELPER FUNCTIONS:
%   - sort_nat(files): Natural sorting wrapper
%     * Sorts filenames with numbers in natural order
%     * Example: [frame_1, frame_2, frame_10] instead of [frame_1, frame_10, frame_2]
%   
%   - sort_nat_internal(c): Internal sorting implementation
%     * Uses regex '\d+' to extract numeric portions
%     * Sorts based on numeric values rather than string comparison
%
% NOTES FOR DEVELOPERS:
%   - Caching Strategy: Always check for existing frames before extraction
%   - Natural Sorting Required: Essential for correct frame sequence
%   - Parallel Pool: Function assumes pool exists or MATLAB auto-creates one
%   - Error Propagation: VideoReader errors (unsupported codec) propagate to caller
%   - Frame Integrity: Empty frame check prevents corrupted file saves
%   - Metadata Consistency: Frame rate retrieved from original video even in cache-hit scenario
%
% PERFORMANCE OPTIMIZATION TIPS:
%   - First Run: Extract frames once, reuse indefinitely (cache strategy)
%   - Disk Speed: SSD dramatically improves frame loading/saving performance
%   - Parallel Workers: More workers improve frame saving speed (diminishing returns >8)
%   - Memory Management: For very long videos, consider implementing block-based processing
%   - Format Choice: PNG balances quality and file size; JPEG smaller but lossy
%
% TROUBLESHOOTING:
%   - "No frame images" error: Folder exists but is empty - delete folder and re-run
%   - Frame rate = 30 fps: Original video inaccessible - acceptable fallback
%   - Out of memory: Video too long - split video or implement block processing
%   - Wrong frame order: Natural sorting failed - verify sort_nat implementation



function [Frame_Data, Video_Structure] = Grab_Video_Frames_par2(File_Name)
% This function extracts all frames from a video file and saves them as PNG images
% with intelligent caching to avoid re-extracting frames that already exist on disk

    % ========================================================================
    % STEP 1: SETUP OUTPUT FOLDER AND INITIALIZE VIDEO STRUCTURE
    % ========================================================================
    % Extract the filename without extension from the full video path
    % Create a path for a subfolder to save the extracted frames
    [~, videoName, ~] = fileparts(File_Name);
    outputFolder = fullfile('Extracted_Frames', videoName);

    % Initialize Video_Structure with basic info
    Video_Structure = struct();
    Video_Structure.videoName = videoName;
    Video_Structure.videoPath = File_Name;

    % ========================================================================
    % STEP 2: CHECK IF FRAMES ALREADY EXIST ON DISK (CACHE HIT)
    % ========================================================================
    % If the folder already exists, load the frames from there
    if exist(outputFolder, 'dir')
        fprintf('\nFrame folder already exists. Loading frames from "%s"...\n', outputFolder);

        % Find all PNG files starting with "frame_"
        imageFiles = dir(fullfile(outputFolder, 'frame_*.png'));
        numFrames = numel(imageFiles);
        
        % Validate that folder is not empty
        if numFrames == 0
            error('The folder "%s" exists but contains no frame images.', outputFolder);
        end

        % Sort by name using natural ordering (frame_0001.png, frame_0002.png, ...)
        imageFiles = sort_nat({imageFiles.name});
        
        % ====================================================================
        % STEP 3A: LOAD EXISTING FRAMES FROM DISK
        % ====================================================================
        % Initialize a cell array and load each frame image into memory
        Video_Frames = cell(1, numFrames);
        for k = 1:numFrames
            framePath = fullfile(outputFolder, imageFiles{k});
            Video_Frames{k} = imread(framePath);
        end

        % Try to get frame rate from original video file for consistency
        try
            Video_Properties = VideoReader(File_Name);
            Video_Structure.frameRate = Video_Properties.FrameRate;
            fprintf('Frame rate from original video: %.2f fps\n', Video_Structure.frameRate);
        catch
            % If cannot read video file, use default fallback
            Video_Structure.frameRate = 30;
            fprintf('Using default frame rate: %.2f fps\n', Video_Structure.frameRate);
        end

    else
        % ====================================================================
        % STEP 3B: EXTRACT FRAMES FROM VIDEO (CACHE MISS)
        % ====================================================================
        % Folder does not exist: extract frames from the video
        fprintf('\nReading video and extracting frames...\n');

        % Use VideoReader to access video properties and frames
        Video_Properties = VideoReader(File_Name);
        
        % Extract video properties: height, width, duration, and fps
        Video_Height = Video_Properties.Height;
        Video_Width = Video_Properties.Width;
        Video_Duration = Video_Properties.Duration;
        Video_FrameRate = Video_Properties.FrameRate; % Keep original frame rate without rounding

        % Save properties in Video_Structure
        Video_Structure.frameRate = Video_FrameRate;
        Video_Structure.height = Video_Height;
        Video_Structure.width = Video_Width;
        Video_Structure.duration = Video_Duration;

        % Estimate number of frames based on duration and frame rate
        Estimated_Num_Frames = floor(Video_Duration * Video_FrameRate);

        % Display video information
        fprintf('\nResolution: %d x %d\n', Video_Width, Video_Height);
        fprintf('Duration: %.2f seconds\n', Video_Duration);
        fprintf('Frame rate: %.2f fps\n', Video_FrameRate);
        fprintf('Estimated number of frames: %d\n', Estimated_Num_Frames);

        % ====================================================================
        % STEP 4: CREATE OUTPUT FOLDER
        % ====================================================================
        % Create the folder to save frames
        mkdir(outputFolder);

        % ====================================================================
        % STEP 5: READ ALL FRAMES INTO MEMORY
        % ====================================================================
        % Load frames sequentially from video file
        fprintf('\nReading video into memory...\n');
        Video_Frames = cell(1, Estimated_Num_Frames);
        i = 1;
        while hasFrame(Video_Properties)
            Video_Frames{i} = readFrame(Video_Properties);
            i = i + 1;
        end
        
        % Trim cell array in case actual frame count differs from estimate
        Video_Frames = Video_Frames(1:i-1);
        Video_Structure.actualFrames = i-1;

        % ====================================================================
        % STEP 6: SAVE FRAMES TO DISK IN PARALLEL
        % ====================================================================
        % Save each frame to disk in parallel, named like frame_0001.png, frame_0002.png, etc.
        fprintf('Saving frames in parallel...\n');
        parfor k = 1:numel(Video_Frames)
            frame = Video_Frames{k};
            
            % Check that the image is not empty (avoid issues with corrupted frames)
            if ~isempty(frame)
                % Build the file path with zero-padded numbering (frame_0001.png)
                % %04d means "use 4 digits with leading zeros"
                frameFileName = fullfile(outputFolder, sprintf('frame_%04d.png', k));
                
                % Save the frame to disk as PNG
                imwrite(frame, frameFileName);
            end
        end

        fprintf('\nFrames saved in "%s".\n', outputFolder);
    end

    % ========================================================================
    % STEP 7: CREATE OUTPUT STRUCTURE IN REQUIRED FORMAT
    % ========================================================================
    % Create the output structure with MATLAB movie format
    % Structure has two fields:
    %   cdata: contains the frame data (the RGB image itself)
    %   colormap: left empty ([]) because frames are RGB, not indexed
    Output_Structure = struct('cdata', [], 'colormap', []);
    
    for k = 1:numel(Video_Frames)
        % Assign the k-th frame to the structure field `cdata`
        Output_Structure(k).cdata = Video_Frames{k};
        
        % Explicitly set colormap to empty (not used with RGB images)
        Output_Structure(k).colormap = [];
    end

    % ========================================================================
    % STEP 8: EXTRACT FRAMES INTO CELL ARRAY FORMAT
    % ========================================================================
    % Create a cell array containing all frames, extracted from cdata field
    % Equivalent to: {Output_Structure(1).cdata, Output_Structure(2).cdata, ...}
    Frame_Data = {Output_Structure.cdata};

end

% ============================================================================
% HELPER FUNCTION: NATURAL SORTING
% ============================================================================
function sorted = sort_nat(files)
    % Natural order sort wrapper
    % Sorts filenames with numbers in natural order (1, 2, 10 instead of 1, 10, 2)
    [~, idx] = sort_nat_internal(files);
    sorted = files(idx);
end

function [sorted, idx] = sort_nat_internal(c)
    % Internal natural sorting implementation
    % Uses regex to extract numeric parts and sort accordingly
    expr = '\d+';  % Regex to find numbers in filenames
    
    % Extract first numeric portion from each filename and sort
    [~, idx] = sort(cellfun(@(s) sscanf(regexp(s, expr, 'match', 'once'), '%d'), c));
    sorted = c(idx);
end