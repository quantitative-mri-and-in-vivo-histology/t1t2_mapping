#!/usr/bin/env python3
#
#  bids_layout.py
#  
#  Copyright 2024 Frank <frank@frank-LuebeckLaptop>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#  


import sys
import json
from bids import BIDSLayout

bids_info = []

if len(sys.argv) > 1:
	dataset_path = sys.argv[1]
else:
	print("Error: no path was given or path is invalid");
	sys.exit(1)

layout = BIDSLayout(dataset_path)
# Get all subjects
subjects = layout.get_subjects()

results = []

for subject in subjects:
	sessions = layout.get_sessions(subject=subject)
	if sessions:  # Only add subjects with existing sessions
		for session in sessions:
			valid_runs = layout.get(return_type='id', subject=subject, session=session, suffix='T2w',
                                    target="run", part="mag", extension="nii.gz")
			runs = valid_runs

			if len(runs) == 0:
				runs = [None]

			# Create a dictionary to store the results
			results.append({
                'subject': subject,
                'session': session,
                'runs': runs
            })
            
# Output the result as JSON (this will be captured in the bash script)
with open('sub_ses_run_description.json', 'w') as outfile:
    json.dump(results, outfile, indent=4)
