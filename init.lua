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
local picker = AbilityPicker.new()
local pickerOpen = false
local Icon = require('mq.ICONS')
local bIcon = Icon.FA_BOOK
local LoadTheme = require('lib.theme_loader')
local themeID = 1
local theme, defaults, settings = {}, {}, {}
local themeFile = string.format('%s/MyThemeZ.lua', mq.configDir)
local configFile = mq.configDir .. '/myui/MySpells_Configs.lua'
local themezDir = mq.luaDir .. '/themez/init.lua'
local themeName = 'Default'
local script = 'MySpells'
local casting = false
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
local memSpell = -1
local currentTime = os.time()
local maxRow, rowCount, iconSize, scale = 1, 0, 30, 1
local aSize, locked, hasThemeZ, configWindowShow, loadSet, clearAll = false, false, false, false, false, false
local meName
local setName = 'None'
local tmpName = ''

defaults = {
	Scale = 1.0,
	LoadTheme = 'Default',
	locked = false,
	IconSize = 30,
	maxRow = 1,
	AutoSize = false,
}

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

---comment Check to see if the file we want to work on exists.
---@param name string -- Full Path to file
---@return boolean -- returns true if the file exists and false otherwise
local function File_Exists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

local function loadTheme()
	if File_Exists(themeFile) then
		theme = dofile(themeFile)
		else
		theme = require('themes') -- your local themes file incase the user doesn't have one in config folder
	end
	themeName = settings[script].LoadTheme or 'Default'
		if theme and theme.Theme then
			for tID, tData in pairs(theme.Theme) do
				if tData['Name'] == themeName then
					themeID = tID
				end
			end
		end
end

local function loadSettings()
	-- Check if the dialog data file exists
	local newSetting = false
	if not File_Exists(configFile) then
		settings[script] = defaults
		mq.pickle(configFile, settings)
		loadSettings()
		else
			
		-- Load settings from the Lua config file
		settings = dofile(configFile)
		if settings[script] == nil then
			settings[script] = {}
		settings[script] = defaults 
		newSetting = true
		end
	end
		
	if settings[script].locked == nil then
		settings[script].locked = false
		newSetting = true
	end
		
	if settings[script].Scale == nil then
		settings[script].Scale = 1
		newSetting = true
	end

	if settings[script].maxRow == nil then
		settings[script].maxRow = 1
		newSetting = true
	end
	
	if not settings[script].LoadTheme then
		settings[script].LoadTheme = 'Default'
		newSetting = true
	end
	
	if settings[script][meName] == nil then
		settings[script][meName] = {}
		settings[script][meName].Sets = {}
		newSetting = true
	end

	loadTheme()

	if settings[script].IconSize == nil then
		settings[script].IconSize = iconSize
		newSetting = true
	end
	
	if settings[script].AutoSize == nil then
		settings[script].AutoSize = aSize
		newSetting = true
	end
		
	-- Set the settings to the variables
	maxRow = settings[script].maxRow
	aSize = settings[script].AutoSize
	iconSize = settings[script].IconSize
	locked = settings[script].locked
	scale = settings[script].Scale
	themeName = settings[script].LoadTheme
		
	if newSetting then mq.pickle(configFile, settings) end
	
end

