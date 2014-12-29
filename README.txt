**************************************
               Dart Protracker
**************************************

V 1.0    12/29/14

Amiga Mod file player made in Dart using the
WebAudio html5 API.

Made by  GameAlchemist a.k.a. Vincent Piel

You might re-use any part of this code for any
purpose, just let me know !

---------------------------------

Demo here :

http://gamealchemist.co.nf/protracker/dartprotrackerdemo.html

you can drag and drop your mod files to hear them.

---------------------------------

To use : 

- Import the library.
- Create a WebGL audio context.
- Create a MOD Object setting autostart to true : 
        Mod myMod = new Mod ('song.mod', myAudioContext, null, true );

Or set autostart to false, then you can later (when its ready) play it.

---------------------------------

  This project was done both to learn WebAudio and for the nostalgia 
of those terribly sounding songs.   
  The 'specifications' are old, not official, and confusing, so one of the
challenge was to build a resilient state machine that would gracefully
handle all commands... But i had to stop at some point, when it works
for 'most' of the mod i have, because it is quite some work. 
  I compared the result to MilkyTracker, and could not match the same
quality in sound rendering. Interpolation and pre-filtering needs some 
work to have a clean sound.  
  I did not plan to go further on this project, however do not hesitate
to contact me if you're a .mod fan and have a plan / rq /fix / ....

---------------------------------

Features :
- uses WebAudio to process the sound for a very low overhead.
- sound mip-mapping (two versions of the samples are stored to reduce replay noise).
- adaptative filtering (a band pass filter is set on each channel to follow the frequency
currently played).
- double precision frequency computations


Issues :  
- some mod won't play (unhanled effects).
- does not handle focus lost.
- 48KHz => 44KHz conversion would be required for 44KHz WebAudio context.
- Some vibrato and other 'advanced' effect do not sound right.
- Some loop commands not handled.


 