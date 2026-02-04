README for GBAFE Lua StatTrack script.

Credit to Dondon151 for the RNG scrambler functionality of this script. And shoutout to Geene whose scripts I borrowed some insiration from and whose readme I copied from

This script currently works for FE8 only, and support for the other GBA games is still in development

Default Hotkeys:
	RngScrambler:
	'R' - Display RNs on the Right Side
	
	StatTrack:
	'Period' - moves stat-tracked units right
	'Comma' - moves stat-tracked units left
	'Slash' - changes color

Color change Instructions:

If you want to change the colors available, edit the hex values in the variable color_arr. The first value is the background color, and the second value is the border color. 

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