--- comments
---@param iconID integer
---@param spell table
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
	local cursor_x, cursor_y = ImGui.GetCursorPos()
	local gem = mq.FindTextureAnimation('A_SpellGemHolder')

	-- draw gem holder
	ImGui.SetCursorPos(cursor_x -1, cursor_y)
	ImGui.DrawTextureAnimation(gem, scale*(iconSize +12), scale*(iconSize+2) )

	ImGui.SetCursorPos(cursor_x, cursor_y)
	if iconID == -1 then
		-- no spell in this slot
		return
	end

	-- draw spell icon
	animSpell:SetTextureCell(iconID or 0)	
	ImGui.SetCursorPos(cursor_x + (scale *8), cursor_y +(5 * scale) )
	ImGui.DrawTextureAnimation(animSpell, scale*(iconSize - 4), scale*(iconSize - 5))
	
	----------- overlay ----------------
	ImGui.SetCursorPos(cursor_x, cursor_y - 2)
	local OverlayColor = IM_COL32(0, 0, 0, 0.9 * 255)
	local startPos = ImGui.GetCursorScreenPosVec()
	local endPos
	local recast = spell.sRecast -- + spell.sCastTime
	
	local diff = currentTime - spell.sClicked
	local remaining = recast - diff
	local percent = remaining / recast

	if diff >= recast then
		spellBar[i].sClicked = -1
	end

	if not mq.TLO.Cast.Ready('"' .. spell.sName .. '"')() then
		-- spell is not ready to cast
		ImGui.SetCursorPos(cursor_x + (scale *8), cursor_y +(5 * scale) )
		if spell.sClicked > 0 then
			-- spell was cast and is on cooldown
			if percent < 0 then percent = 0 end -- Ensure percent is not negative
			OverlayColor = IM_COL32(21,2,2,238)
			startPos = ImGui.GetCursorScreenPosVec()
			-- adjust the height of the overlay based on the remaining time
			local adjustedHeight = (scale*(iconSize -5)) * percent
			endPos = ImVec2(startPos.x + ((iconSize )*scale)  , startPos.y + ((iconSize -5)* scale))
			startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
			-- draw the overlay
			ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
			ImGui.SetCursorPos(cursor_x + (scale* (iconSize / 2)), cursor_y + (scale * (iconSize / 2)))
			-- print the remaining time

			ImGui.Text("%d", remaining )--1)
		
		else
			-- spell is not ready to cast and was not clicked most likely from global cooldown or just memmed
			-- draw the overlay
			ImGui.SetCursorPos(cursor_x + (scale *8), cursor_y +(5 * scale) )
			OverlayColor = IM_COL32(0,0,0,255)
			startPos = ImGui.GetCursorScreenPosVec()
			local adjustedHeight = (iconSize -5) * scale
			endPos = ImVec2(startPos.x + ((iconSize )*scale)  , startPos.y + ((iconSize -5)* scale))
			startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
			ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
			ImGui.SetCursorPos(cursor_x + (iconSize / 2), cursor_y + (iconSize / 2))
		end
		-- draw the gem Color overlay faded out to show the spell is not ready
		ImGui.SetCursorPos(cursor_x , cursor_y + 1)
		ImGui.Image(pickColor(spell.sID):GetTextureID(), ImVec2(scale*(iconSize + 37), scale*(iconSize + 2)))
		ImGui.SetCursorPos(cursor_x , cursor_y + 1)
		ImGui.Image(pickColor(spell.sID):GetTextureID(), ImVec2(scale*(iconSize + 37), scale*(iconSize + 2)), ImVec2(0, 0), ImVec2(1,1), ImVec4(0,0,0,0.85))
	else
		-- draw the gem Color overlay
		ImGui.SetCursorPos(cursor_x , cursor_y + 1)
		ImGui.Image(pickColor(spell.sID):GetTextureID(), ImVec2(scale*(iconSize + 37), scale*(iconSize + 2)))
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
	ImGui.InvisibleButton(sName, ImVec2(scale * iconSize, scale * iconSize), bit32.bor(ImGuiButtonFlags.MouseButtonRight))
	ImGui.PopID()
end

