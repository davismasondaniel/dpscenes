Scenes = {
	Current = {},
	Cooldowns = {}
}

Admins = {
	"discord:82089430562635776",
	"steam:1100001053ac3bb",
}

function CloseToOtherScene(t)
	for _, v in pairs(Scenes.Current) do
		if Distance(t.Location, v.Location) < 0.2 then return true end
	end
	return false
end

function CountScenes(id)
	local Count = 0
	for _, v in pairs(Scenes.Current) do
		if v.Owner == id then Count = Count + 1 end
	end
	return Count
end

-- Ids of every scene past its expiry. Shared by the SQL and KVP backends.
function GetExpiredScenes(now)
	local Ids = {}
	for id, v in pairs(Scenes.Current) do
		if (tonumber(v.Created) or 0) + 3600 * v.Hours < now then
			Ids[#Ids+1] = id
		end
	end
	return Ids
end

-- Cooldowns are plain timestamps now, so there's no 1-second ticking thread to run forever.
AddEventHandler("playerDropped", function()
	Scenes.Cooldowns[source] = nil
end)

-- Expiry check only. The old loop also broadcast the time to every player every 10s;
-- clients now get it once on join (Scene:Request) and count forward themselves.
CreateThread(function()
	Wait(100)
	DB.GrabAll()
	while true do
		Wait(10000)
		DB.Timecheck()
	end
end)

RegisterCommand("scene", function(Src, Arguments)
	if Src == 0 then return end
	local Now = GetGameTimer()
	if (Scenes.Cooldowns[Src] or 0) > Now then
		Chat(Src, Lang("CantRightNow"))
		return
	end
	Scenes.Cooldowns[Src] = Now + 1000
	local Input = table.concat(Arguments, " ")
	local Length = string.len(Input)
	if Length <= 280 and Length > 3 then
		TriggerClientEvent("Scene:Create", Src, Input)
	else
		Chat(Src, Lang("InvalidText"))
	end
end)

RegisterCommand("scenestats", function(Src)
	local Total = 0
	for _ in pairs(Scenes.Current) do Total = Total + 1 end
	Chat(Src, "Active Scenes : "..Total.."x")
end)

RegisterNetEvent("Scene:Request")
AddEventHandler("Scene:Request", function()
	local Src = source
	TriggerClientEvent("Scene:RecieveAll", Src, Scenes.Current)
	TriggerClientEvent("Scene:Cache", Src, { Time = os.time() })
end)
