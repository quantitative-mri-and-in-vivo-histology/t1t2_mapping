#!/bin/bash
set -e
########################################################################
# Save inputs #
# Insert as input 1 the corresponding main path, until sub-XXX and 
# derivatives.
# Example:
# ./T1T2_estimation_UKL.sh /path/data
########################################################################

function prompt_user_to_skip() {
	while true; do
		read -p "The following ${SubSess} for run ${run} dataset will be analysed. Do you want to skip this analysis?(y/n): " yn
		case $yn in
			[Yy]*) 
				echo "Skipping analysis"
				return 1
				;;
			[Nn]*) 
				echo "Starting analysis" 
				return 0
				;;
			*) 
				echo "Please answer yes (y) or no (n)"
				;;
		esac
	done
}

MainPath="$1"

# Before executing this line, please install sudo apt-get install jq
$(python3 bids_layout.py "$MainPath")

# Load the JSON file and iterate over each subject/session/run
json_file="sub_ses_run_description.json"

# Use jq to parse the JSON
combinations=$(jq -r '.[] | "\(.subject) \(.session) \(.runs[])"' "$json_file" | sort -u)

#IFS=$'\n'  # Set the internal field separator to newline to handle spaces properly
for combination in "${combinations[@]}"; do
	# Split the combination into subject, session, and run
	IFS=' ' read -r subject session run <<< "$combination"
	
	SubSess="sub-${subject}/ses-${session}"		
	Anatomy_directory="${MainPath}/${SubSess}/anat"
			
	if [ ! -d "${Anatomy_directory}" ]; then
		echo "Subject: ${subject}, session: ${session} data does not exist. Skipping..."
		continue
	else
		echo "Checking into subject: ${subject}, session: ${session} dataset..."
	fi
	
	if [ "$run" != "null" ]; then
		SubSess="$SubSess/run-${run}"
	fi
			
	B1_directory_SPM="${MainPath}/derivatives/SPM/${SubSess}/fmap"
	B1_directory_Siemens="${MainPath}/derivatives/SiemensHealthineers/${SubSess}/fmap"
	Output_directory_fsl="${MainPath}/derivatives/FSL/${SubSess}"
	mkdir -p "${Output_directory_fsl}"
	Output_directory_qi="${MainPath}/derivatives/QUIT/${SubSess}"
	mkdir -p "${Output_directory_qi}"
	
	if prompt_user_to_skip; then
		echo "Starting analysis..."
	else
		continue
	fi

	###########################################################################
	# Find all SPGR and SSFP volumes #
	# All files are located in one folder. In BIDS default conversion from 
	# bidscoin, the SPGR were defined as _T1w and the SSFP as _T2w. Extra
	# information as flip angle and RF increment were added (for now) in the
	# acq-<value>, i.e. t2Ssfp2[A2 or A13 for T1w and A49RF180, A49RF0 and 
	# A12RF180 for T2w].
	###########################################################################
	if [ "$run" != "null" ]; then
		spgr_ssfp_files=($(find "${Anatomy_directory}" -type f \( -name "*acq-t2Ssfp*A*_run-$run*.nii.gz" \)))
	else
		spgr_ssfp_files=($(find "${Anatomy_directory}" -type f \( -name "*acq-t2Ssfp*A*.nii.gz" \)))
    fi
	
	filename=$(basename "${spgr_ssfp_files[1]}")
	if [[ "$filename" == *acq-t2Ssfp1* || "$filename" == *acq-t2Ssfp2* ]]; then
		ApplyScaling=true
	elif [[ "$filename" == *acq-t2Ssfp3* ]]; then
		ApplyScaling=false
	else
		ApplyScaling="undefined"  # Optional: for cases that don't match any pattern
	fi
								
	for file in "${spgr_ssfp_files[@]}"; do
		filename=$(basename "$file")
		# Check if the file ends with '_T1w.nii.gz'
		if [[ "$filename" == *"_T1w.nii.gz" ]]; then
			# Use regex to extract the number after 'acq-t2Ssfp2A'
			if [[ "$filename" =~ acq-t2Ssfp[123]A([0-9]+) ]]; then
				number="${BASH_REMATCH[1]}"  # Extracted number from regex match
				# Here, you can set your condition for the number (e.g., greater than 2)
				if (( "$number" > 10 )); then
					RefVolumeFile="$file"
					echo "The reference volume for registration is ${RefVolumeFile}"
					break
				fi
			fi
		fi
	done

	###########################################################################
	# Load B1map and B1ref volumes and register to reference volume #
	# It assumes that these maps were previously calculated and located in the
	# bids-format folder derivatives/pipeline(SPM/Siemens/others)/sub-XXX/ses-XXX/fmap
	###########################################################################
	flirt_ref="RefVolBrain"

	#1. Mask reference volume
	bet "${RefVolumeFile}" "${Output_directory_fsl}/${flirt_ref}" -R -f 0 -g 0 -m #This BET is actually not doing any BET at all.
	echo "Finished FSL BET on reference volume ${RefVolumeFile}"

	#2. Register B1 anatomical volume to reference and then, the transformation
	# matrix to the B1 map. Depends if exists the TFL or SPM-based B1 map
	afi2ref="B1anat2RefVol.mat"

	if [ -d "${B1_directory_SPM}" ]; then
		B1anat=$(find ${B1_directory_SPM} -type f -name "*ref.nii")
		B1map=$(find ${B1_directory_SPM} -type f -name "*map.nii")
		scaleval=100
	elif [ -d "${B1_directory_Siemens}" ]; then
		B1anat=$(find ${B1_directory_Siemens} -type f -name "*acq-anat*TB1TFL.nii.gz")
		B1map=$(find ${B1_directory_Siemens} -type f -name "*acq-famp*TB1TFL.nii.gz")
		
		#Get the flip angle from the corresponding json file
		json_b1map="${B1map%%.*}"
		flipangle_rfmap=$(jq 'select(.FlipAngle != null) | .FlipAngle' "${json_b1map}.json")
		scaleval=$(echo ""${flipangle_rfmap}" * 10" | bc )
	else
		echo "B1 map non-existant - please have a pre-calculated B1map."
	fi

	flirt -cost mutualinfo -dof 6 -interp trilinear -in "${B1anat}" -ref "${Output_directory_fsl}/${flirt_ref}" -omat "${afi2ref}"
	flirt -interp sinc -in "${B1map}" -ref "${Output_directory_fsl}/${flirt_ref}" -applyxfm -init "${afi2ref}" -out "${Output_directory_fsl}/B1map_Reg.nii"
	fslmaths "${Output_directory_fsl}/B1map_Reg.nii" -div "${scaleval}" "${Output_directory_fsl}/B1map_Reg_Norm.nii"
	echo "Applied transformation and interpolated B1 map"

	#3. Register volumes to reference, apply scaling and do TGV to all volumes.
	for file in "${spgr_ssfp_files[@]}"; do
		filename=$(basename "$file")
		filename_out="${filename%%.*}"

		flirt -cost mutualinfo -dof 6 -interp trilinear -in "$file" -ref "${Output_directory_fsl}/${flirt_ref}" -omat "${Output_directory_fsl}/${filename_out}_Reg_Mat"
		flirt -interp sinc -in "$file" -ref "${Output_directory_fsl}/${flirt_ref}" -applyxfm -init "${Output_directory_fsl}/${filename_out}_Reg_Mat" -out "${Output_directory_fsl}/${filename_out}_Reg"	

		filename_scale_tgv=$(basename "${Output_directory_fsl}/${filename_out}_Reg")
		if [ "$ApplyScaling" = true ]; then
			echo "Scaling is applied before performing TGV"
			if [[ "$filename_scale_tgv" == *"_T1w_"* ]]; then
				scaleval=3
				echo "Scale value to apply for this file ${filename} is 3 (SPGR file)"
			else
				scaleval=7
				echo "Scale value to apply for this file ${filename} is 7 (SSFP file)"
			fi
			
			fslmaths "${Output_directory_fsl}/${filename_out}_Reg" -div "$scaleval" "${Output_directory_fsl}/${filename_out}_Reg_ReScaled"
			qi tgv --alpha=1e-5 --out="${Output_directory_qi}/${filename_out}_Reg_ReScaled_TGV.nii.gz" "${Output_directory_fsl}/${filename_out}_Reg_ReScaled.nii.gz"    
		else
			echo "Scaling is applied before performing TGV"
			qi tgv --alpha=1e-5 --out="${Output_directory_qi}/${filename_out}_Reg_TGV.nii.gz" "${Output_directory_fsl}/${filename_out}_Reg.nii.gz"
		fi

		echo "Applied transformation, scaled (if so) and TGV'ed to ${filename}"
	done

	######################
	# JSR fit using QUIT #
	######################
	spgr_tgv_files=$(find ${Output_directory_qi} -type f -name "*T1w*TGV.nii.gz")
	ssfp_tgv_files=$(find ${Output_directory_qi} -type f -name "*T2w*TGV.nii.gz")

	fslmerge -t "${Output_directory_qi}/all_SPGR.nii.gz" ${spgr_tgv_files}
	fslmerge -t "${Output_directory_qi}/all_SSFP.nii.gz" ${ssfp_tgv_files}
	maskfile=$(find ${Output_directory_fsl} -type f -name "*mask.nii.gz")

	echo "Before executing quit JSR analysis, check if the input JSON file is correct..."
	echo "List of files merged: "
	for files in "${spgr_tgv_files[@]}"; do
		echo "${files}"
	done
	for files in "${ssfp_tgv_files[@]}"; do
		echo "${files}"
	done
	echo "If everything is correct, press Enter to continue..."
	read
	echo -e "Ready to run the last bit..."

	qi jsr "${Output_directory_qi}/all_SPGR.nii.gz" "${Output_directory_qi}/all_SSFP.nii.gz" --B1="${Output_directory_fsl}/B1map_Reg_Norm.nii" --mask="${maskfile}" --npsi=6 --out="${Output_directory_qi}/" < input.json
	echo "Finished JSR fit"
	
	echo "Finalised ${SubSess} for run ${run}"	
done
