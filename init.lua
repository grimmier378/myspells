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
local gIcon = Icon.MD_SETTINGS
local LoadTheme = require('lib.theme_loader')
local themeID = 1
local theme, castTheme, defaults, settings, timerColor = {}, {}, {}, {}, {}
local themeFileOld = string.format('%s/MyThemeZ.lua', mq.configDir)
local configFileOld = mq.configDir .. '/myui/MySpells_Configs.lua'
local configFileOld2 = ''
local themeFile = string.format('%s/MyUI/MyThemeZ.lua', mq.configDir)
local configFile = ''
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
local aSize, locked,castLocked, hasThemeZ, configWindowShow, loadSet, clearAll, CastTextColorByType = false, false, false, false, false, false, false, false
local meName
local setName = 'None'
local tmpName = ''
local showTitle, showTitleCasting = true, false
local interrupted = false
local enableCastBar = false
local debugShow = false
local castTransparency = 1.0
local startedCast, startCastTime, castBarShow = false, 0, false
defaults = {
	Scale = 1.0,
	LoadTheme = 'Default',
	locked = false,
	CastLocked = false,
	CastTransperancy = 1.0,
	ShowTitleCasting = false,
	ShowTitleBar = true,
	enableCastBar = false,
	CastTextColorByType = false,
	IconSize = 30,
	TimerColor = {1,1,1,1},
	maxRow = 1,
	AutoSize = false,
}

local function pickColor(spellID)
	local spell = mq.TLO.Spell(spellID)
	local categoryName = spell.Category()
	local subcaterogy = spell.Subcategory()
	local targetType = spell.TargetType()
	if targetType == 'Single' or targetType == 'Line of Sight' or targetType == 'Undead' or categoryName == 'Taps' then
		return redGem, ImVec4(0.9, 0.1, 0.1, 1)
	elseif targetType == 'Self' then
		return yellowGem, ImVec4(1, 1, 0, 1)
	elseif targetType == 'Group v2' or targetType == 'Group v1' or targetType == 'AE PC v2' then
		return purpleGem, ImVec4(0.8, 0.0, 1.0, 1.0)
	elseif targetType == 'Beam' then
		return blueGem , ImVec4(0, 1, 1, 1)
	elseif targetType == 'Targeted AE' and (categoryName == 'Utility Detrimental' or spell.PushBack() > 0 or spell.AERange() < 20) then
		return greenGem, ImVec4(0, 1, 0, 1)
	elseif targetType == 'Targeted AE' then
		return orangeGem, ImVec4( 1.0, 0.76, 0.03, 1.0)
	elseif targetType == 'PB AE' then
		return blueGem, ImVec4(0, 1, 1, 1)
	elseif targetType == 'Pet' then
		return redGem, ImVec4(0.9, 0.1, 0.1, 1)
	elseif targetType == 'Pet2' then
		return redGem, ImVec4(0.9, 0.1, 0.1, 1)
	elseif targetType == 'Free Target' then
		return greenGem, ImVec4(0, 1, 0, 1)
	else
		return redGem, ImVec4(1,1,1,1)
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
		castTheme = dofile(themeFile)
	else
		if File_Exists(themeFileOld) then
			theme = dofile(themeFileOld)
			castTheme = dofile(themeFileOld)
		else
			theme = require('themes')-- your local themes file incase the user doesn't have one in config folder
			castTheme =  require('themes') 
		end
		mq.pickle(themeFile, theme)
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
		if File_Exists(configFileOld2) then
			settings = dofile(configFileOld2)
			mq.pickle(configFile, settings)
		else
			if File_Exists(configFileOld) then
				settings = dofile(configFileOld)
			else
				settings[script] = defaults
			end
			mq.pickle(configFile, settings)
		end
	else
		-- Load settings from the Lua config file

		settings = dofile(configFile)
		if settings[script] == nil then
			settings[script] = {}
			settings[script] = defaults 
			newSetting = true
		end
	end

	-- check for new settings and add them to the settings file
	for k, v in pairs(defaults) do
		if settings[script][k] == nil then
			settings[script][k] = v
			newSetting = true
		end
	end

	if settings[script][meName] == nil then
		settings[script][meName] = {}
		settings[script][meName].Sets = {}
		newSetting = true
	end

	loadTheme()

	-- Set the settings to the variables
	CastTextColorByType = settings[script].CastTextColorByType
	castTransparency = settings[script].CastTransperancy
	showTitleCasting = settings[script].ShowTitleCasting
	castLocked = settings[script].CastLocked
	enableCastBar = settings[script].EnableCastBar
	showTitle = settings[script].ShowTitleBar
	maxRow = settings[script].maxRow
	aSize = settings[script].AutoSize
	iconSize = settings[script].IconSize
	locked = settings[script].locked
	scale = settings[script].Scale
	themeName = settings[script].LoadTheme
	timerColor = settings[script].TimerColor
	if newSetting then mq.pickle(configFile, settings) end

