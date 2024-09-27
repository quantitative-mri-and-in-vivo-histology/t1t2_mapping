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

if len(sys.argv) > 1:
	dataset_path = sys.argv[1]
else:
	print("Error: no path was given or path is invalid");
	sys.exit(1)

layout = BIDSLayout(dataset_path)

subjects = layout.get_subjects()

for sub in subjects:
	sessions = layout.get_sessions(subjects = sub)
	for ses in sessions:
		runs = layout.get_runs(subject = sub, session = ses)
		
		info = {
			"subject": subjects,
			"session": sessions,
			"runs"; [run['run'] for run in runs]
		}
		bids_info.append(info)

#with open('bids_info.json', 'w') as json_file:
#	json.dumps(bids_info, json_file, indent=4)

print(json.dumps(bids_info, json_file, indent=4))
