---
title: "Oro-nasal Airflow Lab Manual"
date: "UCSC Linguistics"
output:
  html_document:
    highlight: tango
    theme: readable
  pdf_document: default
---
https://people.ucsc.edu/~rbennett/
https://github.com/rbennett24/UCSC-Airflow-lab
***
***
# <todo>TO DO</todo>
1. <todo>**Write up separate guide to making nasal pressure recordings using earbuds**</todo>
2. <todo>**Clean up scripts, then post**</todo>
3. <todo>**Write a comparable manual for recording intra-oral airpressure using tubes**</todo>
<!-- 4. <todo>come to a better understanding of what modulation does, and whether you can/should do without it.</todo> -->
<!-- 6. <todo>**PRESSURE TO FLOW CONVERSION?? No, the GE manual for the mask is clear that you're already measuring flow, there's a different transducer that measures pressure (the blue one), I guess?**</todo> -->
<!-- 7. <todo>**Read the manuals...all of them...**</todo> -->
<!-- 8. <todo>figure out why tf low-pass filtering at 50Hz doesn't get you the same kinds of results that DualView gets. "it calculates Nasalance from the low frequency or average airflows instead of from acoustic energies as in the other nasalance systems...Nasalance, or, alternatively ‘Flow Nasalance’ is computed from the low-pass filtered (‘averaged’) oral (Channel A) and nasal (Channel B) airflows," p.3-4 --- but how does this 'averaging' work? Or is this *precisely* because we're recording WITHOUT MODULATION to get the 20Hz and below components? That may be it...also "the red traces are of the airflow low pass filtered, -3dB at about 50 Hz, to eliminate all acoustic energy.", p.5</todo> -->


***
***
# Preparing a computer for oro-nasal recording
## Recording on Windows
If you connect the MS-110 box directly to a Windows computer using the USB plug on the back of the MS-110, there are a number of settings that need to be changed to make the recording work properly. If you instead connect via 3.5mm plug on the back of the MS-110, with a 3.5mm to USB converter, you'll probably have to make these same changes. (Note that you have to make these changes *separately* for each recording device or input technique used.)

The following instructions are for Windows 10. While similar sound settings are available in Windows 11, **we have never successfully recorded a stereo signal in Windows 11 using the MS-110 box**, regardless of the software used. The result has always been a 'stereo' recording with two identical audio channels, which is exactly what happens if you leave <sc>Enable audio enhancements</sc> checked on Windows 10 (see below). If you want to try to record in Windows 11, you may need to navigate through <sc>System > Sound > Advanced > More sound settings</sc> to get to some of the necessary interfaces.

<todo>To do: add screenshots</todo>

1. Plug in MS-110 to the computer.
2. Go to <sc> Settings > Sound</sc>, and under <sc>Input</sc>, go to <sc>Device Properties</sc>.
3. If desired: rename the MS-110 input device to something like "Oro-nasal airflow".
4. Make sure the volume is set high enough --- around 55% seems to yield a decent signal-to-noise ratio, but this should be periodically double-checked. (The Glottal Enterprises DualView manual recommends 40% on p.7.)   
    * The system recording volume you need seems to vary with (i) whether modulation is turned on or off on the MS-110, and (ii) whether you're recording directly to USB (level up to ~90% needed in some cases) or via 3.5mm to USB converter (level around ~55%).
    * See below for more specific instructions on setting recording levels.
5. Click on <sc>Additional device properties</sc> in the upper right.
6. On the <sc>Listen</sc> tab, set <sc>Playback</sc> through this device to the computer's regular speakers, so the computer doesn't try to play sound out through the MS-110 box.
7. Under <sc>Levels</sc> verify that the volume levels are still set correctly.
8. Under <sc>Advanced</sc>, **uncheck** <sc>Enable audio enhancements</sc>. **This is crucial**: otherwise, for whatever reason, Windows may fail to produce an actual stereo recording with two distinct channels when using this device, even when all other settings are correct. Instead, it will output a mono recording, or a fake 'stereo' recording with two identical channels.
9. While in the <sc>Advanced</sc> window, double-check that the USB input is set to record in 2-channel stereo under <sc>(Default) Format</sc>. In the <sc>Format</sc> dropdown menu, something like "2 channels, 16 bit, 48000 Hz (DVD Quality)" should be selected. 
     * The MS-110 system records with a sampling rate no higher than 10 kHz, so there's no point in trying to record at higher sampling rates in Windows (see p.3-5 of the MS-110 user manual). But you can always set a lower sampling rate (e.g. 11025 Hz) in whatever recording software you use. See below for more information on recording and sampling frequencies.
