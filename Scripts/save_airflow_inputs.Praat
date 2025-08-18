############################
# save_airflow_inputs.Praat
# Ryan Bennett, April 2023
# https://people.ucsc.edu/~rbennett/
# https://github.com/rbennett24/UCSC-Airflow-lab
############################


##########
# Praat script to:
# - Iterate through long files with associated TextGrids
# - Extract word-level chunks (audio + TextGrids) from labeled intervals.
# - Convert airflow channels to saved intensity objects.


################
form Process two-channel airflow files: save intervals to chunked wav, TextGrid, and Intensity files.
	
	comment Give the location of the input sound files and TextGrids:
		sentence rawFiles 

	comment Which IntervalTier in this TextGrid would you like to process?
		integer Tier 1
	
	comment Skip unlabeled intervals, and intervals labeled as silence or beginning in XXX?
		boolean Exclude_empty_labels 1
		
	comment Pitch floor for creation of Intensity objects:
	comment (Praat default = 100; lower => worse temporal resolution, but fewer spurious measurements)
		positive pitchFloor 200
		# 200 seems to work well
	
	comment Ignore repetitions with mask off?
		boolean maskcheck 1
	
	comment What tier labels mask on/off repetitions?
		integer maskTier 3
	
	comment What label is used to mark repetitions with the mask off?
		text masklabel Mask-Off
		
	comment If you've marked "nasal appendices" with a unique tag, what is it? (Leave blank if you didn't do this)
		text appendTag TN

	comment Do you want to merge nasal appendices with the preceding nasal vowel,
	comment or keep them separate?
		boolean mergeNasApp 0

	comment What tier labels segments?
		integer segTier 2
	
endform

# If the output folders don't exist, create them.
folder$ = rawFiles$ + "Extracted_files\"
createDirectory: folder$
intensfolder$ = folder$ + "\Intensity_tracks\"
createDirectory: intensfolder$

# Get the number of textgrids in the input folder
Create Strings as file list... filesTextGrid 'rawFiles$'*.TextGrid
numfile = Get number of strings

