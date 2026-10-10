RegisterNetEvent("Scene:Recieve")
AddEventHandler("Scene:Recieve", function(scene, id)
	Scenes[id] = scene
	RefreshNearby()
end)

RegisterNetEvent("Scene:Cache")
AddEventHandler("Scene:Cache", function(cache)
	Cache.Time = cache.Time
	Cache.Received = GetGameTimer()
end)

RegisterNetEvent("Scene:Delete")
AddEventHandler("Scene:Delete", function(id)
	Scenes[id] = nil
	RefreshNearby()
end)

-- Batched expiry, one event instead of one per scene.
RegisterNetEvent("Scene:DeleteMany")
AddEventHandler("Scene:DeleteMany", function(ids)
	for i = 1, #ids do Scenes[ids[i]] = nil end
	RefreshNearby()
end)

RegisterNetEvent("Scene:Reset")
AddEventHandler("Scene:Reset", function()
	ResetScene()
end)

RegisterNetEvent("Scene:RecieveAll")
AddEventHandler("Scene:RecieveAll", function(scenes)
	Scenes = scenes
	RefreshNearby()
end)

-- Server refused to let us pick the scene up (not owner), so abort the move.
RegisterNetEvent("Scene:CancelMove")
AddEventHandler("Scene:CancelMove", function()
	MovingScene = false
end)

RegisterNetEvent("Scene:Create")
AddEventHandler("Scene:Create", function(T)
	Scene.Text.Text = T
	if not Scene.State then
		Scene.State = "Placing"
	end
end)

LastCopiedScene = nil
RegisterNetEvent("Scene:RecieveCopy")
AddEventHandler("Scene:RecieveCopy", function(T)
	LastCopiedScene = T
	Scene = T
	if not Scene.State then
		Scene.State = "Placing"
	end
end)
