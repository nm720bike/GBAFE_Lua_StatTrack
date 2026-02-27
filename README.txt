README for GBA FE Lua StatTrack script.

Credit to Dondon151 for the RNG scrambler functionality of this script. And shoutout to Geene whose scripts I borrowed some insiration from and whose readme I copied from

This script currently works for all FE6 (J) FE7 (U) and FE8 (U) 

----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------
This script auto-saves data about what pre-premoted level characters are at in session_data.csv

When you load the game and that file exists it will automatically load that file

You can manually edit this file. Just open it, use ctrl+f to find a character you've promoted, and enter their pre-promoted level and set the spot for "promoted" to 1

If you wish to pass a save to someone, make sure to give them this file too so that the stat tracker works as intended

For FE8 trainees, the ppp_lvl is for the level they were at as a trainee when they promoted
----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------

Commands:

There are a couple commands you can run in the LUA console that will do things:
n() : cycles through who you're looking at, which lets you see more characters if more than 3 have leveled up
t() : toggles printing of current RNG strings (kind of a mess)
l() : loads session_data.csv
s() : saves to session_data.csv



Command change Instructions:

If you wanna change these commands, scroll to the bottom of RNGscramblerMGBA_StatTrack.lua and change the function name

