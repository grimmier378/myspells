--[[
	Title: MySpells
	Author: Grimmier
	Includes: AbilityPicker.lua 
		By: Aquietone
		Many thanks to him for his work on this.
	Description: This script creates a spell bar that allows you to cast spells from your spell gems.
				It also allows you to memorize spells from the spell picker.
				Right Clicking on a spell gem will bring up a context menu to memorize, inspect, or clear the spell.
				Right Clicking on an Empty spell gem will bring up the spell picker to memorize a spell.
				Left Clicking on a spell gem will cast the spell.
				Spells that are on cooldown will have a cooldown overlay.
				Spells that are not ready to cast will have a faded gem overlay.
]]

local mq = require('mq')
local ImGui = require('ImGui')
local AbilityPicker = require('AbilityPicker')
local Icon = require('mq.ICONS')
local bIcon = Icon.FA_BOOK

local spellBar = {}
local numGems = 8
local RUNNING = true
local animSpell = mq.FindTextureAnimation('A_SpellIcons')
local redGem = mq.CreateTexture(mq.luaDir .. '/myspells/images/red_gem.png')
local greenGem = mq.CreateTexture(mq.luaDir .. '/myspells/images/green_gem.png')
local purpleGem = mq.CreateTexture(mq.luaDir .. '/myspells/images/purple_gem.png')
local blueGem = mq.CreateTexture(mq.luaDir .. '/myspells/images/blue_gem.png')
local orangeGem = mq.CreateTexture(mq.luaDir .. '/myspells/images/orange_gem.png')
local yellowGem = mq.CreateTexture(mq.luaDir .. '/myspells/images/yellow_gem.png')
local openBook = mq.CreateTexture(mq.luaDir .. '/myspells/images/open_book.png')
local closedBook = mq.CreateTexture(mq.luaDir .. '/myspells/images/closed_book.png')
local picker = AbilityPicker.new()
local pickerOpen = false
local memSpell = -1


local function pickColor(spellID)
	local spell = mq.TLO.Spell(spellID)
	local categoryName = spell.Category()
	local targetType = spell.TargetType()
	if targetType == 'Single' or targetType == 'Line of Sight' or targetType == 'Undead' then
		return redGem
	elseif targetType == 'Self' then
		return yellowGem
	elseif targetType == 'Group v2' or targetType == 'Group v1' or targetType == 'AE PC v2' then
		return purpleGem
	elseif targetType == 'Beam' then
		return blueGem
	elseif targetType == 'Targeted AE' and (categoryName == 'Utility Detrimental' or spell.PushBack() > 0 or spell.AERange() < 20) then
		return greenGem
	elseif targetType == 'Targeted AE' then
		return orangeGem
	elseif targetType == 'PB AE' then
		return blueGem
	elseif targetType == 'Pet' then
		return redGem
	elseif targetType == 'Pet2' then
		return redGem
	elseif targetType == 'Free Target' then
		return greenGem
	else
		return redGem
	end

end