local function GetSpells(slot)
	local bonusGems = mq.TLO.Me.AltAbility('Mnemonic Retention').Rank() or 0
	numGems = 8 + bonusGems

	local function GetInfo(slotNum)
		local sToolTip = mq.TLO.Window(string.format('CastSpellWnd/CSPW_Spell%s',slotNum-1)).Tooltip()
		local sName
		local sRecast
		local sClicked 
		local sID, sIcon
		local sCastTime
		if spellBar[slotNum] == nil then
			spellBar[slotNum] = {}
		end
		if spellBar[slotNum].sClicked == nil then
			spellBar[slotNum].sClicked = -1
		end
	
		if sToolTip:find("%)%s") then
			sName = mq.TLO.Me.Gem(slotNum).Name()--sToolTip:sub(sToolTip:find("%)%s")+2,-1)
			sID = mq.TLO.Spell(sName).ID() or -1
			sClicked = spellBar[slotNum].sClicked or -1
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
			
		spellBar[slotNum].sCastTime = sCastTime
		spellBar[slotNum].sName = sName
		spellBar[slotNum].sID = sID
		spellBar[slotNum].sIcon = sIcon
		spellBar[slotNum].sClicked = sClicked
		spellBar[slotNum].sRecast = sRecast
	end

	if slot == nil then
		for i = 1, numGems do
			GetInfo(i)
		end
	else
		GetInfo(slot)
	end

end

local function SaveSet(SetName)
	settings = dofile(configFile)
	if settings[script][meName].Sets[SetName] == nil then
		settings[script][meName].Sets[SetName] = {}
	end
	
	settings[script][meName].Sets[SetName] = spellBar

	mq.pickle(configFile, settings)
	settings = dofile(configFile)
	tmpName = ''
end

local function LoadSet(set)
	-- print("Loading Set: ", set)
	local setBar = settings[script][meName].Sets[set]
	mq.TLO.Window('SpellBookWnd').DoOpen()
	mq.delay(5)
	for i = 1, numGems do
		if setBar[i].sName ~= nil then
			if mq.TLO.Me.Gem(i).Name() ~= setBar[i].sName then
				setBar[i].sClicked = os.time()
				spellBar[i]  = setBar[i]
				if setBar[i].sName ~= "Empty" then
					mq.cmdf("/memspell %d \"%s\"", i, setBar[i].sName)
					-- printf("/memspell %d \"%s\"", i, setBar[i].sName)
				end

				while mq.TLO.Me.Gem(i).Name() ~= setBar[i].sName do
					if not mq.TLO.Window('SpellBookWnd').Open() then
						spellBar[i].sName = 'Empty'
						spellBar[i].sID = -1
						spellBar[i].sIcon = -1
						spellBar[i].sClicked = -1
						spellBar[i].sRecast = -1
						spellBar[i].sCastTime = -1
						GetSpells(i)
						loadSet = false
						return
					end
				end
			end
		end
	end
	mq.TLO.Window('SpellBookWnd').DoClose()
	mq.delay(1)
	loadSet = false
end

local function ClearGems()
	for i = 1, numGems do
		mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i-1)
		mq.delay(300)
		spellBar[i].sName = 'Empty'
		spellBar[i].sID = -1
		spellBar[i].sIcon = -1
		spellBar[i].sClicked = -1
		spellBar[i].sRecast = -1
		spellBar[i].sCastTime = -1
	end
	clearAll = false
end

local function DrawConfigWin()
	if not configWindowShow then return end
	local ColorCountTheme, StyleCountTheme = LoadTheme.StartTheme(theme.Theme[themeID])
	local openTheme, showTheme = ImGui.Begin('Theme Selector##MySpells_',true,bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize))
	if not openTheme then
		configWindowShow = false
	end
	if not showTheme then
		LoadTheme.EndTheme(ColorCountTheme, StyleCountTheme)
		ImGui.End()
		return
	end
	ImGui.SeparatorText("Theme##MySpells")
			
	ImGui.Text("Cur Theme: %s", themeName)
	-- Combo Box Load Theme
	if ImGui.BeginCombo("Load Theme##MySpells", themeName) then
			
		for k, data in pairs(theme.Theme) do
			local isSelected = data.Name == themeName
			if ImGui.Selectable(data.Name, isSelected) then
				theme.LoadTheme = data.Name
				themeID = k
				
				themeName = theme.LoadTheme
				settings = dofile(configFile)
				settings[script].LoadTheme = themeName
				mq.pickle(configFile, settings)
			end
		end
		ImGui.EndCombo()
	end
	
	scale = ImGui.SliderFloat("Scale##DialogDB", scale, 0.8, 2)
	if scale ~= settings[script].Scale then
		if scale < 0.8 then scale = 0.8 end
		settings = dofile(configFile)
		settings[script].Scale = scale
		mq.pickle(configFile, settings)
	end

	if hasThemeZ then
		if ImGui.Button('Edit ThemeZ') then
			mq.cmd("/lua run themez")
		end
		ImGui.SameLine()
	end

	if ImGui.Button('Reload Theme File') then
		loadTheme()
	end
	LoadTheme.EndTheme(ColorCountTheme, StyleCountTheme)
	ImGui.End()