end

local function MemSpell(line, spell)
	-- print("Memorized: ", spell)
	for i = 1, numGems do
		if spellBar[i].sName == spell then
			mq.delay(1)
			spellBar[i].sClicked = os.time()
			break
		end
	end
end

local function CastDetect(line, spell)
	-- print("Memorized: ", spell)
	if not startedCast then
		startedCast = true
		startCastTime = os.time()
	end
end

local function InterruptSpell()
	casting = false
	interrupted = true
end

local function CheckCasting()
	if mq.TLO.Me.Casting() ~= nil  then
		castBarShow = true
		for i = 1, numGems do
			if spellBar[i].sName == mq.TLO.Me.Casting() then
				spellBar[i].sClicked = os.time()
				casting = true
				break
			end
		end
	else
		casting = false
		castBarShow = false
		startedCast = false
		startCastTime = 0
	end
end

function CalculateColor(minColor, maxColor, value)
	-- Ensure value is within the range of 0 to 100
	value = math.max(0, math.min(100, value))

	-- Calculate the proportion of the value within the range
	local proportion = value / 100

	-- Interpolate between minColor and maxColor based on the proportion
	local r = minColor[1] + proportion * (maxColor[1] - minColor[1])
	local g = minColor[2] + proportion * (maxColor[2] - minColor[2])
	local b = minColor[3] + proportion * (maxColor[3] - minColor[3])
	local a = minColor[4] + proportion * (maxColor[4] - minColor[4])

	return r, g, b, a
end

