README for GBA FE Lua StatTrack script - BizHawk Version.

To run this script, put it, and the images folder in our LUA folder, and run RNGscramblerBizHawk_StatTrack.lua from the LUA console

Credit to Dondon151 for the RNG scrambler functionality of this script. And shoutout to Geene whose scripts I borrowed some insiration from and whose readme I copied from

This script currently works for all FE6 (J) FE7 (U) and FE8 (U) 

----------------------------------------------------
!!IMPORTANT!! Session Save information !!IMPORTANT!!
----------------------------------------------------
Whenever you save the game (enter a new chapter) the game will save some data to a file called session_data.csv
 - This file keeps track of who's promoted and at what level so the stat tracker can accurately calculate averages

When you load the game into any chapter but the prologue/first chapter, and that file exists, it will load it

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

Binomial Distribution Viewer:
	- To view the binomial distribution of each stat, use our mouse to left click on the magnifying glass on a displayed unit
	- If you gave that unit stat boosters, you can subtract a stat booster amount from a graph by left clicking it, and the reverse by right clicking it
	- When looking at the binomial distribution, all other hotkeys and functionality pauses, so make sure to left click exit in the bottom left when you're done looking
	- Displayed next to each graph is top/bot and a percentage. This is the top of bottom percentile of your unit in that stat. Ex. if it says Bot 20%, then there's an 80% chance for this unit to have better stats than yours
		- If your unit caps a stat, it will not say top/bot, and the percentage is instead the chance that your unit would cap that stat naturally
	- Known bugs include:
		- not handling growth rates > 100% correctly (blame math, not me)
		- not handling pre-promote stat caps correctly if your unit would have capped as a pre-promote, and then got promoted
		- not having enough numbers in the ref_img.png to show probabilities over 60%
		- If there is a unit that becomes tracked who gained 0 levels somehow, viewing their binomial distribution will crash the script

Color change Instructions:
	If you want to change the colors available, edit the hex values in the variable color_arr. 
	The first value is the background color, and the second value is the border color. 


Hotkey change Instructions (universal):

Open the script in a text editor of your choice.

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
