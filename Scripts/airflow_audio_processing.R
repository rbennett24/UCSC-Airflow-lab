############################
# airflow_audio_processing.R
# Ryan Bennett, current version as of August 2025
# https://people.ucsc.edu/~rbennett/
# https://github.com/rbennett24/UCSC-Airflow-lab
############################


########################
# Function: processing and plotting two-channel oro-nasal airflow recordings.
########################

# To get this to work you need to specify some filepaths, look below (~ lines 173-179, and 192) for:
# filedir
# intensDir
# scriptFolder
# 
# And fill in those locations.

########################
# Usage notes:
########################
#
# - Tested with the Glottal Enterprises OroNasal Mask, but the script should work with any two-channel oro-nasal airflow recording in .wav format, regardless of sampling rate, bit depth, quality, etc.
#
#
# - Assumes all filenames begin with a <Spk#(#)_> tag indicating speaker number (e.g. Spk04_wordlist_bicycle.wav).
#
#
# - Used in conjunction with a Praat script called <save_airflow_inputs.Praat>. This R script will take the output of that script as its input (short .wav files, .TextGrid files, and corresponding .Intensity files).
#
#
# - The Praat .Intensity files are managed with two functions, readIntensityTrack() and convertDFtoIntensity(). These functions are defined in the R scripts readIntensity.R and df_to_intensity.R, which this script assumes are in a particular folder (see <scriptFolder> variable below).
#
#
# - Will save PNG and/or PDF files, along with nasalance contours in the Praat Intensity object format, in case you'd like to analyze them in Praat. See below for information about the specific subfolders this script will create in order to save these derived files.
#
#
# - The input will have matched oral and nasal values (for airflow or intensity) at each sample. But the process of filtering out outliers can lead to (many) samples which are unpaired across oral and nasal channels. Necessarily, nasalance will be undefined at these points. This is something to be careful about.
#
#
# - This script is *slow*. I've tried to improve it by making sure that there aren't any rbind() calls or other interated/repeated dataframe modification within for-loops, which are a well-known bottleneck in R:
#     * https://adv-r.hadley.nz/perf-improve.html#avoid-copies
#     * https://rpubs.com/jimhester/rbind
#     * https://rstudio-pubs-static.s3.amazonaws.com/406521_7fc7b6c1dc374e9b8860e15a699d8bb0.html
# The script uses dplyr::bind_rows() rather than rbind() when creating/modifying dataframes in the hopes of speeding things up (another option is data.table::rbindlist()). It also saves dataframe-type info in a list, then only binds to a dataframe outside of the loop (e.g. plotdata<-as.data.frame(dplyr::bind_rows(wavdatalist))).
# 
# I've tried to optimize other aspects of the code as well, related to e.g. reading in .wav files, computing rolling averages, etc.
# Right now, the major bottlenecks in this code occur whenever files are saved. If you set options that will save more files, that will correspondingly slow the script more.
# Another way of managing speed is by changing the resolution of the PNG files that are saved. Higher resolution = slower, as you'd expect. The effect
# can be pretty significant. So is changing the dimensions of each plot.
#
# There are probably other things that could be done for speeding up code, particularly not running operations needed for complex plots when you're only
# making simpler plots (e.g. leaving out low-pass filtering, signal difference, etc.). Some operations occur within loops when they could probably occur 
# just once in the script, outside loops. Some folders are created even when not strictly necessary.
# 
# But, as mentioned above, the major slowdown appears to be the time required to save any generated files to disk. It's not clear it's worth
# the effort to track down all of the potential slowdowns just to shave off a few seconds on a script that can sometimes run for hours, 
# when we know the major timesink is file saving.




############################
# Load necessary packages
library(tidyverse) # For data processing and plotting
library(audio) # For audio processing; seems to be much faster at loading .wav files than tuneR, av, sound, wrassp, and warbleR packages,
               # at least some of which are just using tuneR under the hood anyway.
               # You can test the speed differences with the microbenchmark package:
               # microbenchmark(audio::load.wave(f), # Fastest by far
               #                tuneR::readWave(f), av::read_audio_bin(f),sound::loadSample(f),
               #                wrassp::read.AsspDataObj(f),warbleR::read_sound_file(f))
library(seewave) # For low-pass filtering
library(readtextgrid) # For working with Praat TextGrids --- note that older versions of Praat may generate tg files in the wrong format!
library(scales) # For range standardization
library(RcppRoll) # For rolling averages (https://vandomed.github.io/moving_averages.html)
library(data.table) # To speed up reading and writing files; this script depends on df_to_intensity.R, which loads this package
                    # You can consider using vroom too; https://cran.r-project.org/web/packages/vroom/vignettes/benchmarks.html
                    # Also for rbindlist(), an alternative to dplyr::bind_rows(), itself a faster alternative to rbind()
library(ragg) # For saving as PNG
library(tictoc) # For timing different parts of the code
  elapsed.time <- function(totaltime=F){
    toc(log = TRUE, quiet = TRUE)
    elapsedtimeSec <- unlist(lapply(tic.log(format = FALSE), function(x) x$toc - x$tic))
    
    if (elapsedtimeSec < 60){
        elapsedtimeSec <- round(elapsedtimeSec, 1)
        if (totaltime==F){
          outmsg <- paste0("\t   \u21DD ", elapsedtimeSec, "s elapsed.", "\n")
        } else {
          outmsg <- paste0("\n***** ", elapsedtimeSec, "s elapsed in total. *****", "\n")
        }
    } else if (elapsedtimeSec < 3600){
        seconds <- round(elapsedtimeSec %% 60,1)
        minutes <- floor(elapsedtimeSec/60)
        if (totaltime==F){
          outmsg <- paste0("\t   \u21DD ", minutes, "m, ", seconds, "s elapsed.", "\n")
        } else {
          outmsg <- paste0("\n***** ", minutes, "m, ", seconds, "s elapsed in total. *****", "\n")
        }
    } else {
        seconds <- round(elapsedtimeSec %% 60,1)
        minutes <- floor((elapsedtimeSec/60) %% 60)
        hours <- floor(elapsedtimeSec/3600)
        if (totaltime==F){
          outmsg <- paste0("\t   \u21DD ", hours, "h, ", minutes, "m, ", seconds, "s elapsed.", "\n")
        } else {
          outmsg <- paste0("\n***** ", hours, "h, ", minutes, "m, ", seconds, "s elapsed in total. *****", "\n")
        }
    }
    cat(outmsg)
    tic.clearlog()
  }


##########
# Load fonts you want to use.
# This only needs to be done once on each computer, I think.
library(extrafont)

# Check that desired IPA font is loaded
if ("Doulos SIL" %in% fonts()==F){
  font_import(prompt = F,pattern="Doulos") # Import system fonts -- this can take awhile if you import them all
  loadfonts(device = "win") # I think you only need to do this once so that R imports all the needed files to a place it can draw on them?
  windowsFonts() # This will just show you which fonts are available to R -- it may be a long list!
}

# Set the font used for plotting IPA symbols
ipaPlotFont <- "Doulos SIL"
# Reasonable choices include Doulos SIL, Charis SIL, Brill, and Tahoma. Gentium Plus may also work, among various other options.
# Brill and Tahoma seem to be the best choices when diacritics need to be stacked on a single character.
# (Calibri and Cambria should work too, but have led to some strange problems in the past -- they can cause the script to crash for some reason, with an error like "polygon edge not found (zero-width or zero-height?)".)
#
# Just make sure you load whatever font you choose appropriately, as shown above.



##########
# Choose a colorblind friendly palette
# See also: https://easystats.github.io/see/reference/scale_color_okabeito.html
colorSetCB=palette.colors(n = 8,palette = "R4")

showColor<-function(pal){
  
  hist(seq(0,length(pal)),col=pal,breaks=length(pal))
  
}

# If you want to visualize the color palette, uncomment this text.
# showColor(colorSetCB)
# colorSet<-colorSetCB[c(1,2,4,3,8,6)]
# showColor(colorSetCB)
# colorSet<-colorSetCB[c(1,7,4,8,3,6)] # This is good for overlapping waveforms
# showColor(colorSet)
# colorSet<-colorSetCB[c(1,4,7,8,3,6)] # This is good for overlapping waveforms
# showColor(colorSet)


##########
# Where are the raw airflow and .TextGrid files located?
computer = ""

mixtecdir <- paste0("C:/Users/",computer) # ETC.

aingaedir <- paste0("C:/Users/",computer) # ETC.

filedir <- aingaedir # Select which directory you'd like to use

if (file.exists(filedir)==F){
  print("You may need to run save_airflow_inputs.Praat to generate input files for this script. Halting script!")
  {stop()}
}

intensDir <- paste0(filedir,"Intensity_tracks/") # Location of intensity files
setwd(filedir)


##########
# Load in functions that this script depends on.
scriptFolder <- paste0("C:/Users/",computer) # ETC
source(paste0(scriptFolder,"readIntensity.R")) # For reading Praat .Intensity files
source(paste0(scriptFolder,"df_to_intensity.R")) # For writing Praat .Intensity files


##########
# Get the list of TextGrids in the input directory.
# Note that this is case-sensitive: the file extension must be exactly ".TextGrid"
tg.list<-list.files(pattern='*.TextGrid')

# Get any/all corresponding .wav files with the same base name (filename minus extension)
# in the same folder.
# Note that this is case-sensitive: the file extension must be exactly ".wav"
wav.list<-str_replace(tg.list,".TextGrid",".wav")


##########
# Make sure that you actually generated the files you are trying to import
if (length(tg.list)==0 | length(wav.list)==0){
    print("There are no .wav (or perhaps no .TextGrid) files in the directory you've specified!")
  {stop()}
}


##############################
# Define a function for re-mapping any IPA symbols or other special symbols, sequences, etc. that
# you want to systematically change from the input TextGrids.
# This should apply to a data frame, with a specific target column for remapping symbols