--- comments
---@param iconID integer
---@param spell table
---@param i integer
local function DrawInspectableSpellIcon(iconID, spell, i)
	CheckCasting()
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
	local fizz = spell.sFizzle
	local diff = currentTime - spell.sClicked
	local remaining = recast - diff
	local percent = remaining / recast
	if interrupted then
		spell.sClicked = os.time()
		remaining = fizz
		percent = remaining / fizz
	end
	if diff >= recast then
		spellBar[i].sClicked = -1
	end

	if not mq.TLO.Cast.Ready(i)() then
		-- spell is not ready to cast
		ImGui.SetCursorPos(cursor_x + (scale *8), cursor_y +(5 * scale) )
		if spell.sClicked > 0 then
			-- spell was cast and is on cooldown
			if percent < 0 then percent = 0 end -- Ensure percent is not negative
			startPos = ImGui.GetCursorScreenPosVec()
			local oStart = startPos
			-- timer background overlay
			OverlayColor = IM_COL32(2,2,2,88)
			local adjustedHeight = (scale*(iconSize -5))
			endPos = ImVec2(startPos.x + ((iconSize )*scale)  , startPos.y + ((iconSize -5)* scale))
			startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
			ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
			startPos = oStart

			-- adjust the height of the overlay based on the remaining time
			OverlayColor = IM_COL32(41,2,2,190)
			adjustedHeight = (scale*(iconSize -5)) * percent
			endPos = ImVec2(startPos.x + ((iconSize )*scale)  , startPos.y + ((iconSize -5)* scale))
			startPos = ImVec2(startPos.x, endPos.y - adjustedHeight)
			-- draw the overlay
			ImGui.GetWindowDrawList():AddRectFilled(startPos, endPos, OverlayColor)
			-- set the cursor for timer display
			ImGui.SetCursorPos(cursor_x + (scale* (iconSize / 2)), cursor_y + (scale * (iconSize / 2)))
			-- print the remaining time
			if not spellBar[i].sName == mq.TLO.Window('CastingWindow').Open() then
				ImGui.TextColored(ImVec4(timerColor[1], timerColor[2],timerColor[3],timerColor[4]), "%d", remaining )
			elseif spellBar[i].sName ~= mq.TLO.Window('CastingWindow').Child('Casting_SpellName').Text() then
				ImGui.TextColored(ImVec4(timerColor[1], timerColor[2],timerColor[3],timerColor[4]), "%d", remaining )
			end
		else
			-- spell is not ready to cast and was not clicked most likely from global cooldown or just memmed
			-- draw the overlay
			ImGui.SetCursorPos(cursor_x + (scale *8), cursor_y +(5 * scale) )
			OverlayColor = IM_COL32(0,0,0,190)
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
		spell.sClicked = -1
	end

	if mq.TLO.Cast.Ready(i)() then
		if currentTime - spell.sClicked > spell.sCastTime + 3 or spell.sClicked == -1 then
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
		local sID, sIcon, sFizzle
		local sCastTime
		if spellBar[slotNum] == nil then
			spellBar[slotNum] = {}
		end
		if spellBar[slotNum].sClicked == nil then
			spellBar[slotNum].sClicked = -1
		end

		if sToolTip:find("%)%s") then
			sName = mq.TLO.Me.Gem(slotNum).Name()
			sID = mq.TLO.Spell(sName).ID() or -1
			sClicked = spellBar[slotNum].sClicked or -1
			sRecast = mq.TLO.Spell(sName).RecastTime.Seconds() or -1
			sIcon = mq.TLO.Spell(sName).SpellIcon()	or -1
			sCastTime = mq.TLO.Spell(sName).MyCastTime.Seconds() or -1
			sFizzle = mq.TLO.Spell(sName).FizzleTime() or -1
		else
			sName = "Empty"
			sID = -1
			sIcon = -1
			sClicked = -1
			sRecast = -1
			sCastTime = -1
			sFizzle = -1
		end

		spellBar[slotNum].sCastTime = sCastTime
		spellBar[slotNum].sName = sName
		spellBar[slotNum].sID = sID
		spellBar[slotNum].sIcon = sIcon
		spellBar[slotNum].sClicked = sClicked
		spellBar[slotNum].sFizzle = sFizzle
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
	if settings[script][meName].Sets[SetName] == nil then
		settings[script][meName].Sets[SetName] = {}
	end
	settings[script][meName].Sets[SetName] = spellBar
	mq.pickle(configFile, settings)
	settings = dofile(configFile)
	tmpName = ''
end

local function LoadSet(set)
	loadSet = false
	local setBar  = {}
	for i, t in pairs(settings[script][meName].Sets[set]) do
		setBar[i] = {}
		for k, v in pairs(t) do
			setBar[i][k] = v
		end
	end
	mq.TLO.Window('SpellBookWnd').DoOpen()
	mq.delay(5)
	for i = 1, numGems or 8 do
		GetSpells(i)
		if setBar[i] ~= nil then
			if setBar[i].sName ~= nil then
				if mq.TLO.Me.Gem(i).Name() ~= setBar[i].sName then
					if setBar[i].sName ~= "Empty" then
						mq.cmdf("/memspell %d \"%s\"", i, setBar[i].sName)
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
							setName = 'None'
							return
						end
					end
					spellBar[i]  = setBar[i]
				end
			end
		end
	end
	mq.TLO.Window('SpellBookWnd').DoClose()
	mq.delay(1)
	setName = 'None'
end