--- comments
---@param iconID integer
---@param spell table
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local iconSize = 30
	local gem = mq.FindTextureAnimation('A_SpellGemHolder')

	-- draw gem holder
	ImGui.SetCursorPos(cursor_x -1, cursor_y)
	ImGui.DrawTextureAnimation(gem, iconSize +12, iconSize+2 )

	ImGui.SetCursorPos(cursor_x, cursor_y)
	if iconID == -1 then
		-- no spell in this slot
		return
	end

	-- draw spell icon
	animSpell:SetTextureCell(iconID or 0)	
	ImGui.SetCursorPos(cursor_x + 8, cursor_y+ 5)
	ImGui.DrawTextureAnimation(animSpell, iconSize - 5, iconSize - 5)
	
	----------- overlay ----------------
	ImGui.SetCursorPos(cursor_x, cursor_y - 2)
	local OverlayColor = IM_COL32(0, 0, 0, 0.9 * 255)
	local startPos = ImGui.GetCursorScreenPosVec()
	local endPos
	local recast = spell.sRecast + 2 + spell.sCastTime
	local currentTime = os.time()
	local diff = currentTime - spell.sClicked
	local remaining = recast - diff
	local percent = remaining / recast

	if diff >= recast then
		spellBar[i].sClicked = -1
	end

	if not mq.TLO.Cast.Ready('"' .. spell.sName .. '"')() then
		-- spell is not ready to cast
		ImGui.SetCursorPos(cursor_x + 8, cursor_y +5 )
		if spell.sClicked > 0 then
			-- spell was cast and is on cooldown
			if percent < 0 then percent = 0 end -- Ensure percent is not negative
			OverlayColor = IM_COL32(21,2,2,238)
			startPos = ImGui.GetCursorScreenPosVec()
			-- adjust the height of the overlay based on the remaining time
			local adjustedHeight = (iconSize -5) * percent
			endPos = ImVec2(startPos.x + iconSize -5  , startPos.y + iconSize -5)
			startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
			-- draw the overlay
			ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
			ImGui.SetCursorPos(cursor_x + (iconSize / 2), cursor_y + (iconSize / 2))
			-- print the remaining time
			ImGui.TextDisabled(string.format("%d", remaining-1))
		
		else
			-- spell is not ready to cast and was not clicked most likely from global cooldown or just memmed
			-- draw the overlay
			ImGui.SetCursorPos(cursor_x + 8, cursor_y +5 )
			OverlayColor = IM_COL32(0,0,0,255)
			startPos = ImGui.GetCursorScreenPosVec()
			local adjustedHeight = (iconSize -5) 
			endPos = ImVec2(startPos.x + iconSize -5  , startPos.y + iconSize -5)
			startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
			ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
			ImGui.SetCursorPos(cursor_x + (iconSize / 2), cursor_y + (iconSize / 2))
		end
		-- draw the gem Color overlay faded out to show the spell is not ready
		ImGui.SetCursorPos(cursor_x , cursor_y + 1)
		ImGui.Image(pickColor(spell.sID):GetTextureID(), ImVec2(iconSize + 37, iconSize + 2), ImVec2(0, 0), ImVec2(1,1), ImVec4(0,0,0,0.7))
	else
		-- draw the gem Color overlay
		ImGui.SetCursorPos(cursor_x , cursor_y + 1)
		ImGui.Image(pickColor(spell.sID):GetTextureID(), ImVec2(iconSize + 37, iconSize + 2))
	end
	
	if mq.TLO.Cast.Ready('"' .. spell.sName .. '"')() then
		if currentTime - spell.sClicked > spell.sCastTime + 2 then
			spell.sClicked = -1
			spellBar[i].sClicked = -1
		end
	end

	local sName = spell.sName or '??'
	ImGui.PushID(tostring(iconID) .. sName .. "_invis_btn")
	ImGui.SetCursorPos(cursor_x, cursor_y)
	ImGui.InvisibleButton(sName, ImVec2(iconSize, iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
	ImGui.PopID()
end

local function GetSpells()
	local bonusGems = mq.TLO.Me.AltAbility('Mnemonic Retention').Rank() or 0
	numGems = 8 + bonusGems
	for i = 1, numGems do
		local sToolTip = mq.TLO.Window(string.format('CastSpellWnd/CSPW_Spell%s',i-1)).Tooltip()
		local sName
		local sRecast
		local sClicked 
		local sID, sIcon
		local sCastTime
		if spellBar[i] == nil then
			spellBar[i] = {}
		end
		if spellBar[i].sClicked == nil then
			spellBar[i].sClicked = -1
		end

		if sToolTip:find("%)%s") then
			sName = sToolTip:sub(sToolTip:find("%)%s")+2,-1)
			sID = mq.TLO.Spell(sName).ID() or -1
			sClicked = spellBar[i].sClicked or -1
			sRecast = mq.TLO.Spell(sName).RecastTime.Seconds() or -1
			sIcon = mq.TLO.Spell(sName).SpellIcon()	or -1
			sCastTime = mq.TLO.Spell(sName).MyCastTime.Seconds() or -1
		else
			sName = "Empty"
			sID = -1
			sIcon = -1
			sClicked = -1
			sRecast = -1
			sCastTime = -1
		end
		
		spellBar[i].sCastTime = sCastTime
		spellBar[i].sName = sName
		spellBar[i].sID = sID
		spellBar[i].sIcon = sIcon
		spellBar[i].sClicked = sClicked
		spellBar[i].sRecast = sRecast
	end
end

local function GUI_Spells()
	local open, show = ImGui.Begin(bIcon..'##'..mq.TLO.Me.Name(), true, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize))
	if not open then
		RUNNING = false
		ImGui.End()
		return
	end
	if show then

	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0,0)
	for i = 1, numGems do
		ImGui.BeginChild("##SpellGem"..i, ImVec2(40, 33), bit32.bor(ImGuiChildFlags.NoScrollbar))
		if spellBar[i].sID > -1 then
			DrawInspectableSpellIcon(spellBar[i].sIcon, spellBar[i], i)
			if ImGui.BeginPopupContextItem("##SpellGem"..i) then
				if ImGui.MenuItem("Memorize") then
					if pickerOpen == true then
						memSpell = -1
						picker:SetClose()
						pickerOpen = false
						picker:ClearSelection()
					else
						memSpell = i
					end
				end
				if ImGui.MenuItem("Inspect") then
					mq.cmdf("/altkey /notify CastSpellWnd CSPW_Spell%s leftmouseup", i-1)
				end
				if ImGui.MenuItem("Clear") then
					mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i-1)
				end
				ImGui.EndPopup()
			end
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip(string.format("%s", spellBar[i].sName))		
					if ImGui.IsMouseReleased(0) then
						mq.cmdf("/cast %s", i)
						spellBar[i].sClicked = os.time()
					end
			end
		else
			DrawInspectableSpellIcon(-1, spellBar[i], i)
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip("Empty")
				if ImGui.IsMouseReleased(1) then
					if pickerOpen == true then
						memSpell = -1
						picker:SetClose()
						pickerOpen = false
						picker:ClearSelection()
					else
						memSpell = i
					end
				end
			end
		end
		ImGui.EndChild()

	end
	ImGui.PopStyleVar()
	if memSpell ~= -1 and not pickerOpen then
		picker:SetOpen()
		pickerOpen = true
	end
	if picker.Selected then
			
		local selected = picker.Selected or {}
		if selected.Type == 'Spell' then
			mq.cmdf("/memspell %d \"%s\"", memSpell, selected.Name)
			memSpell = -1
			picker:SetClose()
			pickerOpen = false
			picker:ClearSelection()
		end
	end
	picker:DrawAbilityPicker()
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	ImGui.SetCursorPos(17, cursor_y)
	if mq.TLO.Window('SpellBookWnd').Open() then
		
		ImGui.Image(openBook:GetTextureID(), ImVec2(40, 40))
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip("Close Spell Book")
		
			if ImGui.IsMouseReleased(0) then
				mq.TLO.Window('SpellBookWnd').DoClose()
			end
		end
	else
		ImGui.Image(closedBook:GetTextureID(), ImVec2(40, 30))
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip("Open Spell Book")
			if ImGui.IsMouseReleased(0) then
				mq.TLO.Window('SpellBookWnd').DoOpen()
			end
		end
	end
	end
	ImGui.End()
end

local function Init()
	if mq.TLO.Me.MaxMana() == 0 then print("You are not a caster!") RUNNING = false return end
	picker:InitializeAbilities()
	GetSpells()
	mq.delay(1000)
	mq.imgui.init('GUI_MySpells', GUI_Spells)
end

local function Loop()
	while RUNNING do
		if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atMySpells\ax] \arNot in game, \ayTry again later...") mq.exit() end
		mq.delay(100)
		picker:Reload()
		GetSpells()
	end
end
if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atMySpells\ax] \arNot in game, \ayTry again later...") mq.exit() end
Init()
Loop()