############
# Remapping rules for Mixtec tones
if (filedir==mixtecdir){
  
  # Placeholders for special tonal and accentual symbols, and nasality
  htone <- "́"
  ltone <- "̀"
  hltone <- "̂"
  lhtone <- "̌"
  nassymbol <- "̃"
  
  # Superscript/subscript equivalences:
  # tone - raised number - raised letter (H, M, L) - lowered number
  # High - \u00B3 - \u1D34 - \u2083
  # Mid - \u00B2 - \u1D39 - \u2082
  # Low - \u00B9 - \u1D38 - \u2081
  newH <- "\u00B3"
  newM <- "\u00B2"
  newL <- "\u00B9"
  newHL <- "\u00B3\u00B9"
  newLH <- "\u00B9\u00B3"
  
  tgSymbolRemapper<-function(df){
      # Rename tiers as needed
      df <- df %>% mutate(tier_name = case_when(tier_num==1 ~ "word",
                                                tier_num==2 ~ "segment"))
    
      # Remap high, low, and contour tones to raised numbers (3, 1, 31, 13),
      # and strip out ligatures from affricates and diphthongs.
      # For symbols that are already encoded
      # Limit to segment-level transcriptions.
      # paste0() is used to pass the values of nassymbol and tone marking variables to the regex pattern.
      df.new <- df %>% mutate(text = case_when(.default = text,
                                               tier_name=="segment" ~ str_replace_all(text,
                                               c("ã" = paste0("a",nassymbol),
                                                 "ẽ" = paste0("e",nassymbol),
                                                 "ĩ" = paste0("i",nassymbol),
                                                 "õ" = paste0("o",nassymbol),
                                                 "ũ" = paste0("u",nassymbol),
                                            
                                                 "á" = paste0("a",newH),
                                                 "é" = paste0("e",newH),
                                                 "í" = paste0("i",newH),
                                                 "ó" = paste0("o",newH),
                                                 "ú" = paste0("u",newH),
                                                  
                                                 "à" = paste0("a",newL),
                                                 "è" = paste0("e",newL),
                                                 "ì" = paste0("i",newL),
                                                 "ò" = paste0("o",newL),
                                                 "ù" = paste0("u",newL),
                                                 
                                                 "â" = paste0("a",newHL),
                                                 "ê" = paste0("e",newHL),
                                                 "î" = paste0("i",newHL),
                                                 "ô" = paste0("o",newHL),
                                                 "û" = paste0("u",newHL),
                                                 
                                                 "ǎ" = paste0("a",newLH),
                                                 "ě" = paste0("e",newLH),
                                                 "ǐ" = paste0("i",newLH),
                                                 "ǒ" = paste0("o",newLH),
                                                 "ǔ" = paste0("u",newLH),
                                                 
                                                 "ṍ" = paste0("o",nassymbol,newH),
                                                 "ṹ" = paste0("u",nassymbol,newH)
                                                 
                                                 )
                                            ))) %>%
                       mutate(text = case_when(.default = text,
                              tier_name=="segment"~str_replace_all(text,paste0("([aeiou]",nassymbol,"?)",htone), paste0("\\1",newH)))) %>% 
                       mutate(text = case_when(.default = text,
                                tier_name=="segment"~str_replace_all(text,paste0("([aeiou]",nassymbol,"?)",ltone), paste0("\\1",newL)))) %>%
                       mutate(text = case_when(.default = text,
                                tier_name=="segment"~str_replace_all(text,paste0("([aeiou]",nassymbol,"?)",hltone), paste0("\\1",newHL)))) %>%
                       mutate(text = case_when(.default = text,
                                tier_name=="segment"~str_replace_all(text,paste0("([aeiou]",nassymbol,"?)",lhtone), paste0("\\1",newLH)))) %>%
                       mutate(text = case_when(.default = text,
                                tier_name=="segment"~str_replace_all(text,"͡",""))) # Ligatures
                       

      # Process mid tones
      # For any single-length vowel symbol (possibly nasalized), if it doesn't have a raised numerical tone mark already,
      # being final or directly followed by another vowel in its segment-level transcription (= diphthongs, long vowels),
      # give it mid tone (raised 2).
      # Limit to segment-level transcriptions.
      df.new <- df.new %>% mutate(text = case_when(.default = text,
                                  tier_name=="segment"~str_replace_all(text,
                                              paste0("([aeiou]",nassymbol,"?)([aeiou]",nassymbol,"?)"),"\\1\u00B2\\2")))
      df.new <- df.new %>% mutate(text = case_when(.default = text,
                            tier_name=="segment"~str_replace_all(text,
                                        paste0("([aeiou]",nassymbol,"?)(\b|$)"),"\\1\u00B2")))
      
      # Strip initial numbers off words
      df.new <- df.new %>% mutate(text = case_when(.default = text,
                                                   tier_name=="word"~str_replace_all(text,"(\b|^)\\d*-","")
                                                   )
                                  )
      
                       
      return(df.new)
  }
} else if (filedir==aingaedir){
  # Convert "TN" for 'transitional nasal' into fancier 'nasal appendix' tag (Napp).
  tgSymbolRemapper<-function(df){
    df.new <- df %>% mutate(text = case_when(.default = text,
                                             tier_name=="segment" ~ str_replace_all(text,"TN","N\u2090\u209A\u209A")
                                             )
                            )
    return(df.new)
  }
} else {
  # If you don't want to define any symbol remapping,
  # just define a trivial function.
  tgSymbolRemapper<-function(df){
    return(df)
  }
  
}


##############################
# Limit plotting of nasalance values to certain kinds of segments
# Will use grepl() downstream to find any interval containing the listed segments.
# Taken from a7ingae_airflow_analysis.R
nasalC <- c("m","ɱ","n","ɳ","ɲ","ŋ","ɴ") # Could of course add more here; A'ingae only has /m n ɲ/
prenasalC <- c("mb","ᵐb","nd","ⁿd","ndz","ⁿdz","ndʒ","ⁿdʒ","ng","ŋg","ᵑɡ","ⁿg",
               "mp","ᵐp","nt","ⁿt","nts","ⁿts","ntʃ","ⁿtʃ","nk","ŋk","ᵑk","ⁿk",
               "nt͡s","ⁿt͡s","nt͡ʃ","ⁿt͡ʃ","ntsʲ","ⁿtsʲ","nt͡sʲ","ⁿt͡sʲ" # For Mixtec coding
               ) # Could of course add more here, including more tiebars like m͡b etc.
oralV <- c("a","i","e","o","u","ɨ")
nasalV <- c("ã","ĩ","ẽ","õ","ũ","ɨ̃") # All atomic nasal vowel symbols
approximants <- c("j","w","ʋ","ɰ","r","ɾ","ɹ","l") # Some relevant approximants; there obviously could be more
glides <- c("j","w","ʋ","ɰ") # Some relevant glides; there obviously could be more
if (filedir==mixtecdir){
  justPlotSegs <- c(nasalC,prenasalC,oralV,nasalV,"h","ʔ",glides)
} else if (filedir==aingaedir){
  justPlotSegs <- c(nasalC,prenasalC,oralV,nasalV,"h","ʔ",glides)
} else {
  justPlotSegs <- c("") # Default, plot everything.
}
segFilterPattern<-paste0(justPlotSegs,collapse="|")
# segFilterPattern <- ".*" # If you want to include all segments



##############################
# Define a function for processing oral and nasal airflow tracks.
# This is the primary function of this script.

