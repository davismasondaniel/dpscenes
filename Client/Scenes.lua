Scenes = {}
Scene = {}
Presets = {}
Cache = {}          -- Cache.Time = server time at last sync, Cache.Received = GetGameTimer() at that moment
Cooldown = false
Hidden = false
MovingScene = false
Nearby = {}         -- only the scenes close enough to matter, rebuilt a few times a second

local DrawRange = 10.0
local InteractRange = 1.5
local RefreshRange = DrawRange + 8.0
local KeyE, KeyX = Keys["E"], Keys["X"]

function IncurCooldown(time)
	Cooldown = true
	CreateThread(function() Wait(time) Cooldown = false end)
end

-- This is the default scene options.
function ResetScene()
	Scene = {
		State = false,
		Info = false,
		Hours = Config.SceneLength[4].Hours,
		ShowAge = 1,
		Text = {Text = "", Font = 1, Size = Config.FontSize.Min, Outline = 1},
		Background = {
			Sprite = 1,
			Colour = {0,0,0},
			ColourName = "Black",
			Settings = {x = 0.00, y = 0.01, w = 0.01, h = 0.01, r = 0.00, o = 120}
		},
		Function = false
	}
end

-- (no longer leaks globals)
function SceneAge(sec)
	local Seconds = tonumber(sec) or 0
	if Seconds <= 0 then return {Hours = 0, Minutes = 0} end
	local Hours = math.floor(Seconds / 3600)
	return {Hours = Hours, Minutes = math.floor(Seconds / 60 - Hours * 60)}
end

-- Server time, extrapolated locally so the server doesn't have to broadcast it.
function ServerNow()
	if not Cache.Time then return nil end
	return Cache.Time + math.floor((GetGameTimer() - (Cache.Received or 0)) / 1000)
end

-- Text shown on a scene, including the age prefix. Built once per refresh instead of every frame.
function BuildText(i)
	if i.ShowAge ~= 1 then return i.Text.Text end
	local Age = Lang("Recent")
	local Now = ServerNow()
	if Now and i.Created then
		local Hours = math.floor((Now - tonumber(i.Created)) / 3600)
		if Hours > 1 then Age = Hours.." "..Lang("Hours") end
	end
	return "~m~["..Age.."]~w~ "..i.Text.Text
end

