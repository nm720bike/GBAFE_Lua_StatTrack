README for GBA FE Lua StatTrack script.

Credit to Dondon151 for the RNG scrambler functionality of this script. And shoutout to Geene whose scripts I borrowed some insiration from and whose readme I copied from

This script currently works for all FE6 (J) FE7 (U) and FE8 (U) 

----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------
When you stop the script it will save data about what pre-premoted level characters are at in session_data.csv

This only happens if you stop the script nicely like toggling the script off. If you exit the LUA console or close the emulator it will not write to this file

When you load the game and that file exists it will ask you if you'd like to load the session data

You can manually edit this file. Just open it, use ctrl+f to find a character you've promoted, and enter their pre-promoted level and set the spot for "promoted" to 1

If you wish to pass a save to someone, make sure to give them this file too so that the stat tracker works as intended

For FE8 trainees, the ppp_lvl is for the level they were at as a trainee when they promoted
----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------


Default Hotkeys:
	RngScrambler:
	'R' - Display RNs on the Right Side
	
	StatTrack:
	'Period' - moves stat-tracked units right
	'Comma' - moves stat-tracked units left
	'Slash' - changes color
	'L' - Cycles order of displayed units


Color change Instructions:

If you want to change the colors available, edit the hex values in the variable color_arr. 
The first value is the background color, and the second value is the border color. 


Hotkey change Instructions (universal):

Open the script in the "Utils" folder in a text editor of your choice.

Example: Instead of 'U' -> 'L'
CTRL + F - Search for "heldDown" (without the quotation marks)
Replace 
	['U'] = false
With
	['L'] = false
	
CTRL + F - Search for "function inputCheck"
Replace 
	if userInput.U and heldDown['U'] == false then
With
	if userInput.L and heldDown['L'] == false then