9. Right click on the speaker logo in the task bar at the lower-right of the screen to bring up the <sc>Sound</sc> window.
10. Double-check that the airflow device is set as the default under <sc>Recording</sc>, and that the computer's regular speakers are set as the default under <sc>Playback</sc>. If not, make sure these settings are changed.


<!-- When connecting the MS-110 to a Windows computer via a 3.5mm to stereo USB adapter, it does not appear that you need to make all these changes. But if you encounter any recording issues --- failure to record in stereo, recording too quiet/loud, etc. --- you should verify that these settings are not the culprit. -->



## Recording on Mac
<todo>Not yet tested.</todo>

Note that DualView software, like all Glottal Enterprises software, only works on Windows systems, and apparently only on Windows 10 (= not on Windows 11).


## Choice of recording program
There are at least two considerations affecting the choice of program for recording airflow signals with the MS-110 box and oro-nasal airflow mask:

* **Recording length**:
Glottal Enterprises software (DualView, AeroView) can only record .wav files shorter than 20 seconds (see e.g. the [AeroView FAQ](https://www.glottal.com/AeroView.html#faq)). In practice, this means that recordings need to be manually started and stopped for each recorded item, which can be cumbersome and time-consuming. Recording sessions will generally be longer and more difficult to manage. The recording session will also be saved as a series of individual short .wav files with uninformative (though numbered) names (e.g. <sc>DView3.wav</sc>; saved by default in <sc>C:\\Users\\...\\Documents\\Dualview  Data\\</sc>).


* **Modulation**:
In order to record airflow signal components below 20Hz the MS-110 box must modulate the signal. Glottal Enterprises DualView and AeroView software can then demodulate the signal. Without some other means to demodulate the signal, recording in other software platforms essentially means giving up on recording frequency components below 20 Hz, which may be desirable for e.g. nasal airflow during voiceless segments. (Modulation is controlled using the <sc>Modulation</sc> toggle switches on the back of the MS-110.)

  * Note, however, that voiceless nasal intervals can still be analyzed using intensity traces, as in [Stewart & Kohlberger (2017)](https://scholarspace.manoa.hawaii.edu/items/25cf5ea8-03e7-49ac-8bbd-5780185b3381) and related work; the Praat and R scripts discussed below implement this method. Note also that frequencies below 20Hz may be recorded *without* modulation or Glottal Enterprises software if an alternative data acquisition system (DAQ) is used, at least according to p.2-3,5 of the MS-110 manual. We have not explored this possibility yet.

  * <todo>Modulation REALLY does seem to change the output, qualitatively. There's way less cross-talk, and it seems to be applying LPF filters automatically (or actually, probably not applying filters as much as really dialing down the sampling frequency in the first place, which probably also reduces apparent cross-talk)</todo>.

  <todo>Add spectra/spectrograms illustrating frequency range; diagrams showing voiceless nasal analysis; etc..</todo>

In general, the practical burden imposed by recording with Glottal Enterprises software is significant enough --- especially in fieldwork contexts --- that we recommend recording with different software. Almost any modern recording software will do for this purpose. We recommend [Audacity](https://www.audacityteam.org/).

[Praat](https://www.fon.hum.uva.nl/praat/) is also an option, but we do not recommend it because (i) it's very easy to close a recording without saving it, and so the risk of losing an entire recording session is fairly high, (ii) Praat sometimes has memory issues when recording long sessions, which in the worst case may cause Praat to crash in the middle of a recording session; and (iii) the Praat recording interface doesn't provide detailed information about recording levels.

When recording with modulation (using Glottal Enterprises software), the frequency range of the recording is ostensibly around 0-1500Hz; without modulation, it's roughly 20-5000Hz (MS-110 manual, p.4-5). However, in practice modulated recordings also seem to capture frequencies up to ~5000Hz; this should be investigated more closely.

There are also concerns about the reliability of Glottal Enterprises software moving forward. In the past, DualView has sometimes stopped functioning as intended. For example, on a Windows 11 machine it stopped opening the recording window for calibration when requested; reinstalling DualView did not resolve the problem. Perhaps this reflects a more general issue with Windows 11 compatibility. In any case, it is clear that Audacity and other widely-available recording platforms are more actively maintained and updated than any Glottal Enterprises software, and likely to be more stable and reliable for that reason.

Glottal Enterprises software *is* important, however, if you would like to interpret your airflow signal in terms of liters/second flow. This is the purpose of the Glottal Enterprises calibration equipment (e.g. the FC-1C  calibration unit) and associated procedures. At present we do not have an alternative procedure for determining calibration or interpreting the airflow signal in terms of physical liters/second measurements. For more discussion of calibration, and the relation between air pressure and airflow, see [Whang (2013) "Production and acoustics of creaky nasal vowels"](https://scholar.colorado.edu/downloads/j3860715g).


***
***
# Installing Glottal Enterprises software
Installing Glottal Enterprises software like DualView, AeroView, or PhaseComp is not straightforward. It can only be used on Windows, and requires the NET 2.0 framework for installation.

[Installing NET 2.0: https://www.groovypost.com/howto/enable-net-framework-2-0-and-3-5-windows-11/](https://www.groovypost.com/howto/enable-net-framework-2-0-and-3-5-windows-11/)

This method for installing NET 2.0 has been tested on both Windows 10 and Windows 11:

1. Open the <sc>Start menu</sc>, and start typing *optionalfeatures*. Click the top result, which may say *Run command* under it.
  * Make sure you’re typing *optionalfeatures* as one word with no spaces. Don’t click <sc>Optional Features</sc> (with spaces) --- this is not what you want.
2. The <sc>Windows Features</sc> settings window should now be open.
3. Click on the <sc>.NET Framework 3.5 (includes .NET 2.0 and 3.0)</sc> check box, and make sure it's fully checked with a check mark, rather than a minus sign or black box.
4. Click <sc>OK</sc>.
5. Click <sc>Let Windows Update download the files for you</sc> to begin.
6. You’ll see a progress bar appear while the necessary components are downloaded and installed. Allow time for this to complete.
7. Once Windows has installed the .NET Framework, you’ll see a confirmation message stating that 'Windows completed the requested changes'.
8. Click the <sc>Close</sc> button to finish. You shouldn’t need to restart your PC, but you may want to, just in case.


Glottal Enterprises software comes on a CD, so you either need to (i) install it on a Windows computer with a CD drive, or (ii) find a computer with a CD drive, copy the installation files from the CD, and then transfer them to the computer you'd like to install the software on (via USB drive, Dropbox, etc.).

***
***
# Equipment checklist
## Primary equipment
* A printout of this manual, or safely stored PDF copy.

* Glottal Enterprises MS-110 "Transducer and analog data computer interface"

     <img src="./Manual_images/ms110.jpg" width="250">

* Glottal Enterprises oro-nasal mask (B)

  * Both small (child) and adult sizes should be at-hand, as recording is more effective/comfortable for some adults with the smaller child-sized mask.

    <img src="./Manual_images/oronasalbmask.jpg" width="250">
    <img src="./Manual_images/oronasalbmask3.jpg" width="200" style='transform: rotate(90deg);'>
      <!-- <img src="./Manual_images/oronasalbmask2.jpg" width="150"> -->

  
* Glottal Enterprises DRTH-1 mask handle
  * Note the hole in this handle for mounting a pressure transducer.

       <img src="./Manual_images/DRTH1handle.jpg" width="175">

* Two Glottal Enterprises PT-2E pressure transducers (yellow) connected to the Glottal Enterprises BFC-2 cable.

     <img src="./Manual_images/PT2e_transducers_BFC2_cable.JPG" width="300">
    
  * One of these PT-2E transducers (channel A) is hard-wired to the BFC-2 cable.
  
  * The second transducer (channel B) can be removed (carefully!) with a Phillips-head screwdriver, removing the screw on the black plastic side of the connection.
  
  * Channel A vs. B is labeled on the BFC-2 cables.
  
    <img src="./Manual_images/channel_labels.jpg" width="200">

  * Our convention is that Channel A = oral signal, Channel B = nasal signal.
  

* Recording device (laptop, portable recorder, etc.)
  * Recording device must have a USB port and/or 3.5mm stereo audio jack, or you must have appropriate adaptors.
  
  
* Cable to connect MS-110 output to your recording device.
  * If 3.5mm, make sure it's a *stereo* connection (aka 'TRS'), with two stripes on the connector.
  
    <img src="./Manual_images/35mm.jpg" width="200">

* Power supply for MS-110
  * Can be powered via powered USB port (on left), or via AC adapter provided by Glottal Enterprises (on right).
  
    <img src="./Manual_images/usb_cable.JPG" width="200">
    <img src="./Manual_images/ac_adapter.JPG" width="200">

  
* Any additional equipment (e.g. microphones, portable solid-state recorder) that you want to use for recording audio through the mask, or with the mask off. We recommend a lavalier mic or tabletop mic.

* Materials for sanitizing airflow mask between uses.
  * Likely includes two tubs for washing/sanitizing, mild fragrance-free soap, liquid rubbing alcohol, clean rags for alcohol wipes, clean dry towels for drying mask, etc.


## Secondary equipment
If working in the field, it's also wise to have backup plans for recording in case something goes wrong.

We recommend:

* Several pairs of low-impedance earbuds to record using the [earbuds method of Stewart & Kohlberger (2017) "Earbuds: A Method for Analyzing Nasality in the Field"](https://scholarspace.manoa.hawaii.edu/items/25cf5ea8-03e7-49ac-8bbd-5780185b3381)
  * [Sony MDR-EX15LP](https://electronics.sony.com/audio/headphones/in-ear/p/mdrex15lp-b) are a good, cheap option.


</br>
We also strongly recommend bringing the following additional equipment. In part, this is because we recommend recording via 3.5mm plug (with USB converter) rather than directly via USB; see below.

* If needed to connect to your recording device: an adapter to connect 3.5mm audio from earbuds to USB or 1/4" stereo connection.
  * A 3.5mm to 1/4" adapter must also be stereo/TRS, with two stripes on it.
  
    <img src="./Manual_images/35mm_14in.jpg" width="250">
  
  * 3.5mm to USB adapters may also work, but you have to verify that they allow you to record in stereo. Many do not. This is also true of USB-C adapters.
  
    * An example of a 3.5mm to USB adapter that works in stereo: [ClearClick Audio2USB Cable](https://www.clearclick.com/collections/our-products/products/audio2usb-cable)
  
      <img src="./Manual_images/audio2usb.jpg" width="200">

* Extension cable to make sure you can reach plug power when recording.

* Glottal Enterprises manuals (we recommend bringing scanned PDFs rather than the physical manuals).

* Backup red plugs (and mesh screens, if available).

    <img src="./Manual_images/backup_red_plugs.JPG" width="200">

* External power supply (e.g. USB power bank) for powering MS-110 if power goes out.

    <img src="./Manual_images/external_USB_power.JPG" width="300">

* Solid-state recorder (ideally with battery power option). E.g. Zoom H5 recorder.

* Spare batteries for any portable recorder used.


</br>
If you decide to record with calibration, you'll also need to bring the FC-1C calibration unit and the 140ml syringe used for calibration.

  </br><img src="./Manual_images/calibration_equip.JPG" width="250" style='transform: rotate(90deg);'></br></br>


***
***
# Assembling the equipment
1. Connect the transducers to the front of the MS-110 box using the BFC-2 cable.

    <img src="./Manual_images/ms110_center_plug.JPG" width="300">
    <img src="./Manual_images/ms110_w_transducers.JPG" width="300"></br></br>

2. To record both oral and nasal airflow simultaneously, make sure that **mesh** screen plugs (rather than the flat grey plastic plugs, which completely obstruct airflow) are in place for all *large* plug holes, for both the oral and nasal chambers. (See p.6-7 of the Glottal Enterprises AeroView software manual.)</br></br>
  
    <img src="./Manual_images/mask-mesh-plugs2.jpg" width="250" style='transform: rotate(90deg);'></br></br></br>

3. Connect the DRTH-1 mask handle to the oro-nasal mask, making sure that the handle is completely and firmly seated against the mask.</br></br></br>

<img src="./Manual_images/handle_mask_insertion.JPG" width="300" style='transform: rotate(90deg);'>
<img src="./Manual_images/handle_mask_seated.JPG" width="300" style='transform: rotate(90deg);'>
<img src="./Manual_images/handle_mask_front.JPG" width="300" style='transform: rotate(90deg);'></br></br></br>

4. Connect the transducers to the mask and handle.
  * Our convention: the channel A transducer should always be used for the oral chamber (mounted directly on the mask), and the channel B transducer for the nasal chamber (mounted on the handle).
  
  * Channel A vs. B is labeled on the BFC-2 cables.</br>
    
    <img src="./Manual_images/channel_labels.jpg" width="200"></br>
  

  * Make sure that the handle hosting the nasal transducer is correctly oriented so that the transducer on the handle (Channel B) is above the handle itself, and feeds into the nasal cavity, not the oral one.
  
    <img src="./Manual_images/mask_DRTH1_handle_PT2E_transducers.jpg" width="300"></br></br>

5. All *small* plug holes need to be plugged with either a transducer, or a small red plastic plug (as in the images above).</br>

    </br><img src="./Manual_images/mask_red_plugs.JPG" width="250" style='transform: rotate(90deg);'></br></br></br>

6. Connect MS-110 box to recording device (via USB or 3.5mm plug on back of device).

  * We recommend using the 3.5mm output, connected to your recording device via 3.5mm-to-USB adaptor (for recording to computer) or other adaptor (e.g. 1/8" plug for many portable recorders). When recording directly via USB, there are background hums at ~10 kHz and its (sub)harmonics that disappear when recording via 3.5mm connection.

      * <todo>To do: add spectrograms showing the hum issue. Write out subcases for direct USB vs. 3.5mm-to-USB adapter, with pictures, and recommendations.</todo>

    <img src="./Manual_images/ms110_rear_panel.jpg" width="350"></br></br>

7. If needed: connect MS-110 box to power supply.

8. Turn everything on. Make sure the power switch on the back of the MS-110 box is correctly set to USB vs. AC adapter power, depending on what you're using.


***
***
# Calibrating the equipment
<todo>**TO DO: clean up and finalize **</todo>

<todo>p.7 of the airflow mask manual: calibration should actually be pretty stable as long as gain values are the same</todo>

As noted above, calibration is primarily needed when you are interested in interpreting airflow signals in terms of physical liters/second values. This is unlikely for most studies, particularly since normalization across speakers/recording sessions/pressure transducers can be achieved by other means during post-hoc data processing and analysis, as implemented in the R scripts described below.

For more discussion of calibration, and the relation between air pressure and airflow, see [Whang (2013) "Production and acoustics of creaky nasal vowels"](https://scholar.colorado.edu/downloads/j3860715g).

<!-- Calibration "factor" has something to do with number of screen rings (= 4) -->

When is recalibration (potentially) needed? When either:

  * Adjustable gain is used, and the gain setting has been changed.
  * A recording is made in a new location, under new atmospheric conditions.

This follows the instructional video for calibrating airflow on the Glottal Enterprises YouTube site [Calibrating Airflow (video)](https://www.youtube.com/watch?v=ek1Vy_KF7b4), as well as the instructions in the DualView software manual. (The instructions in the FC-1C manual are similar, but refer to the AeroView software instead.)

Note that the Glottal Enterprises manuals recommend a 15 minute 'warm up' period for equipment to adjust to atmospheric conditions (esp. temperature) before calibrating and getting started.

1. Connect the channel A, PT-2E pressure transducer to the FC-1C Flow Calibrator.

2. Insert the syringe into the FC-1C Flow Calibrator.

  <todo>insert picture</todo>

3. Check the settings on the MS-110:
  * <sc>Modulation</sc> should be on for Channel A (the channel being calibrated) on the back of the box.
  * <sc>Offset</sc> and <sc>Gain</sc> should be set to <i>Adj.</i> on the front of the box.<todo>I'm not sure this is true.</todo>


<todo>Question: is it possible to carry out calibration using Audacity or [Praat]? Is it desirable? Is it possible/sufficient to use DualView *only* for calibration?</todo>

<!-- 3. <todo>**FIGURE OUT IF IT'S ENOUGH TO SAVE THE CALIBRATION SIGNAL IN DUALVIEW FOR LATER REFERENCE, THEN MOVE ON TO AUDACITY???**</todo> -->

***
***
# Making a recording
## MS-110 settings
Make sure the following settings are correct:
**Back of the MS-110 box**:
  * <sc>Modulator</sc>: off on both channels (unless recording with DualView)
  * <sc>Input invert</sc>: off

**Front of the MS-110 box**:
  * <sc>T.C.</sc> ('transducer compensation): on (see p.3-4 of MS-110 manual)
  * <sc>Offset</sc>: fixed for both channels
  * <sc>Gain</sc>: adjustable for both channels

The procedure described below for setting recording levels also works if <sc>Offset</sc> is adjustable and <sc>Gain</sc> is fixed instead, but the more intuitive approach is to use <sc>Gain</sc> to adjust the output levels of the MS-110.

<todo>To do: add content about the 'meaningful zero' associated with the offset setting. See MS-110 manual. Note that 'meaningful zero' might not be so important since even in cases of zero nasal airflow there is positive nasal channel signal from the acoustics and from physical coupling of the mask and transducers. Also, compare to p.3-4 of the FC-1C manual for calibration, which uses adjustable settings for both offset and gain.</todo>


## Volume adjustment on MS-110 box
1. Move the <sc>Gain</sc> setting on each channel until all of the LED lights are off.
  * For Channel A (oral), we recommend turning gain until the **yellow** LED is lit, then turning the gain **up** until the LEDs all go dark.
  * For Channel B (nasal), we recommend turning gain until the **green** LED is lit, then turning the gain **down** until the LEDs all go dark.
  * We recommend this because Channel B seems to be inherently somewhat quieter than Channel A, and this brings the two channels closer in volume.
  * In either case, the <sc>Gain</sc> settings should be around 9-10 o'clock on the dial.

After doing this, make sure that the LEDs stay off when you breathe in, hold your breath, and place the mask on your face (or the participant's face). If the LEDs change, readjust the settings as described above so they stay neutral with the mask on the face, since that will be the actual recording configuration. (See p.7 of the DualView manual for this recommendation.)



## Volume adjustment on recording device
If recording in e.g. Audacity, there should be a recording level meter you can watch to make sure that the volume setting is appropriate. While speaking into the mask, both channels (A & B) should have volume levels hovering around -12dB: this provides a good signal-to-noise ratio for the recording while also allowing enough headroom to prevent clipping.

  <todo>Add screenshot</todo>

If the recording levels are not around -12dB, you may have to adjust the <sc>Gain</sc> settings on the MS-110 box, and/or the recording levels on whatever device you're recording to.

Make sure to avoid clipping no **both** the recording device and on the MS-110 itself (= make sure the red LED does not come on).

As noted above, the recording volume you need to set on your recording device seems to vary with (i) whether modulation is turned on or off on the MS-110, and (ii) whether you're recording directly to USB (level up to ~90% needed in some cases) or via 3.5mm to USB converter (level around ~55%).

Note that **voiceless* nasal intervals have much greater amplitude than voiced ones. If you're planning to study voiceless nasals, you may have to lower the baseline volume on Channel B (nasal signal) accordingly to avoid clipping.

  <todo>Add diagram</todo>



## Sampling rate on recording device
The MS-110 system records with a sampling rate no higher than 10 kHz. We recommend setting your recording device to record at a sampling rate of 11025 Hz, or even just 10 kHz if your device allows that as an option (e.g. Audacity allows custom sampling rates).

Audacity allows you to set a default or recording-specific sampling rate at <sc>Edit > Preferences > Audio Settings</sc> (at least in the version that is current as of July 2023).


If you try to record above 11025 Hz, you may get some pretty nasty hums around 8 kHz and its harmonic multiples, which negatively impact recording quality even if you try to eliminate them later via resampling or filtering. 

  * These hums probably reflect the functioning of the USB port itself, which has an 8kHz information transfer rate, e.g. [1](https://archimago.blogspot.com/2015/05/measurements-usb-hubs-and-8khz-phy.html), [2](https://www.audiosciencereview.com/forum/index.php?threads/8khz-usb-noise-how-do-i-get-rid-of-it.10211/). 
  
  * These 8kHz multiple hums are probably louder than usual because they are the only signal information at all in that frequency range, given the frequency limitations of the MS-110 device.
  
  * This is probably also why the hum gets worse when modulation is turned on, since the modulated signal supposedly has an even lower sampling rate (frequency ceiling) than unmodulated ones.

Because of this sampling rate limit, you should assume that **you won't get any usable frequency information above 5 kHz** at best. That's not an issue for analyzing nasalance, or nasality more generally.




## Presentation of materials and recording procedure
We recommend recording audio to a dedicated solid-state recorder at the same time you record oro-nasal airflow (if possible). For example:

  <todo>NEED TO ADD IMAGES OF OVERALL RECORDING SETUP</todo>

We suggest that each word be recorded:

1. **Twice without the mask on**, so that the dedicated audio recording captures a clear version of the target item.
2. **Twice with the mask on** in a *slow, careful speech rendition* of the item.
3. **Twice with the mask on** in a *fast, more casual or naturalistic rendition* of the item.

The clean, unmasked recordings may help with transcription at later stages.

For some of the motivation for manipulating speech rate, see [Solé 1992](https://journals.sagepub.com/doi/pdf/10.1177/002383099203500204), [1995](https://journals.sagepub.com/doi/pdf/10.1177/002383099503800101), and [2007](https://www.researchgate.net/profile/Maria-Josep-Sole/publication/320629228_Controlled_and_mechanical_properties_in_speech_a_review_of_the_literature/links/59f2fd8caca272cdc7d03f81/Controlled-and-mechanical-properties-in-speech-a-review-of-the-literature.pdf).

<todo>Needs to be cleaned up and finalized.</todo>
* **Use your Python script?**
* **RECORD ONCE CLEAN TO AUDIO WITHOUT THE MASK, BEFORE RECORDING TO THE MASK?**


## Length of recording session
Anecdotally, recording sessions shouldn't be much longer than 30 minutes. Participants begin to feel fatigued after that point, at least in field settings where e.g. humidity may be an issue for comfort.




## Finalizing the recording
If using Audacity, make sure to save the project **and** export to .wav, adding appropriate metadata and saving with an informative filename (e.g. <sc>A7ingae_July23_oronasal_spk3-Zabalo.wav</sc>).


***
***
# Annotating a recording
Recordings should be annotated using [Praat](https://www.fon.hum.uva.nl/praat/) TextGrids.

We recommend using the [Praat](https://www.fon.hum.uva.nl/praat/) script [twochannel_mixdown_textgrids.Praat](./Scripts/Praat_scripts/twochannel_mixdown_textgrids.Praat) to generate TextGrids. This script will also process the original two-channel airflow recording into an audio file with (i) a mono mixdown of both airflow channels, combined into a single channel (as channel 1), and (i) the original oral airflow channel (as channel 2). This makes it easier to do segmentation than when working with oral and nasal airflow channels separately.

# <todo>Do we want to talk about how to time-align audio and nasality recordings? Probably doesn't matter for anything except TextGrids. I guess the workflow could be to code the audio recording, calculate a time lag, and generate a nasal airflow textgrid to check.</todo>

<todo>Do we also want to use a script to mark utterances?</todo>

<todo>In practice, the mixed-down audio isn't *always* easier to work with than just the oral (or nasal) channel separately, so make sure it's clear that this is an optional step? Or adjust the script with more parameters/options...</todo>

<todo>**twochannel_mixdown_textgrids.Praat doesn't produce textgrids with the right names or locations for the next script save_airflow_inputs.Praat right now (= the textgrids all have a "_mono" tag and are in the mono_mixdown_files folder)**</todo>

<todo>Also important to remember that you don't want to run the subsequent analysis steps on the mixed-down audio!</todo>

<todo>**Make sure the TextGrid format is clear, e.g. word on tier 1, segments on tier 2; make sure that this is what forced alignment generates if that's what you use.**</todo>

<todo>**Should this script be updated to mark non-silent intervals?**</todo>


***
***
# Processing a recording for analysis


## Generating PDF plots
Use the [Praat](https://www.fon.hum.uva.nl/praat/) script [save_airflow_inputs.Praat](./Scripts/Praat_scripts/save_airflow_inputs.Praat), followed by the R script [airflow_audio_processing.R](./Scripts/Praat_scripts/airflow_audio_processing.R).

Note that Praat doesn't like special characters like *&aacute;, &ntilde;*, etc. in file names. It's also important to make sure that your local version of Praat is saving TextGrid files with UTF-8 encoding.

## Quantitative analysis
Use the [Praat](https://www.fon.hum.uva.nl/praat/) script [measure_nasalance_traces.Praat](./Scripts/Praat_scripts/measure_nasalance_traces.Praat), followed by the R script [nasalance_airflow_data_analysis.R](./Scripts/Praat_scripts/nasalance_airflow_data_analysis.R).

These scripts assume that you've already run the R script [airflow_audio_processing.R](./Scripts/Praat_scripts/airflow_audio_processing.R) above to generate the inputs to [measure_nasalance_traces.Praat](./Scripts/Praat_scripts/measure_nasalance_traces.Praat).


***
***
# Transporting the equipment
<todo>**TO BE WRITTEN**</todo>




***
***
# Online resources
<todo>Needs to be cleaned up and finalized.</todo>
Calibrating airflow video: https://www.youtube.com/watch?v=ek1Vy_KF7b4&t=153s

Calibrating air pressure (not used): https://www.youtube.com/watch?v=NiSV0HG3T6


***
***

## Online resources (add more!)
<todo>Needs to be cleaned up and finalized; see similar section above.</todo>
* [YouTube video made by Glottal Enterprises for using AeroView system](https://www.youtube.com/watch?v=vIiIU6NzfAE)
* [General Glottal Enterprises YouTube channel](https://www.youtube.com/user/GlottalEnterprises)
* Calibrating airflow video: https://www.youtube.com/watch?v=ek1Vy_KF7b4&t=153s
* Calibrating air pressure (not used, right?): https://www.youtube.com/watch?v=NiSV0HG3T6

***
***
***
***






<!-- ## Recent lessons learned -->
<!-- * Make sure that the system volume is set correctly --- this can be done using the DualView software while calibration/level setting is happening, if that's how we determine levels ultimately. -->


<!--
## Preparing the equipment
1. If you want to record both oral and nasal airflow simultaneously, make sure that the mesh screen plugs are in place for both the oral and nasal chambers (rather than the flat plastic grey plugs which completely obstruct airflow). [*See p.6-7 of the physical manual from Glottal Enterprises.*] **ALSO, ALL OPEN PLUG HOLES NEED TO BE PLUGGED WITH A RED PLUG OR A TRANSDUCER**
  * In the event that you want to record *only* oral airflow or nasal airflow (and not both), the chamber associated with airflow measurement should have the mesh screen plugs inserted, and the other chamber should have the flat plastic plugs in place. <todo>**[!!!verify this!!!]**</todo>
 
	<img src="./Manual_images/mask-mesh-plugs2.jpg" width="200">
 	

2. THIS IS INCORRECT, FIX IT, SEE NOTES BELOW IN THE QUESTIONS SECTION: Different pressure transducers are used for measuring oral vs. nasal airflow:
  * **Nasal** airflow is measured using the **yellow** PT-2E pressure transducer.
	
	![insert two pictures here showing the correct connection]()
  
  * **Oral** airflow is measured using the **blue** P-25 pressure transducer, which connects to the mask using an additional converter and tube.
  
	![insert two pictures here showing the correct connection]()
	![insert two pictures here showing the correct connection]()
-->	
	
<!-- ## Questions
1. WHY is the yellow PT-2E pressure transducer used for the DualView system that has both oral and nasal airflow, while the blue PT-25 transducer is used with an oral tube + adapter for the measurement of subglottal pressure? Also note that the P-25 uses a different calibration unit than the PT-2E pressure transducer. They are both called "pressure" transducers, though...perhaps it has to do with low pressure vs. high pressure measurement, which is something that's mentioned in the user guides. Also, the calibrator for the blue PT-25 transducer is for "pressure", while the calibrator for the PT-2E transducer is for "flow" -->
