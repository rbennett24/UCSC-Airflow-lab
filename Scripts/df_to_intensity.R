convertDFtoIntensity<-function(inputDF,filepath,overwrite.existing=T){
  
  # Load the data.table package for faster write times.
  # You can consider using vroom too
  # https://cran.r-project.org/web/packages/vroom/vignettes/benchmarks.html
  require(data.table)
  
  # Assumes a df with times (column 1) and values (column 2), as well as a column 3 which 
  # includes a timestamp (repeated in every row) for when the file ends.
  # You can't reconstruct that timestamp from anything else -- you just have to know what it is ---
  # because the endtime of the file and the time of the final sample in the file
  # are not predictably connected/correlated in any way.
  
  # Delete existing versions of the file (if desired)
  if (overwrite.existing==T){
    if (file.exists(filepath)==T){
      file.remove(filepath)
    }
  }

  # Prep text of the Praat Intensity file you will save.
  # Note that that almost every line ends in one extra white space plus a newline...except for lines 1-3, 15 which lack the extra whitespace.
  # This includes the last content line, which ends in an extra white space and newline.
  
  # Header text
  header1 <- 'File type = "ooTextFile"' # Note the double quotes
  header2 <- 'Object class = "Intensity 2"' # Note the double quotes
  header3 <- '' # Blank line
  
  
  # Text that may vary from file to file
  x1 <- inputDF[1,1] # Time of first sample
  x1line <- paste0("x1 = ",x1," ")
  
  dx <- inputDF[2,1]-inputDF[1,1] # Space between samples
  dxline <- paste0("dx = ",dx," ")
  
  nx <- nrow(inputDF) # Number of samples
  nxline <- paste0("nx = ",nx," ")

  xmin <- 0 # Start time of file
  xminline <- paste0("xmin = ",xmin," ")
      
  xmax <- unique(inputDF[,3]) # End time of file (included in the input data frame, not calculated here)
  xmaxline <- paste0("xmax = ",xmax," ")
  
  
  # Invariant text (at least as far as I know!)
  dummy1 <- "ymin = 1 "
  dummy2 <- "ymax = 1 "
  dummy3 <- "ny = 1 "
  dummy4 <- "dy = 1 "
  dummy5 <- "y1 = 1 "
  dummy6 <- "z [] []: "
  dummy7 <- "    z [1]:"


  # Prepare first block of text to write
  outText<-c(header1,header2,header3,xminline,xmaxline,nxline,dxline,x1line,dummy1,dummy2,dummy3,dummy4,dummy5,dummy6,dummy7)

  # Prepare timestamp ~ value pairs
  for (i in 1:nx){
    sample.value <- inputDF[i,2]
    if (is.na(sample.value)){
      sample.value <- "--undefined--"
    }
    value.row <- paste0("        z [1] [",i,"] = ",sample.value," ")
    outText<-c(outText,value.row)
  }
    
  # Write the text
  # writeLines(outText,filepath)
  # write(outText,filepath)
  data.table::fwrite(list(outText),filepath,quote=FALSE)
}