local function ClearGems()
	for i = 1, numGems do
		mq.cmdf("/nomodkey /altkey /notify CastSpellWnd CSPW_Spell%s rightmouseup", i-1)
		mq.delay(5000, function () return mq.TLO.Me.Gem(i)() == nil end)
		spellBar[i].sName = 'Empty'
		spellBar[i].sID = -1
		spellBar[i].sIcon = -1
		spellBar[i].sClicked = -1
		spellBar[i].sRecast = -1
		spellBar[i].sCastTime = -1
	end
	GetSpells()
	clearAll = false
end

local function DrawConfigWin()
	if not configWindowShow then return end
	local ColorCountTheme, StyleCountTheme = LoadTheme.StartTheme(theme.Theme[themeID])
	local openTheme, showTheme = ImGui.Begin('Config##MySpells_',true,bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing))
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
			end
		end
		ImGui.EndCombo()
	end

	scale = ImGui.SliderFloat("Scale##DialogDB", scale, 0.5, 2)
	if scale ~= settings[script].Scale then
		if scale < 0.5 then scale = 0.5 end
		if scale > 2 then scale = 2 end
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

	ImGui.SeparatorText("General Settings##MySpells")
	if mq.TLO.Me.Class.ShortName() ~= 'BRD' then
		castTransparency = ImGui.SliderFloat("Cast Bar Transparency##MySpells", castTransparency, 0.0, 1.0)
		enableCastBar = ImGui.Checkbox("Enable Cast Bar##MySpells", enableCastBar)
		if enableCastBar then
			ImGui.SameLine()
			debugShow = ImGui.Checkbox("Force Show CastBar##MySpells", debugShow)
			CastTextColorByType = ImGui.Checkbox("Cast Text Color By Type##MySpells", CastTextColorByType)
			ImGui.SameLine()
			ImGui.HelpMarker("This will change the color of the cast bar text based on the spell type.")
		end
	end
	timerColor, _ = ImGui.ColorEdit4("Timer Color##MySpells", timerColor, ImGuiColorEditFlags.AlphaBar)
	ImGui.SameLine()
	ImGui.HelpMarker("This will change the color of the timer text on the spell gems.\nThis is also the Text Default color for the Cast Bar.")
	if ImGui.Button("Save & Close") then
		settings[script].CastTextColorByType = CastTextColorByType
		settings[script].CastTransperancy = castTransparency
		settings[script].EnableCastBar = enableCastBar
		settings[script].Scale = scale
		settings[script].TimerColor = timerColor
		settings[script].LoadTheme = themeName
		mq.pickle(configFile, settings)
		configWindowShow = false
	end
	LoadTheme.EndTheme(ColorCountTheme, StyleCountTheme)
	ImGui.End()
end

