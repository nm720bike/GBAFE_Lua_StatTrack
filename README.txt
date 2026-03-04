README for GBA FE Lua StatTrack script - mGBA Version.
This LUA script was ported from the main branch (BizHawk version) with the help of AI

Credit to Dondon151 for the RNG scrambler functionality of this script. And shoutout to Geene whose scripts I borrowed some insiration from and whose readme I copied from

This script currently works for all FE6 (J) FE7 (U) and FE8 (U) 

----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------
Whenever you save the game (enter a new chapter) the game will save some data to a file called session_data.csv
 - This file keeps track of who's promoted and at what level so the stat tracker can accurately calculate averages

When you load the game into any chapter but the prologue, and that file exists, it will load it

You can manually edit this file. Just open it, use ctrl+f to find a character you've promoted, and enter their pre-promoted level and set the spot for "promoted" to 1
	* if they're a trainee unit, and they've promoted out of their trainee class, set trainee state to 3

If you wish to pass a save to someone, make sure to give them this file too so that the stat tracker works as intended
----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------

Commands:

There are a couple commands you can run in the LUA console that will do things:
n() : cycles through who you're looking at, which lets you see more characters if more than 3 have leveled up
t() : toggles printing of current RNG strings (kind of a mess)

Command change Instructions:

If you wanna change these commands, scroll to the bottom of RNGscramblerMGBA_StatTrack.lua and change the function name