end

local function GUI_Spells()
	local winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize)
	if not aSize then winFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse) end
	local ColorCount, StyleCount =LoadTheme.StartTheme(theme.Theme[themeID])
	local open, show = ImGui.Begin(bIcon..'##MySpells_'..mq.TLO.Me.Name(), true, winFlags)
	if not open then
		RUNNING = false
		LoadTheme.EndTheme(ColorCount, StyleCount)
		ImGui.End()
		return
	end
	if show then
		-- ImGui.SetWindowFontScale(scale)
		-- Calculate maxRow to account for window padding and element size
		local windowWidth = ImGui.GetWindowWidth()
		maxRow = math.floor(windowWidth / (scale*44))
		if aSize then
			maxRow = settings[script].maxRow
		end
		currentTime = os.time()
		rowCount = 0
		
		if ImGui.BeginPopupContextItem("##MySpells_theme") then
			
			if ImGui.MenuItem("Configure") then
				configWindowShow = not configWindowShow
			end
			local aLabel = aSize and 'Disable Auto Size' or 'Enable Auto Size'
			if ImGui.MenuItem(aLabel) then
				aSize = not aSize
				settings = dofile(configFile)
				if aSize then
					settings[script].maxRow = maxRow
				end
				
				settings[script].AutoSize = aSize
				mq.pickle(configFile, settings)
			end
			ImGui.EndPopup()
		end
		ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0,0)
		for i = 1, numGems do
			ImGui.BeginChild("##SpellGem"..i, ImVec2(scale * 40, scale * 33), bit32.bor(ImGuiChildFlags.NoScrollbar,ImGuiChildFlags.AlwaysUseWindowPadding), bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))
			if spellBar[i].sID > -1 then
				DrawInspectableSpellIcon(spellBar[i].sIcon, spellBar[i], i)
				if ImGui.BeginPopupContextItem("##SpellGem"..i) then
					if ImGui.IsKeyDown(ImGuiMod.Ctrl) then ImGui.CloseCurrentPopup() end
					if ImGui.MenuItem("Memorize") then
						if pickerOpen == true then
							memSpell = -1
							picker:SetClose()
							pickerOpen = false
							picker:ClearSelection()
							casting = true
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
					ImGui.SetTooltip(string.format("%d) %s",i, spellBar[i].sName))        
					if ImGui.IsMouseReleased(0) then
						mq.cmdf("/cast %s", i)
						casting = true
						spellBar[i].sClicked = os.time()
					elseif ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsMouseReleased(1) then
						mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i-1)
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
			rowCount = rowCount + 1

			if rowCount < maxRow then
				ImGui.SameLine()
			else
				rowCount = 0
			end
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

		ImGui.BeginChild("##SpellBook", ImVec2(40 * scale , scale * 40), bit32.bor(ImGuiChildFlags.AlwaysUseWindowPadding, ImGuiChildFlags.NoScrollbar), bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))
		local cursor_x, cursor_y = ImGui.GetCursorPos()
		
		if mq.TLO.Window('SpellBookWnd').Open() then
			ImGui.SetCursorPos(cursor_x, cursor_y)
			ImGui.Image(openBook:GetTextureID(), ImVec2(scale * 39, scale * 22))
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip("Close Spell Book")
				if ImGui.IsMouseReleased(0) then
					mq.TLO.Window('SpellBookWnd').DoClose()
				end
			end
		else
			ImGui.SetCursorPos(cursor_x, cursor_y)
			ImGui.Image(closedBook:GetTextureID(), ImVec2(39 * scale , scale * 22))
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip("Open Spell Book")
				if ImGui.IsMouseReleased(0) then
					mq.TLO.Window('SpellBookWnd').DoOpen()
				end
			end
		end

		if ImGui.BeginPopupContextWindow("##SpellBook") then
			ImGui.SeparatorText("Save Set")
			ImGui.SetNextItemWidth(150)
			tmpName = ImGui.InputText("##SetName", tmpName)
			ImGui.SameLine()
			if ImGui.Button("Save Set") then
				if tmpName ~= '' then
					setName = tmpName
					SaveSet(setName)
					ImGui.CloseCurrentPopup()
				end
			end
			ImGui.SeparatorText("Load Set")
			ImGui.SetNextItemWidth(150)
			if ImGui.BeginCombo("##LoadSet", setName) then
				for k, data in pairs(settings[script][meName].Sets) do
					local isSelected = k == setName
					if ImGui.Selectable(k, isSelected) then
						setName = k
					end
				end
				ImGui.EndCombo()
			end
			ImGui.SameLine()
			if ImGui.Button("Load Set") then
				loadSet = true
				ImGui.CloseCurrentPopup()
			end

			if setName ~= 'None' then
				if ImGui.Button("Delete Set") then
					settings = dofile(configFile)
					settings[script][meName].Sets[setName] = nil
					mq.pickle(configFile, settings)
					setName = 'None'
					tmpName = ''
					ImGui.CloseCurrentPopup()
				end
				ImGui.SameLine()
			end

			if ImGui.Button("Clear Gems") then
				clearAll = true
			end
			ImGui.EndPopup()
		end
		ImGui.SetWindowFontScale(1)
		ImGui.EndChild()
		
	end
	LoadTheme.EndTheme(ColorCount, StyleCount)
	ImGui.End()
	
	if configWindowShow then
		DrawConfigWin()
	end

