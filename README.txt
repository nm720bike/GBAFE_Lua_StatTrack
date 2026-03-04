README for GBA FE Lua StatTrack script.

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
