USER MANUAL - ViFoSe (Video Foreground Segmentation)
<img width="2428" height="931" alt="image" src="https://github.com/user-attachments/assets/05e383de-3b36-4581-a596-24a8900e6ca8" />
EXECUTIVE SUMMARY
ViFoSe is a MATLAB application specialized in foreground segmentation of video sequences, developed at the University of Bologna. The platform integrates manual and automatic segmentation tools for the analysis and processing of video content in academic and professional settings.

1. INSTALLATION AND STARTUP
-System Prerequisites:
MATLAB R2020b or later
Image Processing Toolbox
8 GB RAM (16 GB recommended for high-resolution video)

-Startup Procedure:
Start the MATLAB environment
Execute the command: app = ViFoSe_1;
The graphical interface will initialize automatically

2. INTERFACE ARCHITECTURE
-Display Panels:
UIAxes (Left): Display of the preprocessed video
UIAxes2 (Center): Representation of the generated binary masks
UIAxes3 (Right): Preview of the output video with applied masks

-Command Structure:
🎥 DATA ACQUISITION MODULE
Load Video: Load video file (supported formats: MP4, AVI, MOV)
Load Project: Reconstruct a work session from a saved project


✂️ PREPROCESSING TOOLS
Crop ROI: Define a region of interest via rectangular selection
Frame Navigation: Inter-frame navigation controls (+/-, advanced slider)

🎨 MANUAL SEGMENTATION
Segment Foreground: Annotate foreground areas (green color)
Segment Background: Annotate background areas (red color)
Reset Segmentation: Selective reset of annotations

🤖 AUTOMATIC SEGMENTATION
Automatic Segmentation: Integration with the SAM framework
Automatic Alignment: Alignment via the STABA algorithm
Manual Alignment: Manual alignment with STABM
Load Automatic Binary Masks: Import pre-computed masks

💾 OUTPUT MANAGEMENT
Save Project: Export complete project
About Us: Development contact information

3. STANDARD OPERATING PROCEDURE
3.1 Initialization Phase:
Select "Load Video"
Choose the source video file
Wait for the frame extraction to complete (progress indicator)
Verify the correct display of the first frame in the three panels

3.2 Region of Interest Definition (Optional):
Click "Crop ROI"
Delimit the rectangular area of interest
Confirm the selection
The system will automatically apply the crop to all frames
Existing masks will be reconfigured to the new geometry

3.3 Manual Segmentation:
-Foreground Procedure:
Select "Segment Foreground"
Draw polylines on the objects of interest (green annotation)
Specify the temporal application interval
Confirm for multi-frame application

-Background Procedure:
Select "Segment Background"
Delineate background areas (red annotation)
Define the target frame interval
Apply the segmentation

3.4 Validation and Navigation:
Use the "Frame +/-" controls for sequential navigation
Use the slider for random access to frames
Monitor in real-time the effect of the masks in the three views

3.5 Process Automation:
-SAM Automatic Segmentation:
Activate "Automatic Segmentation"
Follow the SAM protocol in the dedicated interface
The generated masks will be imported automatically

-Loading External Masks:
Select "Load Automatic Binary Masks"
Locate the directory containing the binary masks
Specify the reference time interval
Masks will be imported as foreground layers


3.6 Exporting Results:
Execute "Save Project"
Select the destination directory
The system will generate:
[name]_preprocessedVideo.avi - Preprocessed video
[name]_binaryMask.avi - Binary masks
[name]_outputVideo.avi - Final composition

4. ADVANCED FEATURES
-Multiple Mask Management:
Support for multiple masks per frame
Temporal hierarchy: recent masks overwrite previous ones
Conflict management via chronological ordering

-Selective Reset:
Targeted deletion of masks in specific intervals
Preservation of work unaffected by changes

-Alignment Systems:
STABA: Automatic alignment for videos with camera motion
STABM: Manual correction of alignments

5. TROUBLESHOOTING
-Error Codes:
"No video loaded": A video must be loaded before processing
"Mask dimensions do not match": Mask size misalignment
Invalid ROI: Repeat the region selection procedure

-Operational Guidelines:
Define an initial ROI for performance optimization
Incremental project saving
Multi-frame verification before applying masks to large intervals

6. TECHNICAL SUPPORT
For technical assistance, bug reports, or feature requests:
Use the "About Us" panel
Contact the development team at the University of Bologna


ViFoSe - Video Foreground Segmentation Tool Department of Electrical, Electronic, and Information Engineering "Guglielmo Marconi" University of Bologna, Italy Copyright © 2025 - All rights reserved
<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/5b4ee328-7aa8-4cba-b6a0-e854f706b204" />