end

local function MemSpell(line, spell)
	for i = 1, numGems do
		if spellBar[i].sName == spell then
			spellBar[i].sClicked = os.time()
			casting = true
			break
		end
	end
end

local function CheckCasting()
	if mq.TLO.Window('CastingWindow').Open() and not casting then
		for i = 1, numGems do
			if spellBar[i].sName == mq.TLO.Window('CastingWindow').Child('Casting_SpellName').Text() then
				spellBar[i].sClicked = os.time()
				casting = true
				break
			end
		end
	else casting = false end
end

local function Init()
	meName = mq.TLO.Me.Name()
	if mq.TLO.Me.MaxMana() == 0 then print("You are not a caster!") RUNNING = false return end
	loadSettings()
	if File_Exists(themezDir) then
		hasThemeZ = true
	end
	picker:InitializeAbilities()
	mq.event("mem_spell", "You have finished memorizing #1#.#*#", MemSpell)
	GetSpells()
	mq.delay(1000)
	mq.imgui.init('GUI_MySpells', GUI_Spells)
end

local function Loop()
	while RUNNING do
		mq.doevents()
		if loadSet then LoadSet(setName) end
		if clearAll then ClearGems() end
		CheckCasting()
		if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atMySpells\ax] \arNot in game, \ayTry again later...") mq.exit() end
		mq.delay(500)
		picker:Reload()
		GetSpells()
	end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atMySpells\ax] \arNot in game, \ayTry again later...") mq.exit() end
Init()
Loop()