local function GUI_Spells()
	local winFlags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoFocusOnAppearing)
	if not aSize then winFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse) end
	if locked then winFlags = bit32.bor(winFlags, ImGuiWindowFlags.NoMove) end
	if not showTitle then winFlags = bit32.bor(winFlags, ImGuiWindowFlags.NoTitleBar) end
	local ColorCount, StyleCount =LoadTheme.StartTheme(theme.Theme[themeID])
	local open, show = ImGui.Begin(bIcon..'##MySpells_'..mq.TLO.Me.Name(), true, winFlags)
	if not open then
		RUNNING = false
	end
	if show then
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
				if aSize then
					settings[script].maxRow = maxRow
				end
				settings[script].AutoSize = aSize
				mq.pickle(configFile, settings)
			end
			local lockLabel = locked and 'Unlock' or 'Lock'
			if ImGui.MenuItem(lockLabel) then
				locked = not locked
				settings[script].locked = locked
				mq.pickle(configFile, settings)
			end
			local titleBarLabel = showTitle and 'Hide Title Bar' or 'Show Title Bar'
			if ImGui.MenuItem(titleBarLabel) then
				showTitle = not showTitle
				settings[script].ShowTitleBar = showTitle
				mq.pickle(configFile, settings)
			end
			ImGui.EndPopup()
		end
		ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0,0)
		for i = 1, numGems do
			ImGui.BeginChild("##SpellGem"..i, ImVec2(scale * 40, scale * 33), bit32.bor(ImGuiChildFlags.NoScrollbar,ImGuiChildFlags.AlwaysUseWindowPadding), bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))
			if spellBar[i] ~= nil then
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
						end
							memSpell = i
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
				if not casting and interrupted then
					spellBar[i].sClicked = -1
					interrupted = false
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
						end
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
		if memSpell ~= -1 and not picker.Draw then -- and not pickerOpen then
			ImGui.SetNextWindowPos(ImGui.GetMousePosOnOpeningCurrentPopupVec(), ImGuiCond.Appearing)
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
			ImGui.Text(gIcon)
			if ImGui.IsItemHovered() then
				ImGui.SetTooltip("Config")
				if ImGui.IsMouseReleased(0) then
					configWindowShow = not configWindowShow
					ImGui.CloseCurrentPopup()
				end
			end
			ImGui.SameLine()
			local rIcon = aSize and Icon.FA_EXPAND or Icon.FA_COMPRESS
			ImGui.Text(rIcon)
			if ImGui.IsItemHovered() then
				local label = aSize and "Disable Auto Size" or "Enable Auto Size"
				ImGui.SetTooltip(label)
				if ImGui.IsMouseReleased(0) then
					aSize = not aSize

					if aSize then
						settings[script].maxRow = maxRow
					end
					settings[script].AutoSize = aSize
					mq.pickle(configFile, settings)
					ImGui.CloseCurrentPopup()
				end
			end
			ImGui.SameLine()
			local lIcon = locked and Icon.FA_LOCK or Icon.FA_UNLOCK
			ImGui.Text(lIcon)
			if ImGui.IsItemHovered() then
				local label = locked and "Unlock" or "Lock"
				ImGui.SetTooltip(label)
				if ImGui.IsMouseReleased(0) then
					locked = not locked

					settings[script].locked = locked
					mq.pickle(configFile, settings)
					ImGui.CloseCurrentPopup()
				end
			end
			ImGui.SameLine()
			local tIcon = showTitle and Icon.FA_EYE_SLASH or Icon.FA_EYE
			ImGui.Text(tIcon)
			if ImGui.IsItemHovered() then
				local label = showTitle and "Hide Title Bar" or "Show Title Bar"
				ImGui.SetTooltip(label)
				if ImGui.IsMouseReleased(0) then
					showTitle = not showTitle
					settings[script].ShowTitleBar = showTitle
					mq.pickle(configFile, settings)
					ImGui.CloseCurrentPopup()
				end
			end
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
				if setName ~= 'None' then
					loadSet = true
				end
				ImGui.CloseCurrentPopup()
			end

			if setName ~= 'None' then
				if ImGui.Button("Delete Set") then
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
				ImGui.CloseCurrentPopup()
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

	if enableCastBar and (castBarShow or debugShow) then
		local castFlags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.NoFocusOnAppearing)
		if castLocked then castFlags = bit32.bor(castFlags, ImGuiWindowFlags.NoMove) end
		if not showTitleCasting then castFlags = bit32.bor(castFlags, ImGuiWindowFlags.NoTitleBar) end
		castTheme.Theme[themeID].Color[2].Color[4] = castTransparency
		local ColorCountCast, StyleCountCast = LoadTheme.StartTheme(castTheme.Theme[themeID])
		ImGui.SetNextWindowSize(ImVec2(150, 55), ImGuiCond.FirstUseEver)
		ImGui.SetNextWindowPos(ImGui.GetMousePosVec(), ImGuiCond.FirstUseEver)

		local openCast, showCast = ImGui.Begin('Casting##MyCastingWin_'..mq.TLO.Me.Name(), true, castFlags)
		if not openCast then
			castBarShow = false
		end
		if showCast or debugShow then
			local castingName = mq.TLO.Me.Casting.Name() or nil
			local castTime = mq.TLO.Spell(castingName).MyCastTime() or 0
			local spellID = mq.TLO.Spell(castingName).ID() or -1
			if castingName == nil then
				startCastTime = 0
				castBarShow = false
			end
			if (castingName ~= nil and startCastTime ~= 0) or debugShow then
				ImGui.BeginChild("##CastBar", ImVec2(-1,-1), bit32.bor(ImGuiChildFlags.NoScrollbar, ImGuiChildFlags.NoScrollWithMouse), bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse))
				local diff = os.time() - startCastTime
				local remaining = mq.TLO.Me.CastTimeLeft() <= castTime and mq.TLO.Me.CastTimeLeft() or 0
				-- if remaining < 0 then remaining = 0 end
				local colorHpMin = {0.0, 1.0, 0.0, 1.0}
				local colorHpMax = {1.0, 0.0, 0.0, 1.0}
				local hr,hg,hb,ha = CalculateColor(colorHpMin, colorHpMax, (remaining / castTime * 100))
				ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(hr, hg, hb, ha))
				ImGui.ProgressBar(remaining / castTime , ImVec2(ImGui.GetWindowWidth(), 15), '')
				ImGui.PopStyleColor()
				local lbl = remaining > 0 and string.format("%.1f",(remaining / 1000)) or '0'
				local _, colorSetting = pickColor(spellID)
				if not CastTextColorByType then
					colorSetting = ImVec4(timerColor[1], timerColor[2],timerColor[3],timerColor[4])
				end
				ImGui.TextColored(colorSetting, "%s %ss",castingName, lbl )
				ImGui.EndChild()
			end
			if ImGui.BeginPopupContextItem("##MySpells_CastWin") then
				local lockLabel = castLocked and 'Unlock' or 'Lock'
				if ImGui.MenuItem(lockLabel.."##Casting") then
					castLocked = not castLocked
					settings[script].CastLocked = castLocked
					mq.pickle(configFile, settings)
				end
				local titleBarLabel = showTitleCasting and 'Hide Title Bar' or 'Show Title Bar'
				if ImGui.MenuItem(titleBarLabel.."##Casting") then
					showTitleCasting = not showTitleCasting
					settings[script].ShowTitleCasting = showTitleCasting
					mq.pickle(configFile, settings)
				end
				ImGui.EndPopup()
			end
		end
		LoadTheme.EndTheme(ColorCountCast, StyleCountCast)
		ImGui.End()
	end