function SceneText(i, text, cam, fov)
	local Loc = i.Location
	local Active, _x, _y = World3dToScreen2d(Loc.x, Loc.y, Loc.z)
	if not Active then return end
	cam = cam or GetGameplayCamCoords()
	fov = fov or GetGameplayCamFov()
	local Font = (Fonts[i.Text.Font] or Fonts[1]).Font or 4
	local Scale = ((1 / #(cam - Loc)) * 2) * (1 / fov) * 80
	local RangeAlpha = 10 * math.floor(Scale * 40)
	if RangeAlpha > 225 then RangeAlpha = 225 elseif RangeAlpha < 40 then RangeAlpha = 40 end
	text = text or i.Text.Text
	local Size = i.Text.Size * Scale

	SetTextColour(255, 255, 255, RangeAlpha)
	SetTextScale(0.0, Size)
	SetTextFont(Font)
	SetTextProportional(1)
	SetTextCentre(true)
	SetTextWrap(0.0, 1.0)
	local Outline = i.Text.Outline
	if Outline == 1 then SetTextOutline() elseif Outline == 2 then SetTextDropshadow(1, 255, 255, 255, 0) end
	local Long = #text > 99
	BeginTextCommandWidth("THREESTRINGS")
	AddTextComponentString(text)
	if Long then SplitString(text) end
	local H = GetTextScaleHeight(Size, Font) + 0.0030
	local W = EndTextCommandGetWidth(Font) + 0.005

	SetTextEntry("THREESTRINGS")
	AddTextComponentString(text)
	if Long then SplitString(text) end
	EndTextCommandDisplayText(_x, _y)

	local Bg = i.Background
	if Bg then
		local Sprite = Config.BackgroundSprites[Bg.Sprite]
		if Sprite then
			local S, Col = Bg.Settings, Bg.Colour
			local Alpha = RangeAlpha
			if Alpha > S.o then Alpha = S.o end
			DrawSprite("dpscenes", Sprite.Sprite, _x+S.x*Scale, _y+S.y*Scale, W+S.w*Scale, H+S.h*Scale, S.r, Col[1], Col[2], Col[3], Alpha)
		end
	end
end

function HandleSceneInteract(i)
	if Cooldown then return false end
	local Interact = i.Function
	if Interact.Prefix then
		ExecuteCommand(Interact.Prefix.." "..Interact.Variable)
		IncurCooldown(1000) return true
	else
		local t = false
		for k,v in pairs(Config.SceneFunctions) do
			if v.Name == Interact.Current then
				t = v.Function
			end
		end
		if t then
			Chat(Lang("WaypointSet"))
			t(Interact.Variable)
			IncurCooldown(1000) return true
		end
	end
end

-- Draws one scene. text/cam/fov are optional; the main loop passes them in so they're fetched once per frame.
function DrawScene(i, p, text, cam, fov)
	local Dist = Distance(i.Location, p)
	if Dist >= DrawRange then return end
	SceneText(i, text or BuildText(i), cam, fov)
	if Dist >= InteractRange or Scene.State or not i.Function then return end
	local F = i.Function
	if F.Current == "GPS" then
		SetTextComponentFormat("TWOSTRINGS")
		AddTextComponentString(Lang("Interact"))
		AddTextComponentString("\n~b~"..string.format(F.Description or "N/A %s", F.String or "N/A"))
		EndTextCommandDisplayHelp(0,0,0,-1)
	elseif F.Current ~= "None" and F.Prefix then
		SetTextComponentFormat("TWOSTRINGS")
		AddTextComponentString(Lang("Interact"))
		AddTextComponentString("\n~b~/"..F.Prefix.." "..F.Variable)
		EndTextCommandDisplayHelp(0,0,0,-1)
	else
		return
	end
	if IsControlJustReleased(0, KeyE) then
		if not HandleSceneInteract(i) then Chat(Lang("CantRightNow")) end
	end
end

-- Rebuild the list of scenes worth drawing. Runs a few times a second (and on any network change),
-- instead of measuring every scene in the world every frame.
function RefreshNearby()
	local Pos = GetEntityCoords(PlayerPedId())
	local List = {}
	for _, v in pairs(Scenes) do
		if Distance(v.Location, Pos) < RefreshRange then
			List[#List+1] = {scene = v, text = BuildText(v)}
		end
	end
	Nearby = List
end

CreateThread(function()
	while true do
		Wait(250)
		if not Hidden then RefreshNearby() end
	end
end)

local function NearestScene(maxDist)
	local Pos = GetEntityCoords(PlayerPedId())
	local Id, Best = nil, maxDist
	for k, v in pairs(Scenes) do
		local Dis = Distance(Pos, v.Location)
		if Dis < Best then Id, Best = k, Dis end
	end
	return Id
end

RegisterCommand("sceneremove", function()
	local Id = NearestScene(3)
	if Id then TriggerServerEvent("Scene:AttemptDelete", Id) end
end)

RegisterCommand("scenecopylast", function()
	if LastCopiedScene then
		Scene = LastCopiedScene
		if not Scene.State then Scene.State = "Placing" end
	else
		Chat(Lang("NoLastCopied"))
	end
end)

RegisterCommand("scenecopy", function()
	local Id = NearestScene(3)
	if Id then
		TriggerServerEvent("Scene:AttemptCopy", Id)
	else
		Chat(Lang("CouldntFindCopy"))
	end
end)

RegisterCommand("scenemove", function()
	if Scene.State or MovingScene then
		Chat(Lang("CantRightNow"))
		return
	end
	local Id = NearestScene(3)
	if Id then
		StartMoveScene(Scenes[Id], Id)
	else
		Chat(Lang("CouldntFindMove"))
	end
end)

function StartMoveScene(scene, id)
	MovingScene = {
		Scene = scene,
		Id = id,
		OldLoc = scene.Location
	}
	TriggerServerEvent("Scene:AttemptDelete", id, true)
	Chat(Lang("ConfirmCancel"))
end

RegisterCommand("scenehide", function()
	Hidden = not Hidden
	if Hidden then Nearby = {} end
end)

function CreateSuggestions()
	TriggerEvent("chat:addSuggestion", "/scene", Lang("SceneDesc"), {
		{ name="text", help = Lang("SceneDesc2")},
	})
	TriggerEvent("chat:addSuggestion", "/sceneremove", Lang("SceneRemove"))
	TriggerEvent("chat:addSuggestion", "/scenehide", Lang("HideScenes"))
	TriggerEvent("chat:addSuggestion", "/scenecopy", Lang("CopySuggestion"))
	TriggerEvent("chat:addSuggestion", "/scenemove", Lang("MoveSuggestion"))
	TriggerEvent("chat:addSuggestion", "/scenecopylast", Lang("CopyLastSuggestion"))
	TriggerEvent("chat:addSuggestion", "/sceneresetpresets", Lang("ResetSuggestion"))
end

-- Main draw loop: full frame rate only while there is something nearby to draw.
local TextureDicts = {"dpscenes", "commonmenu"}
CreateThread(function()
	CreateSuggestions()
	CreateFonts()
	ResetScene()
	for k,v in pairs(TextureDicts) do while not HasStreamedTextureDictLoaded(v) do Wait(100) RequestStreamedTextureDict(v, true) end end
	TriggerServerEvent("Scene:Request")
	while true do
		if Hidden then
			Wait(1000)
		elseif #Nearby == 0 then
			Wait(300)
		else
			Wait(0)
			local Pos = GetEntityCoords(PlayerPedId())
			local Cam, Fov = GetGameplayCamCoords(), GetGameplayCamFov()
			local List = Nearby
			for n = 1, #List do
				local e = List[n]
				DrawScene(e.scene, Pos, e.text, Cam, Fov)
			end
		end
	end
end)

-- Placement helpers (shared by "new scene" and "move scene").
-- Returns coords, blockedReason, playerCoords (coords is nil if nothing valid is targeted).
local function PlacementTarget()
	local Player = GetEntityCoords(PlayerPedId())
	local Hit, Coords, Entity = RayCastGamePlayCamera(10.0)
	if not Hit or Distance(Player, Coords) >= 15 then return nil, nil, Player end
	local Info = {Entity = Entity, Coords = Coords, Player = Player}
	for _, v in ipairs(Config.Blacklist) do
		if v.Function(Info) then return Coords, v.Error, Player end
	end
	return Coords, nil, Player
end

local function DrawCursor(coords)
	DrawMarker(2, coords, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.06, 0.06, 0.06, 0, 200, 255, 255, false, true, false, nil, nil, false)
end

local function DrawBlocked(coords, reason)
	DrawMarker(28, coords, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.02, 0.02, 0.02, 255, 0, 0, 255, false, true, 2, nil, nil, false)
	SceneText({
		Text = {Text = reason, Font = 1, Size = 0.3, Outline = 1},
		Location = coords,
	})
end

CreateThread(function()
	while true do
		Wait((Scene.State or MovingScene) and 0 or 250)
		InvalidateIdleCam()
		if Scene.State then
			DrawMenu(Scene.State == "Placing")
			if IsControlJustPressed(0, KeyX) then
				ResetScene()
				Scene.State = false
			end
			local Coords, Blocked, Player = PlacementTarget()
			if Coords then
				if not Blocked then
					DrawCursor(Coords)
					Scene["Location"] = Coords
					DrawScene(Scene, Player, BuildText(Scene))
					if IsControlJustPressed(0, KeyE) then
						TriggerServerEvent("Scene:New", Scene)
						Wait(250)
					end
				else
					DrawBlocked(Coords, Blocked)
				end
			end
			if Scene.State == "Colour" then
				DrawColourSelect()
			elseif Scene.State == "Fonts" then
				DrawFonts()
			elseif Scene.State == "Functions" then
				DrawFunctions()
			elseif Scene.State == "Presets" then
				DrawPresets()
			end
			if Scene.Info then
				DrawInfo()
			end
		elseif MovingScene then
			local Coords, Blocked, Player = PlacementTarget()
			if Coords then
				if not Blocked then
					DrawCursor(Coords)
					MovingScene.Scene["Location"] = Coords
					DrawScene(MovingScene.Scene, Player, BuildText(MovingScene.Scene))
					if IsControlJustPressed(0, KeyE) then
						TriggerServerEvent("Scene:New", MovingScene.Scene)
						MovingScene = false
						Wait(250)
					end
				else
					DrawBlocked(Coords, Blocked)
				end
			end
			if MovingScene and IsControlJustPressed(0, KeyX) then
				MovingScene.Scene["Location"] = MovingScene.OldLoc
				TriggerServerEvent("Scene:New", MovingScene.Scene)
				MovingScene = false
				Wait(250)
			end
		end
	end
end)
