DB = {}

local function Clamp(v, min, max) return math.max(min, math.min(max, v)) end
local function Num(v, default) if type(v) == "number" and v == v then return v end return default end

-- Only prefixes that exist in Config.SceneFunctions may be stored (clients run these via ExecuteCommand).
local AllowedPrefix = {}
for _, f in ipairs(Config.SceneFunctions) do
	if f.Prefix then AllowedPrefix[(f.Prefix:gsub("^/", ""))] = true end
end

-- Never trust the client: rebuild the scene from known fields, with known-safe values.
-- (A malformed scene would otherwise throw errors inside every player's draw loop.)
function SanitiseScene(s)
	if type(s) ~= "table" or type(s.Text) ~= "table" or type(s.Text.Text) ~= "string" then return end
	if type(s.Location) ~= "vector3" then return end
	local Len = #s.Text.Text
	if Len <= 3 or Len > 280 then return end

	local Clean = {
		Hours = Clamp(math.floor(Num(s.Hours, 24)), 1, Config.MaxSceneLength),
		ShowAge = Num(s.ShowAge, 0),
		Text = {
			Text = s.Text.Text,
			Font = math.max(1, math.floor(Num(s.Text.Font, 1))),
			Size = Clamp(Num(s.Text.Size, Config.FontSize.Min), Config.FontSize.Min, Config.FontSize.Max),
			Outline = Num(s.Text.Outline, 1),
		},
		Location = s.Location,
		Function = false,
	}

	if type(s.Background) == "table" then
		local B = s.Background
		local Set = type(B.Settings) == "table" and B.Settings or {}
		local Col = type(B.Colour) == "table" and B.Colour or {}
		Clean.Background = {
			Sprite = Clamp(math.floor(Num(B.Sprite, 1)), 1, #Config.BackgroundSprites),
			Colour = {Clamp(Num(Col[1], 0), 0, 255), Clamp(Num(Col[2], 0), 0, 255), Clamp(Num(Col[3], 0), 0, 255)},
			Settings = {
				x = Clamp(Num(Set.x, 0.0), -5, 5), y = Clamp(Num(Set.y, 0.01), -5, 5),
				w = Clamp(Num(Set.w, 0.01), -5, 5), h = Clamp(Num(Set.h, 0.01), -5, 5),
				r = Clamp(Num(Set.r, 0.0), -360, 360), o = Clamp(Num(Set.o, 120), 0, 255),
			},
		}
	end

	local F = s.Function
	if F then
		if type(F) ~= "table" then return end
		if F.Prefix then
			if not AllowedPrefix[F.Prefix] or type(F.Current) ~= "string" or type(F.Variable) ~= "string"
				or #F.Variable > 90 or F.Variable:find("[%c;]") then return end
			Clean.Function = {Current = F.Current, Prefix = F.Prefix, Variable = F.Variable}
		elseif F.Current == "GPS" and type(F.Variable) == "vector3" then
			Clean.Function = {
				Current = "GPS", Prefix = false, Variable = F.Variable,
				Description = "Set your waypoint to %s?", -- fixed: a client-supplied format string could break every client
				String = tostring(F.String or ""):sub(1, 60),
			}
		else
			return
		end
	end
	return Clean
end

function PrepareSceneForDatabase(s)
	return json.encode(s)
end

local AdminSet = nil
function CanDeleteAnyScene(Identifier)
	if not AdminSet then
		AdminSet = {}
		for _, id in ipairs(Admins) do AdminSet[id] = true end
	end
	return AdminSet[Identifier] == true
end

local LastNew = {}
AddEventHandler("playerDropped", function() LastNew[source] = nil end)

RegisterNetEvent("Scene:New")
AddEventHandler("Scene:New", function(New)
	local Src = source
	local Now = GetGameTimer()
	if LastNew[Src] and Now - LastNew[Src] < 500 then return end
	LastNew[Src] = Now

	local Id = GetLicense(Src, Config.IdentifierType)
	if not Id then return end
	local Scene = SanitiseScene(New)
	if not Scene then Chat(Src, Lang("InvalidText")) return end

	local Count = CountScenes(Id)
	if Count >= Config.MaxScenes then
		Chat(Src, string.format(Lang("TooMany"), Count))
	elseif CloseToOtherScene(Scene) then
		Chat(Src, Lang("TooClose"))
	else
		DB.NewScene(Scene, Src, Id, os.time(), PrepareSceneForDatabase(Scene))
		TriggerClientEvent("Scene:Reset", Src)
	end
end)

RegisterNetEvent("Scene:AttemptDelete")
AddEventHandler("Scene:AttemptDelete", function(Id, Move)
	local Src = source
	local SceneToDelete = Scenes.Current[Id]
	if not SceneToDelete then return end
	local Me = GetLicense(Src, Config.IdentifierType)
	-- Moving = delete + re-place, so it needs the same permission as deleting (it previously didn't).
	if Me == SceneToDelete.Owner or CanDeleteAnyScene(Me) then
		DB.RemoveScene(Id)
		if not Move then Chat(Src, Lang("RemovedScene")) end
	else
		Chat(Src, Lang("NoPerms"))
		if Move then TriggerClientEvent("Scene:CancelMove", Src) end
	end
end)

RegisterNetEvent("Scene:AttemptCopy")
AddEventHandler("Scene:AttemptCopy", function(Id)
	local Src = source
	local SceneToCopy = Scenes.Current[Id]
	if not SceneToCopy then return end
	if GetLicense(Src, Config.IdentifierType) == SceneToCopy.Owner then
		TriggerClientEvent("Scene:RecieveCopy", Src, SceneToCopy)
	else
		Chat(Src, Lang("OnlyCopyOwn"))
	end
end)