# Iterate through each of the TextGrids
select all
for k from 1 to numfile

	select Strings filesTextGrid

	# Select an individual TextGrid to work with (and convert to unicode)
	workingTGname$ = Get string... 'k'
	Read from file... 'rawFiles$'\'workingTGname$'
	gridname$ = selected$ ("TextGrid")
	Convert to Unicode

	# Select an individual sound to work with
	Read from file... 'rawFiles$'\'gridname$'.wav
	soundname$ = selected$ ("Sound")
	
	# Iterate through the textgrids and corresponding sound files.
	select TextGrid 'gridname$'
	numberOfIntervals = Get number of intervals... tier

	# Loop through all intervals in the selected tier of the TextGrid
	indexnumber = 0
	
	for interval from 1 to numberOfIntervals
		select TextGrid 'gridname$'
		intname$ = Get label of interval... tier interval
		
		if maskcheck = 1
			maskcheckname$ = Get label of interval... maskTier interval
		endif

		check = 0

		if (intname$ = "" or intname$ = " " or intname$ = "	" or intname$ = "sp" or intname$ = "sil" or left$(intname$, 3)="XXX") and exclude_empty_labels = 1
			check = 1
		endif
		
		if maskcheck = 1
			if maskcheckname$ = masklabel$
				check = 1
			endif
		endif

		if check = 0
			indexnumber = indexnumber + 1
		
			intervalstart = Get starting point... tier interval	
			intervalend = Get end point... tier interval

			# Extract sound
			select Sound 'soundname$'
			Extract part: 'intervalstart', 'intervalend', "rectangular", 1, "no"
			intervalSound$ = selected$ ("Sound")

			# Extract TextGrid
			select TextGrid 'gridname$'
			Extract part: 'intervalstart', 'intervalend', "no"
			intervalTG$ = selected$ ("TextGrid")
			
			# Merge nasal appendix intervals if desired
			if ("'appendTag$'" <> "" and 'mergeNasApp' = 1)
				select TextGrid 'intervalTG$'
				segNumberOfIntervals = Get number of intervals... segTier
				for segInt from 1 to segNumberOfIntervals
					segname$ = Get label of interval... segTier segInt
					if 'segname$' = 'appendTag$'
						# Nuke the label
						Set interval text: segTier, segInt, ""
						
						# Merge the intervals
						# Remove the boundary between the now-empty interval and the preceding 
						# interval.
						Remove left boundary: segTier, segInt
						
						# Adjust the relevant counters, since you've now restructured the TextGrid itself by
						# eliminating an interval.
						segNumberOfIntervals = 'segNumberOfIntervals'-1
						segInt = 'segInt'-1
					endif
				endfor
			endif

			# Extract Intensity for each channel.
			select Sound 'intervalSound$'
			Extract all channels
			select Sound 'intervalSound$'_ch1
			To Intensity: 'pitchFloor', 0, "no"
			intervalIntense1$ = selected$ ("Intensity")
			select Sound 'intervalSound$'_ch2
			To Intensity: 'pitchFloor', 0, "no"
			intervalIntense2$ = selected$ ("Intensity")
			select Sound 'intervalSound$'_ch1
			plus Sound 'intervalSound$'_ch2
			Remove

			# Remove non-ASCII characters and unwanted punctuation from filenames
			# and interval names.
			# û ñ ' á í ú ó é	
			filename$ = replace$(gridname$,"û","u1",0)
			filename$ = replace$(filename$,"ñ","n1",0)
			filename$ = replace$(filename$,"á","a8",0)
			filename$ = replace$(filename$,"é","e8",0)
			filename$ = replace$(filename$,"í","i8",0)
			filename$ = replace$(filename$,"ó","ó8",0)
			filename$ = replace$(filename$,"ú","u8",0)
			filename$ = replace$(filename$,"'","7",0)
			
			filename$ = replace$(filename$,".","",0)
			filename$ = replace$(filename$,"!","",0)
			filename$ = replace$(filename$,"?","",0)
						
			
			intname$ = replace$(intname$,"û","u1",0)
			intname$ = replace$(intname$,"ñ","n1",0)
			intname$ = replace$(intname$,"á","a8",0)
			intname$ = replace$(intname$,"é","e8",0)
			intname$ = replace$(intname$,"í","i8",0)
			intname$ = replace$(intname$,"ó","ó8",0)
			intname$ = replace$(intname$,"ú","u8",0)
			intname$ = replace$(intname$,"'","7",0)
			
			intname$ = replace$(intname$,".","",0)
			intname$ = replace$(intname$,"!","",0)
			intname$ = replace$(intname$,"?","",0)
			
			
			# Output file names
			
			# Add leading zeros
			if indexnumber < 10
				indexnumber$ = "00'indexnumber'"
			elif (indexnumber < 100 and indexnumber >= 10)
				indexnumber$ = "0'indexnumber'"
			else
				indexnumber$ = "'indexnumber'"
			endif
			
			intervalfile$ = "'folder$'" + "'filename$'" + "_'intname$'" + "_" + "'indexnumber$'" + ".wav"
			intervalTGfile$ = "'folder$'" + "'filename$'" + "_'intname$'" + "_" + "'indexnumber$'" + ".TextGrid"
			intervalIntense1file$ = "'intensfolder$'" + "'filename$'" + "_'intname$'" + "_" + "'indexnumber$'_ch1" + ".Intensity"
			intervalIntense2file$ = "'intensfolder$'" + "'filename$'" + "_'intname$'" + "_" + "'indexnumber$'_ch2" + ".Intensity"
			

			# If you want to avoid overwriting files
			# if not fileReadable (intervalfile$)
			# endif

			# Save files.
			# Sound
			select Sound 'intervalSound$'
			Write to WAV file: "'intervalfile$'"
			Remove

			# TextGrid
			select TextGrid 'intervalTG$'
			Convert to Unicode
			Save as text file... 'intervalTGfile$'
			Remove
			
			# Intensity
			select Intensity 'intervalIntense1$'
			Save as text file... 'intervalIntense1file$'
			Remove
			select Intensity 'intervalIntense2$'
			Save as text file... 'intervalIntense2file$'
			Remove

		endif
	endfor

	select TextGrid 'gridname$'
	plus Sound 'soundname$'
	Remove
endfor

select all
Remove