readIntensityTrack<-function(filename){
  
  # Verify that the file exists and can be found:
  
  if (file.exists(filename)==F){
    print(paste(filename,"cannot be found! Stopping script readIntensityTrack() from readIntensity.R."))
    {stop()}
  }
  
  # Some techniques taken from Kohlberger & Stewart's (2014) 'Intensity.R' script
  # https://scholarspace.manoa.hawaii.edu/bitstreams/c8d8325c-17b7-4623-b728-4646c641d582/download
  
  # 'filename' should be a Praat .Intensity file
  intensityFile <- read.table(filename, header=T, sep="\t", encoding="UTF-8")
  
  # Get time of first sample frame, and the size (in seconds) of each frame step.
  startStep <- as.numeric(str_replace(intensityFile[which(!is.na(str_extract(intensityFile[,1],"x1 = \\d+"))),],"x1 = ",""))
  stepSize <- as.numeric(str_replace(intensityFile[which(!is.na(str_extract(intensityFile[,1],"dx = \\d+"))),],"dx = ",""))
  
  # Get endtime of the file (which is *not* the same as the time of the last sample in the file)
  fileendtime <- as.numeric(str_replace(intensityFile[which(!is.na(str_extract(intensityFile[,1],"xmax = \\d+"))),],"xmax = ",""))
  
  # Renaming the first column of the intensity object
  colnames(intensityFile)[1]="ampvalue"
  
  # Subsetting to get the intensity data.
  I <- subset(intensityFile, grepl("z\\s\\[.*\\s=\\s\\d.",intensityFile$ampvalue))
  
  # Removing non-numeric data
  I <- as.data.frame(apply(I,2,function(i)gsub('\\s+z\\s\\[.*\\s=\\s', '',i)))
  I <- as.data.frame(apply(I,2,function(i)gsub('\\s', '',i)))
  
  # Create list of samples
  I$sample<-seq(1,nrow(I),1)
  rownames(I)<-seq(1,nrow(I),1) # Correct goofy rownames
  
  # Converting to numeric
  I$ampvalue <- as.numeric(I$ampvalue)
  
  # Add in times
  I$second <- startStep + (as.numeric(I$sample)-1) * stepSize
  
  # Add in the end of the file
  I$fileend <- rep(fileendtime,nrow(I))
  
  return(I[c("second","ampvalue","fileend")]) # Drop sample column
  
}