end

local function Init()
	meName = mq.TLO.Me.Name()
	if mq.TLO.Me.MaxMana() == 0 then print("You are not a caster!") RUNNING = false return end
	configFileOld2 = string.format('%s/myui/MySpells/MySpells_%s_Configs.lua',mq.configDir ,meName)
	configFile = string.format('%s/myui/MySpells/%s/MySpells_%s.lua', mq.configDir, mq.TLO.EverQuest.Server(), meName)
	loadSettings()
	if File_Exists(themezDir) then
		hasThemeZ = true
	end
	picker:InitializeAbilities()
	mq.event("mem_spell", "You have finished memorizing #1#.#*#", MemSpell)
	mq.event("int_spell", "Your spell is interrupted.", InterruptSpell)
	mq.event("fiz_spell", "Your#*#spell fizzles#*#", InterruptSpell)
	mq.event('cast_start',"You begin casting #1#.#*#", CastDetect)
	GetSpells()
	mq.delay(16)
	mq.imgui.init('GUI_MySpells', GUI_Spells)
end

local function Loop()
	while RUNNING do
		mq.doevents()
		if loadSet then LoadSet(setName) end
		if clearAll then ClearGems() end
		if not picker.Draw then pickerOpen = false end
		CheckCasting()
		if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atMySpells\ax] \arNot in game, \ayTry again later...") mq.exit() end
		mq.delay(1)
		picker:Reload()
		GetSpells()
	end
end

if mq.TLO.EverQuest.GameState() ~= "INGAME" then print("\aw[\atMySpells\ax] \arNot in game, \ayTry again later...") mq.exit() end
Init()
Loop()