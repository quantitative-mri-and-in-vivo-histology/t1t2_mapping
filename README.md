# T1 and T2 mapping from Kings College's protocol.

This bash was adapted from the original bash created by David Leit~ao at King's. 

To make this code to run is advisable that:
1. Your nifti data is sorted in BIDS convention, i.e. (any other previous tree folder) > sub-XXX > ses-XXX > anat
2. The B1+ and B1 anatomical maps are previously estimated, either by SPM (using the hMRI toolbox) or previously estimated by Siemens. These maps should be located (also in BIDS convention) in: derivatives > [SPM/Siemens/Others] > sub-XXX > ses-XXX > fmap
3. The code is bash-based (Ubuntu 24.04 - T1T2_estimation_UKL.sh) but requires of a python code (bids_layout.py) to run properly; therefore:
   a. Required packages: python >= 3.0, quit software (from https://github.com/spinicist/QUIT), pybids and FSL.
   b. The main code (the bash code) can run either in conda environment or normal environment.
4. To run the code, write in bash: ./T1T2_estimation_UKL.sh (any other previous tree folder - see point 1). The first input helps the .py code to look through all the subjects, sessions and runs.