processAirflow<-function(plottype=c("channel","type","nasalance","all"), # Choose what kind of plot(s) you want to save. Should default to "channel".
                         simpleplot=T, # Simple plots, or complex ones? Should default to "simple", which will be overridden by plottype="all"
                         simpleNasalanceType=c("praat","lpf","rsd"), # When making simple plots, draw intensity + nasalance based on Praat intensity, LPF signal, or raw signal difference?
                         convertdBtoPa = T, # Convert Praat Intensity files from dB to Pa before calculating nasalance,
                                            # or doing other processing (including normalization)?
                                            # https://www.fon.hum.uva.nl/praat/manual/Intensity.html
                                            # https://groups.io/g/Praat-Users-List/topic/intensity_in_rms_vs/58557644
                         filterCeiling=280, # Height of low-pass filter in Hz. 250-300 is pretty good, being mindful of speaker f0.
                                            # 200 should filter out F1 and above but retain most pitch
                                            # 40-50 should mostly give true DC signals (i.e. aperiodic airflow,                                                                             # most salient in voiceless regions), assuming that those very low
                                            # frequency components were actually recorded to begin with.
                         trim.thresh=6, # When normalizing airflow and intensity, remove all points with n # of standard
                                        # deviations from mean before normalization (within each measurement type separately).
                                        # Set at something high, like 100, if you don't want any trimming to take place.
                                        # If this is too low, waveform peaks will all get flattened out at ceiling/floor!
                                        # Trial-and-error exploration suggests that something like 6 or 7 is a good limit.
                         nasal.amp.minimum = 0.01, # Return NA whenever strength of range-normalized nasal airflow is weak or zero.
                                                  # Calculated below relative to abs(Nasal) which is in [0,1] for normalized intensity/amplitude.
                                                  # 0.015-0.2 seems reasonable.
                         smoothwindowsizeMS = 11, # When smoothing for LPF nasalance, how big should the window be (in ms) for averaging? 10-20 seems reasonable.
                         vec.of.wavs=wav.list, # Input list of .wavs to process
                                               # Should all have associated TextGrids with same base filename (minus file extension)
                         nasal.chan=2, # Which channel in airflow recordings is nasal airflow?
                                       # If 2 (= right), assumes oral airflow is 1 (= left), and vice-versa
                         seg.tier=2, # What tier on the TextGrid is segment-level information coded?
                                     # This script assumes that there's a word-level transcription on the tier immediately above this.
                         saveDir=filedir, # Where do you want to save output image files?
                         imageSaveType=c("png","pdf","both"), # What format should images be saved in?
                         savePraatNas = T, # Do you want to save both normalized airflow and nasalance
                                           # measured from input Praat .Intensity files as output Praat .Intensity files?
                         saveLPF = F # Do you want to save smoothed LPF intensity and LPF nasalance as output Praat .Intensity files?
                         ){

  # Start timer for total time of script
  tic()
  print(paste0("Starting processing at ",format(Sys.time(), "%I:%M%P")))
  
  # Set default value for plot type to "channel".
  plottype <- match.arg(plottype)
  
  # Set default value for intensity+nasalance to "praat" (vs. "lpf" and "rsd")
  simpleNasalanceType <- match.arg(simpleNasalanceType)
  
  # Set default value for image saving type to png (vs. "pdf" and "both")
  imageSaveType <- match.arg(imageSaveType)
  
  ##########
  # Create folders for saving files as needed
  # TO DO: ONLY CREATE FOLDERS NEEDED GIVEN PARAMETER SETTINGS
  plotFold <- paste0(saveDir,"/Plots/")
  plotChanFold <- paste0(plotFold,"/Channel/")
  plotChanFoldSimp <- paste0(plotFold,"/Channel/Simple/")
  plotTypeFold <- paste0(plotFold,"/Type/")
  plotTypeFoldSimp <- paste0(plotFold,"/Type/Simple/")
  plotTypeFoldNasalanceOnly <- paste0(plotFold,"/Nasalance_only/")
  nasalanceFold <- paste0(saveDir,"/Nasalance_files/")
  airflowFold <- paste0(saveDir,"/Normalized_airflow/")
  if (saveLPF==T){
    LPFIntfold <- paste0(saveDir,"/LPF_normalized_intensity/")
    LPFNasfold <- paste0(saveDir,"/LPF_nasalance/")

    for (f in c(plotFold,plotChanFold,plotTypeFold,plotChanFoldSimp,plotTypeFoldSimp,plotTypeFoldNasalanceOnly,nasalanceFold,airflowFold,LPFIntfold,LPFNasfold)){
      if (file.exists(f)==F){
        dir.create(f)
      }
    }
  } else {
      for (f in c(plotFold,plotChanFold,plotTypeFold,plotChanFoldSimp,plotTypeFoldSimp,plotTypeFoldNasalanceOnly,nasalanceFold,airflowFold)){
        if (file.exists(f)==F){
          dir.create(f)
        }
      }
  }
  
  
  
  # Get unique speaker codes across the entire fileset
  # Assumes all filenames begin with a 4 or 5 digit <Spk(#)#_> tag indicating speaker number (e.g. Spk4_bicycle.wav).
  spk.code.list <- vec.of.wavs %>% substr(1,5) %>% str_replace("_","") %>% unique()
  print(paste0("Processing ", length(vec.of.wavs)," .wav files from ", length(spk.code.list)," speakers."))

  # Process items individually, speaker by speaker
  # This script used to process all speakers at once, but ran very slowly,
  # so we're trying this now.
  # It probably renders some of the group_by(speaker) calls below superfluous, but
  # we're not worried about that right now.
  for (spk.code in spk.code.list){
    
    # Get .wav files for one speaker at a time
    vec.of.wavs.spk <- vec.of.wavs %>% str_subset(paste0("^",spk.code))
    print(paste0("Now processing: ",spk.code,", ",length(vec.of.wavs.spk)," .wav + .TextGrids pairs."))
      
    
    ##############################
    # Process each .wav file, and store them for further processing, and eventually plotting.
    cat("\t","\u21B3 Reading in .wav files and intensity files; applying LPF to raw audio.","\n")
    tic() # Start the stopwatch
    wavdatalist <- vector("list", length(vec.of.wavs) * 6) # By 6 because we are storing 6 kinds of data per .wav file
    wcounter <- 1
    
    for (wav in vec.of.wavs.spk){
    
      # Get item
      # Assumes that all filenames end with ...file_item_interval#.wav
      item.codeRaw<-str_extract(wav,"[^_]*_[[:digit:]]*.wav")
      item.codeRaw<-str_replace(item.codeRaw,".wav","")
      item.code<-unlist(str_split(item.codeRaw,"_"))[1]
      item.num<-unlist(str_split(item.codeRaw,"_"))[2]
      
      
      ##########
      # Read in two channel airflow sound
      two.channel.sound <- audio::load.wave(wav)
      
      # Get sampling frequency and bit depth
      srate <- two.channel.sound$rate
      bdepth <- two.channel.sound$bits
  
      
      # Separate out the two airflow channels
      if (nasal.chan==2){
        nasalAirflowRaw<-c(two.channel.sound[2,])
        oralAirflowRaw<-c(two.channel.sound[1,])
      } else {
        nasalAirflowRaw<-c(two.channel.sound[1,])
        oralAirflowRaw<-c(two.channel.sound[2,])
      }
      
  
      ##########
      # Low pass filter the airflow channels
      # This could just be done to the stereo file too.
      # Better than downsampling, which can lead to aliasing.
      # It shouldn't matter if this is done to raw values (as here)
      # or normalized values.
      nasalLP <- nasalAirflowRaw %>%
        seewave::ffilter(f=srate,from=0,to=filterCeiling)
      oralLP <- oralAirflowRaw %>%
        seewave::ffilter(f=srate,from=0,to=filterCeiling)
      
      
      # Check that the two channels still have the same number of samples,
      # and print a warning if not.
      if (length(nasalLP) == length(oralLP)){ # length() instead of nrow() because these are wav objects, not dataframes
        # Do nothing
      } else {
        print(paste("There's a problem with the filtered audio for ", wav,
                    ", the numbers of samples in the filtered oral and nasal airflow channels are
                      different!"))
      }
      
  
      ####################
      # Create data frames for plotting raw and low-pass filtered audio
      # Convert samples into times
      # Add waveform type
      # Add file and speaker information, along with the timestamp of the end of the file.
      origrec = paste0("Normalized acoustic waveform\n","(",srate,"Hz sampling rate)")
      filtrec = paste0("Low-pass filtered\n","(",filterCeiling,"Hz threshold)")
      intensrec = paste0("Normalized intensity\ncontour (from Praat)")
      
      ##########
      # Raw data
      nasaldataRaw <- data.frame(ampvalue = nasalAirflowRaw)
      nasaldataRaw$second <- (1:nrow(nasaldataRaw)) / srate
      nasaldataRaw <- nasaldataRaw %>% 
        mutate(channel = "Nasal",type = origrec,
               speaker=spk.code,item=item.code,item.number=item.num,file=wav,sampling.rate=srate,bit.depth=bdepth,fileend=max(second))
      
      oraldataRaw <- data.frame(ampvalue = oralAirflowRaw)
      oraldataRaw$second <- (1:nrow(oraldataRaw)) / srate
      oraldataRaw <- oraldataRaw %>% 
        mutate(channel = "Oral",type = origrec,
               speaker=spk.code,item=item.code,item.number=item.num,file=wav,sampling.rate=srate,bit.depth=bdepth,fileend=max(second))
      
      
      ##########
      # Filtered data
      nasaldataLP <- data.frame(ampvalue = nasalLP)
      nasaldataLP$second <- (1:nrow(nasaldataLP)) / srate
      nasaldataLP <- nasaldataLP %>% 
        mutate(channel = "Nasal",type = filtrec,
               speaker=spk.code,item=item.code,item.number=item.num,file=wav,sampling.rate=srate,bit.depth=bdepth,fileend=max(second))
      
      oraldataLP <- data.frame(ampvalue = oralLP)
      oraldataLP$second <- (1:nrow(oraldataLP)) / srate 
      oraldataLP <- oraldataLP %>% 
        mutate(channel = "Oral",type = filtrec,
               speaker=spk.code,item=item.code,item.number=item.num,file=wav,sampling.rate=srate,bit.depth=bdepth,fileend=max(second))
  
      
      ##########
      # Read in corresponding intensity tracks for oral and nasal
      # channels as generated by Praat, and process as needed.
      if (nasal.chan==2){
        nasIntensTrack<-paste0(str_replace(wav,".wav",""),"_ch2.Intensity") # This is case-sensitive!
        nasalIntensRaw <- readIntensityTrack(paste0(intensDir,nasIntensTrack))
        
        oralIntensTrack<-paste0(str_replace(wav,".wav",""),"_ch1.Intensity") # This is case-sensitive!
        oralIntensRaw <- readIntensityTrack(paste0(intensDir,oralIntensTrack))
        
      } else {
        nasIntensTrack<-paste0(str_replace(wav,".wav",""),"_ch1.Intensity") # This is case-sensitive!
        nasalIntensRaw <- readIntensityTrack(paste0(intensDir,nasIntensTrack))
        
        oralIntensTrack<-paste0(str_replace(wav,".wav",""),"_ch2.Intensity") # This is case-sensitive!
        oralIntensRaw <- readIntensityTrack(paste0(intensDir,oralIntensTrack))
        
      }
      
      # Don't need to add fileend as a factor because it's already part of the output of readIntensityTrack()
      # You need the end time of the file later if you ever want to export these curves (or something derived from them)
      # as Praat Intensity files later using e.g. convertDFtoIntensity().
      nasalIntens <- nasalIntensRaw %>% mutate(channel = "Nasal",type = intensrec,
                                               speaker=spk.code,item=item.code,item.number=item.num,file=wav,sampling.rate=srate,bit.depth=bdepth)
  
      oralIntens <- oralIntensRaw %>% mutate(channel = "Oral",type = intensrec,
                                             speaker=spk.code,item=item.code,item.number=item.num,file=wav,sampling.rate=srate,bit.depth=bdepth)
      
      if (convertdBtoPa == T){
        nasalIntens <- nasalIntens %>% mutate(ampvalue = 2 * 10^-5 * 10 ^ (ampvalue / 20))
        oralIntens <- oralIntens %>% mutate(ampvalue = 2 * 10^-5 * 10 ^ (ampvalue / 20))
      }
      
  
      ####################
      # Merge all audio/intensity tracks that you plan to plot.
      wavdatalist[[wcounter]]<-nasaldataRaw
      wavdatalist[[wcounter+1]]<-oraldataRaw
      wavdatalist[[wcounter+2]]<-nasaldataLP
      wavdatalist[[wcounter+3]]<-oraldataLP
      wavdatalist[[wcounter+4]]<-nasalIntens
      wavdatalist[[wcounter+5]]<-oralIntens
      
      wcounter <- wcounter + 6

    }
      
    # bind_rows() outside of for-loop, so shouldn't be a major bottleneck.
    plotdata<-as.data.frame(dplyr::bind_rows(wavdatalist))
    rm(wavdatalist)
    rm(nasaldataRaw,oraldataRaw,nasaldataLP,oraldataLP,nasalIntens,oralIntens)
  
    # End the stopwatch and print
    elapsed.time()
    
    ##############################
    # Normalize amplitude for raw airflow channels values based on maximum values for
    # datasets grouped by speaker + channel type, and audio type (raw, filter, intensity, etc.).
    # 
    # For intensity contours, normalize by full range of values from [0,∞] to [0,1] using range standardization, since intensity is never negative.
    cat("\t","\u21B3 Normalizing airflow channels.","\n")
    tic() # Start the stopwatch

    # Before normalization, remove outlier points that might stretch the data space.
    # Do this within each type + channel separately.

    # Replace outliers with NA (or with the data limits themselves), or just remove them.
    plotdata <- plotdata %>% group_by(speaker,channel,type) %>%
                             # mutate(ampvalue = case_when(ampvalue > mean(ampvalue,na.rm=T) + trim.thresh * sd(ampvalue,na.rm=T) ~ NA,
                             #                            ampvalue < mean(ampvalue,na.rm=T) - trim.thresh * sd(ampvalue,na.rm=T) ~ NA,
                             #                            .default = ampvalue)
                             # mutate(ampvalue = case_when(ampvalue > mean(ampvalue,na.rm=T) + trim.thresh * sd(ampvalue,na.rm=T) ~ mean(ampvalue,na.rm=T) + trim.thresh * sd(ampvalue,na.rm=T),
                             #                             ampvalue < mean(ampvalue,na.rm=T) - trim.thresh * sd(ampvalue,na.rm=T) ~ mean(ampvalue,na.rm=T) - trim.thresh * sd(ampvalue,na.rm=T),
                             #                            .default = ampvalue)
                                    # ) %>% ungroup()
      
                             filter(ampvalue < mean(ampvalue,na.rm=T) + trim.thresh * sd(ampvalue,na.rm=T) & ampvalue > mean(ampvalue,na.rm=T) - trim.thresh * sd(ampvalue,na.rm=T)) %>% ungroup()
  
    # Normalize
    waves.normed <- subset(plotdata,type!=intensrec) %>% group_by(speaker,channel,type) %>%
                                                         mutate(normvalue = ampvalue/max(abs(ampvalue),na.rm=T)) %>% ungroup()

    intens.normed <- subset(plotdata,type==intensrec) %>% group_by(speaker,channel,type) %>%
                                                          mutate(normvalue = scales::rescale(ampvalue,to=c(0,1))) %>% ungroup()
    
    waves.normed <- subset(plotdata,type!=intensrec) %>% group_by(speaker,channel,type) %>%
      mutate(normvalue = ampvalue/max(abs(ampvalue))) %>% ungroup()
    
    intens.normed <- subset(plotdata,type==intensrec) %>% group_by(speaker,channel,type) %>% 
      mutate(normvalue = scales::rescale(ampvalue,to=c(0,1))) %>% ungroup()
    
    plotdata<-dplyr::bind_rows(waves.normed,intens.normed) # Since this is not in a for-loop, it shouldn't be a bottleneck
    
    
    ##########
    # Save normalized intensity contours so you can work with them later.
    
    if (nasal.chan==2){
      oral.chan=1
    } else {
      oral.chan=2
    }
    
    # End the stopwatch and print
    elapsed.time()
    
    # No rbind/bind_rows() call in this for-loop, so it shouldn't be a bottleneck
    if (savePraatNas==T){
      cat("\t","\u21B3 Saving normalized airflow channels as Praat .Intensity files.","\n")
      tic() # Start the stopwatch
      for (wav in vec.of.wavs.spk){
          nasalIntNormOut<-subset(plotdata,file==wav & type == intensrec & channel == "Nasal")[c("second","normvalue","fileend")]
          nasalIntNormOutName<-str_replace(wav,".wav",paste0("_ch",nasal.chan,"_normalized.Intensity"))
          convertDFtoIntensity(nasalIntNormOut,paste0(airflowFold,nasalIntNormOutName))
          
          oralIntNormOut<-subset(plotdata,file==wav & type == intensrec & channel == "Oral")[c("second","normvalue","fileend")]
          oralIntNormOutName<-str_replace(wav,".wav",paste0("_ch",oral.chan,"_normalized.Intensity"))
          convertDFtoIntensity(oralIntNormOut,paste0(airflowFold,oralIntNormOutName))
      }
      # End the stopwatch and print
      elapsed.time()
    }
    
    
    
    
    ##############################
    # Calculate nasalance
    cat("\t","\u21B3 Calculating nasalance over Praat intensity.","\n")
    tic() # Start the stopwatch
    ##########
    # Nasalance over intensity contours
    nasalanceIntensity <- subset(plotdata,type==intensrec) %>%
                              select(-ampvalue) %>% # Have to ditch the raw amplitude column first.
                              pivot_wider(names_from=channel, values_from = normvalue) %>% # Spread oral and nasal values into columns.
                              mutate(Nasalance = case_when(abs(Nasal) <= nasal.amp.minimum ~ NA, # Compute nasalance, above threshold
                                                           .default = Nasal/(Nasal+Oral)
                                                           )) %>%
                              pivot_longer(cols=c("Nasal","Oral","Nasalance"),names_to = "channel",values_to = "normvalue") # Gather columns
    

    # Drop oral and nasal airflow values
    nasalanceIntensity<-subset(nasalanceIntensity,channel=="Nasalance")
    
    # Add empty raw amplitude back in for data.frame merging
    nasalanceIntensity$ampvalue<-rep(NA,nrow(nasalanceIntensity))
    
    # Waveform type
    nasalancerecIntensity = paste0("Nasalance\n = A\u2099/(A\u2099+A\u2092) over\n normalized intensity")
    nasalanceIntensity <- nasalanceIntensity %>% select(-type) %>% # Drop any preexisting information about type so you can overwrite it.
                                                 mutate(type = nasalancerecIntensity) # No need to add other columns/values, they're already there.
    

    # End the stopwatch and print
    elapsed.time()
    
    ##########
    # Nasalance over low-pass filtered data
    cat("\t","\u21B3 Calculating nasalance over LPF signal.","\n")
    tic() # Start the stopwatch
    
    # Since the waveform is constantly changing, compute rolling average over absolute values.
    # Set size of the window for averaging, in number of samples, based on size of desired averaging window (in ms)
    smoothwindow = ceiling(1/((1/srate)/(smoothwindowsizeMS/1000)))
    
    # An alternative approach would be to set smoothwindow on the basis of the lowest or highest f0 values of the
    # LPF signal. That way, you can guarantee that x # of periods are guaranteed to be included in the window for the 
    # lowest/highest f0 frequencies. 
    # The highest f0 frequency is known --- it's the upper limit of the low-pass filter, filterCeiling.
    # The lowest f0 frequency has to be estimated. This can be done heuristically (e.g. filterCeiling/5), or 
    # by actually estimating pitch in each speaker's data using e.g. tuneR functions. This would greatly slow the script, but
    # see e.g. https://groups.google.com/g/seewave/c/CCBqa9I-gZA?pli=1 for how to turn tuneR wav objects into periodograms, then
    # f0 estimations.
    # This code would guarantee that you get 3 periods during the highest possible f0 values (with the shortest periods) in the
    # LPF data.
    # smoothwindow = ceiling(1/(filterCeiling) * 3 * srate)
    # At 11025 Hz, an 111 sample window = ~10ms window, 201 gets ~ 15ms, 221 gets ~ 20ms window, 276 gets ~ 25ms, 333 ~ 30ms, etc.
    
    nasalanceLP <- subset(plotdata,type==filtrec) %>%
                        select(-ampvalue) %>% # Have to ditch the raw amplitude column first.
                        pivot_wider(names_from=channel, values_from = normvalue) %>% # Spread oral and nasal values into columns.
                        # Compute rolling averages for oral and nasal LPF airflow to smooth the signals.
                        mutate(rollingavgNasal = RcppRoll::roll_mean(x = abs(Nasal), n = smoothwindow, na.rm = T,
                                                                fill = NA, align = "center", by = 1),
                               rollingavgOral = RcppRoll::roll_mean(x = abs(Oral), n = smoothwindow, na.rm = T,
                                                               fill = NA, align = "center", by = 1)
                               ) %>%
                        # Compute LPF nasalance from smoothed oral and nasal LPF channels.
                        mutate(Nasalance = case_when(is.na(rollingavgNasal) ~ NA, # Avoid NA values.
                                                     rollingavgNasal <= nasal.amp.minimum ~ NA, # Avoid sudden jumps to zero (or close to zero)
                                                     .default = rollingavgNasal/(rollingavgNasal+rollingavgOral) # Compute nasalance, above threshold
                        )) %>%
                        pivot_longer(cols=c("Nasal","Oral","Nasalance"),names_to = "channel",values_to = "normvalue") # Gather columns
    
    # End the stopwatch and print
    elapsed.time()

    # Save LPF airflow and nasalance
    # No rbind/bind_rows() call in this for-loop, so it shouldn't be a bottleneck
    if (saveLPF==T){
      cat("\t","\u21B3 Saving LPF airflow and nasalance values as Praat .Intensity files.","\n")
      tic() # Start the stopwatch
      for (wav in vec.of.wavs.spk){
        nasalIntNormOut<-subset(nasalanceLP,file==wav & channel == "Nasal")[c("second","rollingavgNasal","fileend")]
        nasalIntNormOutName<-str_replace(wav,".wav",paste0("_ch",nasal.chan,"_LPF_airflow_normalized.Intensity"))
        convertDFtoIntensity(nasalIntNormOut,paste0(LPFIntfold,nasalIntNormOutName))
        
        oralIntNormOut<-subset(nasalanceLP,file==wav & channel == "Oral")[c("second","rollingavgOral","fileend")]
        oralIntNormOutName<-str_replace(wav,".wav",paste0("_ch",oral.chan,"_LPF_airflow_normalized.Intensity"))
        convertDFtoIntensity(oralIntNormOut,paste0(LPFIntfold,oralIntNormOutName))
        
        nasalanceOut<-subset(nasalanceLP,file==wav & channel == "Nasalance")[c("second","normvalue","fileend")]
        nasalanceOutName<-str_replace(wav,".wav",paste0("_LPF_nasalance_normalized.Intensity"))
        convertDFtoIntensity(nasalanceOut,paste0(LPFNasfold,nasalanceOutName))
      }
      # End the stopwatch and print
      elapsed.time()
    }
      
    # Drop oral and nasal airflow values
    nasalanceLP<-subset(nasalanceLP,channel=="Nasalance")
    
    # Add empty raw amplitude back in for data.frame merging
    nasalanceLP$ampvalue<-rep(NA,nrow(nasalanceLP))
    
    # Waveform type
    nasalancerecLP = paste0("Nasalance\n = A\u2099/(A\u2099+A\u2092) over\n smoothed LPF signal")
    nasalanceLP <- nasalanceLP %>% select(-type) %>% # Drop any preexisting information about type so you can overwrite it.
                                   mutate(type = nasalancerecLP) %>% # No need to add other columns/values, they're already there.
                                   select(-c(rollingavgOral,rollingavgNasal)) # Ditch rolling average values


    ##########
    # Add signal difference over original recordings
    cat("\t","\u21B3 Computing signal difference between oral and nasal channels.","\n")
    tic() # Start the stopwatch
    nasalDiff <- subset(plotdata,type==origrec) %>% 
                        select(-ampvalue) %>% # Have to ditch the raw amplitude column first.
                        pivot_wider(names_from=channel, values_from = normvalue) %>% # Spread oral and nasal values into columns.
                        mutate(Signal.Difference = abs(Nasal)-abs(Oral)) %>% 
                        pivot_longer(cols=c("Nasal","Oral","Signal.Difference"),names_to = "channel",values_to = "normvalue") # Gather columns

    # Drop oral and nasal airflow values
    nasalDiff<-subset(nasalDiff,channel=="Signal.Difference")
    
    # Add empty raw amplitude back in for data.frame merging
    nasalDiff$ampvalue<-rep(NA,nrow(nasalDiff))
    
    # Waveform type
    nasalDiffrec = paste0("Raw signal difference\n = A\u2099-A\u2092")
    
    nasalDiff <- nasalDiff %>% select(-type) %>% # Drop any preexisting information about type so you can overwrite it.
                                   mutate(type = nasalDiffrec) # No need to add other columns/values, they're already there.
    

    # End the stopwatch and print
    elapsed.time()

    
    
    ##############################
    # Save nasalance files for analysis in Praat,
    # and generate + save plots.    
    
    
    ####################
    # Merge data files for plotting
    # Since this rbind/bind_rows call is not in a for-loop, it shouldn't be a major bottleneck
    cat("\t","\u21B3 Plotting data, and (if requested) saving nasalance derived from normalized Praat .Intensity.","\n")
    tic() # Start the stopwatch
    plotdata<-dplyr::bind_rows(plotdata,nasalanceIntensity,nasalanceLP,nasalDiff)

  
    ####################
    # Arrange factor levels as you'd like in the plotting data.
    plotdata <- plotdata %>% mutate(channel = fct_relevel(channel, "Nasal", after = 2))
    plotdata <- plotdata %>% mutate(channel = fct_relevel(channel, "Nasalance", after = 3))

    plotdata <- plotdata %>% mutate(type = fct_relevel(type,origrec,filtrec,intensrec,nasalDiffrec,nasalancerecLP,nasalancerecIntensity))


    # Determine nasalance range for segments that you have decided to plot, so that you can scale the plots appropriately.
    # Note that this will be done on a by-speaker basis. 
    # You have to do this goofy floor(min*100)/100 etc. trick b/c floor() and ceiling() round to nearest
    # integer values. Using 100 will round to two places instead, i.e. to an integer value of x%
    lpfNasFiltRange <- c(floor(min(subset(plotdata,type==nasalancerecLP)$normvalue,na.rm=T)*100)/100,
                         ceiling(max(subset(plotdata,type==nasalancerecLP)$normvalue,na.rm=T)*100)/100
                         )
    praatNasFiltRange <- c(floor(min(subset(plotdata,type==nasalancerecIntensity)$normvalue,na.rm=T)*100)/100,
                           ceiling(max(subset(plotdata,type==nasalancerecIntensity)$normvalue,na.rm=T)*100)/100
                           )

    # # Instead of speaker-specific ranges, you can also (manually) set fixed ranges for the entire dataset.
    # praatNasFiltRange <- c(0.17,0.77) # Derived from the A'ingae dataset itself in a7ingae_airflow_analysis.R

    # Get data range of signal difference values for controlling plot
    # y-axis when plotting signal difference.
    sig.diff.range <- c(floor(min(subset(plotdata,channel=="Signal.Difference")$normvalue,na.rm=T)*100)/100,
                        ceiling(max(subset(plotdata,channel=="Signal.Difference")$normvalue,na.rm=T)*100)/100
                        )

    # Set plot type which will be used for plotting nasalance,
    # or comparable alternative.
    # Default = nasalancerecIntensity
    if (simpleNasalanceType=="lpf"){
      nasalanceFacetType <- nasalancerecLP
      nasalanceFacetRange <- lpfNasFiltRange
    } else if (simpleNasalanceType=="rsd") {
      nasalanceFacetType <- nasalDiffrec
    } else {
      nasalanceFacetType <- nasalancerecIntensity # Default
      nasalanceFacetRange <- praatNasFiltRange
    }

    # No rbind/bind_rows() call in this for-loop, so it shouldn't be a bottleneck
    for (wav in vec.of.wavs.spk){
      
      ##########
      # Save output nasalance data (over intensity traces) as a Praat .Intensity file
      if (savePraatNas==T){
        nasalanceOutdata<-subset(plotdata,file==wav & type == nasalancerecIntensity)[c("second","normvalue","fileend")]
        nasalanceOutName<-str_replace(wav,".wav","_nasalance.Intensity")
        convertDFtoIntensity(nasalanceOutdata,paste0(nasalanceFold,nasalanceOutName))
      }
      
      ##########
      # Grab TextGrid information for plotting.
      tg.tibble <- read_textgrid(path = str_replace(wav,".wav",".TextGrid"))
      
      # Remap any symbols you'd like to change.
      tg.tibble <- tgSymbolRemapper(tg.tibble)
      
      # Add duration, midpoints.
      tg.tibble <- tg.tibble %>% group_by(file,tier_num,annotation_num) %>% # And e.g filename, speaker number, or whatever unique identifiers you need.
                                  mutate(
                                    duration = round((xmax - xmin)*1000,0),
                                    xmid = xmin + (xmax - xmin) / 2,
                                  )  %>% ungroup()

      
      # Extract segment vs. word-level coding (and remove unwanted punctuation <!?.>, leaving <'> which sometimes marks consonants)
      tg.segs<-subset(tg.tibble,tier_num==seg.tier)
      tg.segs$text<-gsub('[!?.]+','',tg.segs$text) # Remove punctuation
      
      tg.wds<-subset(tg.tibble,tier_num==seg.tier-1)
      tg.wds$text<-gsub('[!?.]+','',tg.wds$text) # Remove punctuation
      
      # Remove all empty intervals
      tg.segs <- tg.segs %>% filter(!(text %in% c("","\t")))
      tg.wds <- tg.wds %>% filter(!(text %in% c("","\t")))
      
      
      
      ##############################
      # Plot the data
      wavdata <- subset(plotdata,file==wav) # Get the data for just this file.

      # Reduce the plot complexity for original waveforms by subsetting out values,
      # to get every 3rd row, starting at 1, using modular arithmetic.
      # This is intended to reduce file size and speed plotting, though it seems like it only helps with file size.
      # If you turn this number up too high, it does begin to visibly affect the waveform shape.
      wavdata.tmp <- wavdata %>% filter(type %in% c(origrec,filtrec)) %>% group_by(channel,type) %>% filter(row_number() %% 3 == 1)
      wavdata <- dplyr::bind_rows(wavdata.tmp, wavdata %>% filter(!(type %in% c(origrec,filtrec))))
      rm(wavdata.tmp)
      
      
      # Merge input data with TextGrid labels to facilitate plotting,
      # and add information about ranges of values in each condition for faceting.
      wavdata.labels <- wavdata %>% select(c(file,channel,type)) %>% distinct() %>% mutate(file = str_replace(file,".wav",""))
      wavdata.labels <- wavdata.labels %>% mutate(yceiling = case_when(.default = 1,
                                                                       type==nasalancerecLP ~ lpfNasFiltRange[2],
                                                                       type==nasalancerecIntensity ~ praatNasFiltRange[2],
                                                                       channel=="Signal.Difference" ~ sig.diff.range[2]),
                                                  yfloor = case_when(type==intensrec ~ 0,
                                                                     type==nasalancerecLP ~ lpfNasFiltRange[1],
                                                                     type==nasalancerecIntensity ~ praatNasFiltRange[1],
                                                                     channel == "Signal.Difference" ~ sig.diff.range[1],
                                                  .default = -1)
                                                  )
      
      wavdata.labels <- wavdata.labels %>% mutate(yrange = yceiling - yfloor)
      
      tg.segs.labels <- tg.segs %>% mutate(file = str_replace(file,".TextGrid",""))
      tg.wds.labels <- tg.wds %>% mutate(file = str_replace(file,".TextGrid",""))
      
      wavdata.segs <- wavdata.labels %>% right_join(tg.segs.labels, by = join_by(file), relationship = "many-to-many")
      wavdata.wds <- wavdata.labels %>% right_join(tg.wds.labels, by = join_by(file), relationship = "many-to-many")

      rm(wavdata.labels,tg.segs.labels,tg.wds.labels)
      

      ##########
      # Blank out sections of nasalance data which are outside of the bounds of the segments
      # that you want to plot nasalance for.
      # https://stackoverflow.com/questions/79266978/dplyrfilter-check-if-each-value-in-vector-is-within-at-least-one-of-a-set/79267055#79267055
      wavdata.segs.nasalance.plotting <- wavdata.segs %>% ungroup() %>% filter(grepl(segFilterPattern,text)==T)
      wavdata.segs.nasalance.plotting.ranges <- wavdata.segs.nasalance.plotting %>% filter(tier_num==seg.tier) %>% select(c(xmin,xmax)) 

      wavdata.no.nasalance <- wavdata %>% ungroup() %>% filter(channel!="Nasalance")
      wavdata.nasalance <- wavdata %>% ungroup() %>% filter(channel=="Nasalance")

      wavdata.nasalance.notna <- wavdata.nasalance[wavdata.nasalance$second %inrange% wavdata.segs.nasalance.plotting.ranges,]
      wavdata.nasalance.na <- anti_join(wavdata.nasalance,wavdata.nasalance.notna,by=colnames(wavdata.nasalance))
      wavdata.nasalance.na$normvalue <- NA

      wavdata.nasalance <- dplyr::bind_rows(wavdata.nasalance.notna,wavdata.nasalance.na)

      wavdata <- dplyr::bind_rows(wavdata.no.nasalance,wavdata.nasalance)

      
      
      ####################
      # Facet by type
      colorSet<-colorSetCB[c(1,7,4,6,8,3)]
      
      # Create a variable for determining line type.
      wavdata <- wavdata %>% mutate(linetypecolumn = case_when((channel=="Nasal" & type==intensrec) ~ "B",
                                                        .default = "A"
                                                        )
                                    )
      
      
      # Dummy dataframe for controlling plotting of midline in airflow facets
      centerline.dummy.df <- expand.grid(channel=unique(plotdata$channel),
                                         type=unique(plotdata$type))
      centerline.dummy.df <- centerline.dummy.df %>% mutate(linevalue = case_when(type %in% c(origrec,filtrec,nasalDiffrec)  ~ 0,
                                                                                  .default = NA)
                                                            )
      
      if ((plottype == "type" & simpleplot==F) | plottype == "all"){
        
        # Get rid of label data you're not using
        wavdata.segs.plot <- wavdata.segs %>% filter(channel != "Nasal") %>% droplevels()
        wavdata.wds.plot <- wavdata.wds %>% filter(channel != "Nasal") %>% droplevels()
        centerline.dummy.df <- centerline.dummy.df %>% filter(channel != "Nasal") %>% droplevels()

        # In order to keep plot axis ranges consistent across plots,
        # we need to create some fake data which we then plot invisibly.
        # Coordinates are based on normalized data ranges in most cases.
        # https://chrischizinski.github.io/rstats/using_geom_blank/
        facetCategories <- levels(wavdata.segs.plot$type)
        blank_data <- data.frame(type = rep(facetCategories,each=2),
                                 x = 0,
                                 y = c(-1, 1, # Original recording
                                       -1, 1, # LPF recording
                                       0, 1, # Normalized intensity
                                       sig.diff.range, # Raw signal difference
                                       lpfNasFiltRange, # LPF nasalance
                                       praatNasFiltRange # Praat intensity nasalance
                                       )
                                 )
        # Ensure that your blank_data dataframe has the same order of levels as the original data.
        blank_data$type <- factor(blank_data$type, levels = levels(wavdata.segs.plot$type))
        
        # Make plot
        outplot<-ggplot() +
                    # Faceting
                    facet_grid(scales="free_y",type ~ .) +
                    # Dummy data to ensure consistent scales.
                    geom_blank(data = blank_data, aes(x = x, y = y)) +
          
                    # Add TextGrid markings for segments
                    geom_vline(data=tg.segs,aes(xintercept = xmin),linetype="dashed") +
                    geom_vline(data=tg.segs,aes(xintercept = xmax),linetype="dashed") +

                    geom_hline(data=centerline.dummy.df,na.rm=T,aes(yintercept=linevalue),color="grey70",lwd=1.5)+
          
                    geom_line(data=subset(wavdata,!(type %in% c(intensrec,nasalancerecIntensity))),
                               aes(x = second, y = normvalue,
                                   color=channel),
                               lwd = 1.25,
                               alpha = 0.55, na.rm=T) +
          
                    geom_line(data=subset(wavdata, type %in% c(intensrec,nasalancerecIntensity)),
                               aes(x = second, y = normvalue,
                                   linetype=linetypecolumn,
                                   color=channel),
                               lwd = 3,
                               alpha = 0.55, na.rm=T) +
                    guides(linetype="none") +
                    scale_linetype_manual(values=c("solid","longdash"))+
                    
                    geom_text(data=wavdata.segs.plot,aes(label=duration,x=xmid,y=yfloor+0.05*yrange),size=5.5)+  
                    geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.segs.plot,aes(label=text,x=xmid,y=yfloor+0.2*yrange),size=8) +

                    ylab("Normalized amplitude") +
                    xlab("Duration (ms)") +
                    theme_bw(base_size=24) +
                    theme(strip.text=element_text(size=14,face="bold"),
                          axis.text.x = element_blank(),
                          
                          panel.grid.major.x = element_blank(),
                          panel.grid.minor.x = element_blank(),
                          
                          legend.title = element_blank(),
                          legend.background = element_rect(fill = "grey90"),
                          legend.key.width = unit(5, "line"),
                          legend.key.size = unit(1.5, "line")) +
          
                    scale_color_manual(values=colorSet)+ # Color-blind friendly palette

                    # Add markings for words
                    geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.wds.plot,aes(label=text,x=max(wavdata$second)-0.01,y=yceiling-0.03*yrange),size=6)+
                    
                    # Add title
                    ggtitle(paste0("Speaker ",str_replace(unique(wavdata$speaker),"Spk","")," '",unique(wavdata.wds.plot$text),"'"," (recording #",unique(wavdata$item.number),")"))
          
          if (imageSaveType=="pdf" | imageSaveType=="both"){
            # Save w/ cairo
            cairo_pdf(file=paste0(plotTypeFold,str_replace(wav,".wav","_typefacet.pdf")),
                      width=22,height=16)
              print(outplot)
            dev.off()
          }
          if (imageSaveType=="png" | imageSaveType=="both"){
            # Save w/ ragg as png
            agg_png(file=paste0(plotTypeFold,str_replace(wav,".wav","_typefacet.png")),
                      width=22,height=16,units="in",res=250)
              print(outplot)
            dev.off()
          }
        
        }   
          
      
        ##########
        # Simplified version focusing on intensity + intensity-based nasalance

        if ((plottype == "type" & simpleplot==T) | plottype == "all"){
          
          # Get rid of label data you're not using
          wavdata.segs.plot <- wavdata.segs %>% filter(channel != "Nasal" & type %in% c(origrec,intensrec,nasalanceFacetType)) %>% droplevels()
          wavdata.wds.plot <- wavdata.wds %>% filter(channel != "Nasal" & type %in% c(origrec,intensrec,nasalanceFacetType)) %>% droplevels()
          centerline.dummy.df <- centerline.dummy.df %>% filter(channel != "Nasal" & type %in% c(origrec,intensrec,nasalanceFacetType)) %>% droplevels()

          # In order to keep plot axis ranges consistent across plots,
          # we need to create some fake data which we then plot invisibly.
          # Coordinates are based on normalized data ranges in most cases.
          # https://chrischizinski.github.io/rstats/using_geom_blank/
          facetCategories <- levels(wavdata.segs.plot$type)
          if (simpleNasalanceType=="rsd"){
            blank_data <- data.frame(type = rep(facetCategories,each=2),
                                     x = 0,
                                     y = c(-1, 1, # Original recording
                                           0, 1, # Normalized intensity
                                           sig.diff.min, sig.diff.max # Raw signal difference
                                           )
                                     )
          } else {
            blank_data <- data.frame(type = rep(facetCategories,each=2),
                                     x = 0,
                                     y = c(-1, 1, # Original recording
                                           0, 1, # Normalized intensity
                                           nasalanceFacetRange # Nasalance (LPF or Praat)
                                           )
                                     )
          }
          # Ensure that your blank_data dataframe has the same order of levels as the original data.
          blank_data$type <- factor(blank_data$type, levels = levels(wavdata.segs.plot$type))

          
          # Make plot
          outplot.simple<-ggplot() +
            # Faceting
            facet_grid(scales="free_y",type ~ .) +
            # Dummy data to ensure consistent scales.
            geom_blank(data = blank_data, aes(x = x, y = y)) +
            
            # Add TextGrid markings for segments
            geom_vline(data=tg.segs,aes(xintercept = xmin),linetype="dashed") +
            geom_vline(data=tg.segs,aes(xintercept = xmax),linetype="dashed") +

            geom_hline(data=centerline.dummy.df,na.rm=T,aes(yintercept=linevalue),color="grey70",lwd=1.5)+
            
            geom_line(data=subset(wavdata,type == origrec), # Subset the data out here to simplify
                      aes(x = second, y = normvalue,
                          color=channel),
                      lwd = 1.25,
                      alpha = 0.55, na.rm=T) +
            
            geom_line(data=subset(wavdata,type %in% c(intensrec,nasalanceFacetType)), # Subset the data out here to simplify
                      aes(x = second, y = normvalue,
                          linetype=linetypecolumn,
                          color=channel),
                      lwd = 3,
                      alpha = 0.55, na.rm=T) +
            guides(linetype="none") +
            scale_linetype_manual(values=c("solid","longdash"))+
            
            geom_text(data=wavdata.segs.plot,aes(label=duration,x=xmid,y=yfloor+0.05*yrange),size=8)+
            geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.segs.plot,aes(label=text,x=xmid,y=yfloor+0.2*yrange),size=12) +

            ylab("Normalized amplitude") +
            xlab("Duration (ms)") +
            theme_bw(base_size=30) +
            theme(strip.text=element_text(size=20,face="bold"),
                  axis.text.x = element_blank(),
                  
                  panel.grid.major.x = element_blank(),
                  panel.grid.minor.x = element_blank(),
                  
                  legend.title = element_blank(),
                  legend.background = element_rect(fill = "grey90"),
                  legend.key.width = unit(5, "line"),
                  legend.key.size = unit(1.5, "line")) +
            
            scale_color_manual(values=colorSet)+ # Color-blind friendly palette

            # Add markings for words
            geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.wds.plot,aes(label=text,x=max(wavdata$second)-0.01,y=yceiling-0.03*yrange),size=10)+
            
            # Add title
            ggtitle(paste0("Speaker ",str_replace(unique(wavdata$speaker),"Spk","")," '",unique(wavdata.wds.plot$text),"'"," (recording #",unique(wavdata$item.number),")"))
          
          if (imageSaveType=="pdf" | imageSaveType=="both"){
            cairo_pdf(file=paste0(plotTypeFoldSimp,str_replace(wav,".wav","_typefacet_simple.pdf")),
                      width=22,height=12)
              print(outplot.simple)
            dev.off()
          }
          if (imageSaveType=="png" | imageSaveType=="both"){
            # Save w/ ragg as png
            agg_png(file=paste0(plotTypeFoldSimp,str_replace(wav,".wav","_typefacet_simple.png")),
                    width=22,height=12,units="in",res=250)
              print(outplot.simple)
            dev.off()
          }

        }          
        
  
      
        ####################
        # Facet by channel
        colorSet<-colorSetCB[c(1,7,2,3,4,6)]
      
        # Dummy dataframe for controlling plotting of midline in airflow facets
        centerline.dummy.df <- expand.grid(channel=unique(plotdata$channel),
                                           type=unique(plotdata$type))
        centerline.dummy.df <- centerline.dummy.df %>% mutate(linevalue = case_when(channel %in% c("Oral","Nasal","Signal.Difference") ~ 0,
                                                                                    .default = NA)
                                                              )
      
        if ((plottype == "channel" & simpleplot==F) | plottype == "all"){
          
          # Get rid of label data you're not using
          wavdata.segs.plot <- wavdata.segs %>% filter(!(type %in% c(intensrec,filtrec,nasalancerecIntensity))) %>% droplevels()
          wavdata.wds.plot <- wavdata.wds %>% filter(!(type %in% c(intensrec,filtrec,nasalancerecIntensity))) %>% droplevels()
          centerline.dummy.df <- centerline.dummy.df %>% filter(!(type %in% c(intensrec,filtrec,nasalancerecIntensity))) %>% droplevels()

          # In order to keep plot axis ranges consistent across plots,
          # we need to create some fake data which we then plot invisibly.
          # Coordinates are based on normalized data ranges in most cases.
          # https://chrischizinski.github.io/rstats/using_geom_blank/
          facetCategories <- levels(wavdata.segs.plot$channel)
          blank_data <- data.frame(channel = rep(facetCategories,each=2),
                                   x = 0,
                                   y = c(-1, 1, # Oral waveform + intensity
                                         -1, 1, # Nasal waveform + intensity
                                         sig.diff.range, # Raw signal difference
                                         range(c(lpfNasFiltRange,praatNasFiltRange),na.rm=T) # LPF + Praat intensity nasalance
                                         )
                                   )
          # Ensure that your blank_data dataframe has the same order of levels as the original data.
          blank_data$channel <- factor(blank_data$channel, levels = levels(wavdata.segs.plot$channel))

          
          # Make plot
          outplot2<-ggplot() +
                    # Faceting
                    facet_grid(scales="free_y",channel ~ .) +
                    # Dummy data to ensure consistent scales.
                    geom_blank(data = blank_data, aes(x = x, y = y)) +
            
                    # Add TextGrid markings for segments
                    geom_vline(data=tg.segs,aes(xintercept = xmin),linetype="dashed") +
                    geom_vline(data=tg.segs,aes(xintercept = xmax),linetype="dashed") +

                    geom_hline(data=centerline.dummy.df,na.rm=T,aes(yintercept=linevalue),color="grey70",lwd=1.5)+
            
                    geom_line(data=subset(wavdata,!(type %in% c(intensrec,nasalancerecIntensity))),
                              aes(x = second, y = normvalue,
                                  color=type),
                              lwd = 1.25,
                              alpha = 0.55, na.rm=T) +
                    
                    geom_line(data=subset(wavdata, type %in% c(intensrec,nasalancerecIntensity)),
                              aes(x = second, y = normvalue,
                                  color=type),
                              lwd = 3,
                              alpha = 0.55, na.rm=T) +
                    
                    geom_text(data=wavdata.segs.plot,aes(label=duration,x=xmid,y=yfloor+0.05*yrange),size=5)+
                    geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.segs.plot,aes(label=text,x=xmid,y=yfloor+0.2*yrange),size=8) +

                    ylab("Normalized amplitude") +
                    xlab("Duration (ms)") +
                    theme_bw(base_size=24) +
                    theme(strip.text=element_text(size=14,face="bold"),
                          axis.text.x = element_blank(),
                          
                          panel.grid.major.x = element_blank(),
                          panel.grid.minor.x = element_blank(),
                          
                          legend.title = element_blank(),
                          legend.background = element_rect(fill = "grey90"),
                          legend.key.width = unit(5, "line"),
                          legend.key.size = unit(1.5, "line"),
                          legend.text = element_text(margin = margin(b = 0.75, unit = "line"))) +
            
                    scale_color_manual(values=colorSet,limits=levels(wavdata$type))+ # Color-blind friendly palette

                    # Add markings for words
                    geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.wds.plot,aes(label=text,x=max(wavdata$second)-0.01,y=yceiling-0.03*yrange),size=6)+
            
                    # Add title
                    ggtitle(paste0("Speaker ",str_replace(unique(wavdata$speaker),"Spk","")," '",unique(wavdata.wds.plot$text),"'"," (recording #",unique(wavdata$item.number),")"))
          
          if (imageSaveType=="pdf" | imageSaveType=="both"){
            # Save w/ cairo
            cairo_pdf(file=paste0(plotChanFold,str_replace(wav,".wav","_channelfacet.pdf")),
                      width=20,height=12)
              print(outplot2)
            dev.off()
          }
          if (imageSaveType=="png" | imageSaveType=="both"){
            # Save w/ ragg as png
            agg_png(file=paste0(plotChanFold,str_replace(wav,".wav","_channelfacet.png")),
                    width=20,height=12,units="in",res=250)
              print(outplot2)
            dev.off()
          }                    
 
        }        
        
      
        ##########
        # Simplified version focusing on intensity + intensity-based nasalance
        colorSet<-colorSetCB[c(1,2,4,3,7,6)]
      
        if ((plottype == "channel" & simpleplot==T) | plottype == "all"){

          # Get rid of label data you're not using
          if (simpleNasalanceType=="lpf"){
            plottingChannels <- c("Oral", "Nasal", "Nasalance")
            plottingTypes <- c(origrec,nasalancerecLP)
          } else if (simpleNasalanceType=="rsd"){
            wavdata <- wavdata %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
            wavdata.segs <- wavdata.segs %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
            wavdata.wds <- wavdata.wds %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
            centerline.dummy.df <- centerline.dummy.df %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
            plottingChannels <- c("Oral", "Nasal", "Raw diff.")
            plottingTypes <- c(origrec,nasalDiffrec)
            wavdata$channel <- factor(wavdata$channel, levels = plottingChannels)
            wavdata.segs$channel <- factor(wavdata.segs$channel, levels = plottingChannels)
            wavdata.wds$channel <- factor(wavdata.wds$channel, levels = plottingChannels)
          } else { # Default
            plottingChannels <- c("Oral", "Nasal", "Nasalance")
            plottingTypes <- c(origrec,nasalancerecIntensity)
          }
          
          wavdata.segs.plot <- wavdata.segs %>% filter(channel %in% plottingChannels & type %in% plottingTypes) %>% droplevels()
          wavdata.wds.plot <- wavdata.wds %>% filter(channel %in% plottingChannels & type %in% plottingTypes) %>% droplevels()
          centerline.dummy.df <- centerline.dummy.df %>% filter(channel %in% plottingChannels & type %in% plottingTypes) %>% droplevels()

          # In order to keep plot axis ranges consistent across plots,
          # we need to create some fake data which we then plot invisibly.
          # Coordinates are based on normalized data ranges in most cases.
          # https://chrischizinski.github.io/rstats/using_geom_blank/
          facetCategories <- levels(wavdata.segs.plot$channel)
          if (simpleNasalanceType=="rsd"){
            blank_data <- data.frame(channel = rep(facetCategories,each=2),
                                     x = 0,
                                     y = c(-1, 1, # Oral waveform + intensity
                                           -1, 1, # Nasal waveform + intensity
                                           sig.diff.min, sig.diff.max # Raw signal difference
                                           )
                                     )
          } else {
            blank_data <- data.frame(channel = rep(facetCategories,each=2),
                                     x = 0,
                                     y = c(-1, 1, # Oral waveform + intensity
                                           -1, 1, # Nasal waveform + intensity
                                           nasalanceFacetRange # Nasalance (LPF or Praat)
                                           )
                                     )
          }
          # Ensure that your blank_data dataframe has the same order of levels as the original data.
          blank_data$channel <- factor(blank_data$channel, levels = levels(wavdata.segs.plot$channel))

          # Make plot
          outplot2.simple<-ggplot() +
            # Faceting
            facet_grid(scales="free_y",channel ~ .) +
            # Dummy data to ensure consistent scales.
            geom_blank(data = blank_data, aes(x = x, y = y)) +

            # Add TextGrid markings for segments
            geom_vline(data=tg.segs,aes(xintercept = xmin),linetype="dashed") +
            geom_vline(data=tg.segs,aes(xintercept = xmax),linetype="dashed") +

            geom_hline(data=centerline.dummy.df,na.rm=T,aes(yintercept=linevalue),color="grey70",lwd=1.5)+
            
            geom_line(data=subset(wavdata,type == origrec), # Subset the data out here to simplify
                      aes(x = second, y = normvalue,
                          color=type),
                      lwd = 1.25,
                      alpha = 0.55, na.rm=T) +
            
            geom_line(data=subset(wavdata,type %in% c(intensrec,nasalanceFacetType)), # Subset the data out here to simplify
                      aes(x = second, y = normvalue,
                          color=type),
                      lwd = 3,
                      alpha = 0.55, na.rm=T) +
            
            geom_text(data=wavdata.segs.plot,aes(label=duration,x=xmid,y=yfloor+0.05*yrange),size=12)+
            geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.segs.plot,aes(label=text,x=xmid,y=yfloor+0.225*yrange),size=14) +

            ylab("Normalized amplitude") +
            xlab("Duration (ms)") +
            theme_bw(base_size=40) +
            theme(strip.text=element_text(size=36,face="bold"),
                  axis.text.x = element_blank(),
                  
                  panel.grid.major.x = element_blank(),
                  panel.grid.minor.x = element_blank(),
                  
                  legend.title = element_blank(),
                  legend.background = element_rect(fill = "grey90"),
                  legend.key.width = unit(5, "line"),
                  legend.key.height = unit(5, "line"),
                  legend.key.size = unit(1.5, "line"),
                  legend.text = element_text(margin = margin(b = 0.75, unit = "line"))) +
            
            scale_color_manual(values=colorSet,limits=c(origrec,intensrec,nasalanceFacetType))+ # Color-blind friendly palette
            
            # Add markings for words
            geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.wds.plot,aes(label=text,x=max(wavdata$second)-0.01,y=yceiling-0.03*yrange),size=10)+
            
            # Add title
            ggtitle(paste0("Speaker ",str_replace(unique(wavdata$speaker),"Spk","")," '",unique(wavdata.wds.plot$text),"'"," (recording #",unique(wavdata$item.number),")"))
          
          
          if (imageSaveType=="pdf" | imageSaveType=="both"){
            # Save w/ cairo
            cairo_pdf(file=paste0(plotChanFoldSimp,str_replace(wav,".wav","_channelfacet_simple.pdf")),
                      width=22,height=14)
              print(outplot2.simple)
            dev.off()

          }
          if (imageSaveType=="png" | imageSaveType=="both"){
            # Save w/ ragg as png
            agg_png(file=paste0(plotChanFoldSimp,str_replace(wav,".wav","_channelfacet_simple.png")),
                    width=22,height=14,units="in",res=250)
              print(outplot2.simple)
            dev.off()
          }   

      }

      
      
      ##########
      # Maximally simple version, plotting just nasalance alone (Praat, LPF, or raw signal difference, as chosen above)
      colorSet<-colorSetCB[c(1,2,4,3,7,6)]
        
      # Dummy dataframe for controlling plotting of midline in airflow facets
        centerline.dummy.df <- expand.grid(channel=unique(plotdata$channel),
                                           type=unique(plotdata$type))
      centerline.dummy.df <- centerline.dummy.df %>% mutate(linevalue = NA)
      
      if (plottype == "nasalance" | plottype == "all"){
        
        # Get rid of label data you're not using
        if (simpleNasalanceType=="lpf"){
          plottingChannels <- c("Nasalance")
          plottingTypes <- c(nasalancerecLP)
        } else if (simpleNasalanceType=="rsd"){
          wavdata <- wavdata %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
          wavdata.segs <- wavdata.segs %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
          wavdata.wds <- wavdata.wds %>% mutate(channel = case_when(.default = channel, channel == "Signal.Difference" ~ "Raw diff."))
          plottingChannels <- c("Raw diff.")
          plottingTypes <- c(nasalDiffrec)
          wavdata$channel <- factor(wavdata$channel, levels = plottingChannels)
          wavdata.segs$channel <- factor(wavdata.segs$channel, levels = plottingChannels)
          wavdata.wds$channel <- factor(wavdata.wds$channel, levels = plottingChannels)
        } else { # Default
          plottingChannels <- c("Nasalance")
          plottingTypes <- c(nasalancerecIntensity)
        }
        
        wavdata.segs.plot <- wavdata.segs %>% filter(channel %in% plottingChannels & type %in% plottingTypes) %>% droplevels()
        wavdata.wds.plot <- wavdata.wds %>% filter(channel %in% plottingChannels & type %in% plottingTypes) %>% droplevels()
        centerline.dummy.df <- centerline.dummy.df %>% filter(channel %in% plottingChannels & type %in% plottingTypes) %>% droplevels()

        # In order to keep plot axis ranges consistent across plots,
        # we need to create some fake data which we then plot invisibly.
        # Coordinates are based on normalized data ranges in most cases.
        # https://chrischizinski.github.io/rstats/using_geom_blank/
        facetCategories <- levels(wavdata.segs.plot$channel)
        if (simpleNasalanceType=="rsd"){
          blank_data <- data.frame(channel = rep(facetCategories,each=2),
                                   x = 0,
                                   y = c(sig.diff.min, sig.diff.max # Raw signal difference
                                         )
                                   )
        } else {
          blank_data <- data.frame(channel = rep(facetCategories,each=2),
                                   x = 0,
                                   y = nasalanceFacetRange # Nasalance (LPF or Praat)
                                   )
        }
        # Ensure that your blank_data dataframe has the same order of levels as the original data.
        blank_data$channel <- factor(blank_data$channel, levels = levels(wavdata.segs.plot$channel))
        
        
        # Make plot
        outplot2.simple<-ggplot() +

          # Dummy data to ensure consistent scales.
          geom_blank(data = blank_data, aes(x = x, y = y)) +
          
          # Add TextGrid markings for segments
          geom_vline(data=tg.segs,aes(xintercept = xmin),linetype="dashed") +
          geom_vline(data=tg.segs,aes(xintercept = xmax),linetype="dashed") +
          
          # geom_hline(data=centerline.dummy.df,na.rm=T,aes(yintercept=linevalue),color="grey70",lwd=1.5)+
          
          geom_line(data=wavdata %>% filter(type==nasalanceFacetType) %>% droplevels(), # Subset the data out here to simplify
                    aes(x = second, y = normvalue),
                    color=colorSet[3],
                    lwd = 3,
                    alpha = 0.55, na.rm=T) +
          
          geom_text(data=wavdata.segs.plot,aes(label=duration,x=xmid,y=yfloor+0.04*yrange),size=11)+
          geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.segs.plot,aes(label=text,x=xmid,y=yfloor+0.22*yrange),size=13) +
          
          ylab(nasalanceFacetType)+
          xlab("Duration (ms)") +
          theme_bw(base_size=32) +
          theme(strip.text=element_text(size=36,face="bold"),
                axis.text.x = element_blank(),
                axis.title.y = element_text(size=28),
                
                panel.grid.major.x = element_blank(),
                panel.grid.minor.x = element_blank(),
                
                plot.title = element_text(size=24),

                legend.title = element_blank(),
                legend.background = element_rect(fill = "grey90"),
                legend.key.width = unit(5, "line"),
                legend.key.height = unit(5, "line"),
                legend.key.size = unit(1.5, "line"),
                legend.text = element_text(margin = margin(b = 0.75, unit = "line"))) +
          
          scale_color_manual(values=colorSet,limits=c(origrec,intensrec,nasalanceFacetType))+ # Color-blind friendly palette
          
          # Add markings for words
          geom_label(family=ipaPlotFont,fontface="bold",data=wavdata.wds.plot,aes(label=text,x=max(wavdata$second)-0.01,y=yceiling-0.0275*yrange),size=8)+
          
          # Add title
          ggtitle(paste0("Speaker ",str_replace(unique(wavdata$speaker),"Spk","")," '",unique(wavdata.wds.plot$text),"'"," (recording #",unique(wavdata$item.number),")"))
        
        
        if (imageSaveType=="pdf" | imageSaveType=="both"){
          # Save w/ cairo
          cairo_pdf(file=paste0(plotTypeFoldNasalanceOnly,str_replace(wav,".wav","_nasalance_only.pdf")),
                    width=22,height=6)
          print(outplot2.simple)
          dev.off()
          
        }
        if (imageSaveType=="png" | imageSaveType=="both"){
          # Save w/ ragg as png
          agg_png(file=paste0(plotTypeFoldNasalanceOnly,str_replace(wav,".wav","_nasalance_only.png")),
                  width=16,height=6,units="in",res=300)
          print(outplot2.simple)
          dev.off()
        }   
        
      }

    }
    
    # End the stopwatch and print
    elapsed.time()      
    
  }

  # End the stopwatch and print total time
  elapsed.time(totaltime = T)
  
  print(paste0("Finished processing at ",format(Sys.time(), "%I:%M%P")))
  
  return(plotdata)
  
}

# airflow.df<-processAirflow(simpleNasalanceType="lpf",plottype="all")
# airflow.df<-processAirflow(simpleNasalanceType="rsd",plottype="all")
# airflow.df<-processAirflow(simpleNasalanceType="praat",plottype="all")
airflow.df<-processAirflow(simpleNasalanceType="praat",plottype="channel",simpleplot=T)

# airflow.df<-processAirflow(simpleNasalanceType="lpf",plottype="nasalance")
# airflow.df<-processAirflow(simpleNasalanceType="lpf",plottype="channel",simpleplot=T)

# head(airflow.df)