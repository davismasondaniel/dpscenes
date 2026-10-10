local Limit = 3000

if Config.Database == "KVP" then

	log("^3You can ignore the error above since you're not using SQL.^7")

	-- First unused slot. (The old #Scenes.Current+1 is unreliable once there are gaps from deleted scenes,
	-- and would overwrite live scenes.)
	local function FreeSlot()
		for i = 1, Limit do
			if not Scenes.Current[i] then return i end
		end
	end

	-- Only talks to clients when something actually expired (it used to resend every scene to everyone every 10s).
	DB.Timecheck = function()
		local Ids = GetExpiredScenes(os.time())
		if #Ids == 0 then return end
		for i = 1, #Ids do
			DeleteResourceKvp("dpscene"..Ids[i])
			Scenes.Current[Ids[i]] = nil
		end
		TriggerClientEvent("Scene:DeleteMany", -1, Ids)
		log("Deleted "..#Ids.." expired scenes.")
	end

	DB.NewScene = function(scene, Src, Id, CreationTime, NewScene)
		local This = FreeSlot()
		if not This then
			Chat(Src, "The servers scene limit appears to have been reached, this is bad!")
			return
		end
		SetResourceKvp("dpscene"..This, json.encode({Owner = Id, Hours = scene.Hours, Created = CreationTime, Data = NewScene}))
		scene["Created"] = CreationTime
		scene["Owner"] = Id
		Scenes.Current[This] = scene
		TriggerClientEvent("Scene:Recieve", -1, scene, This)
	end

	DB.GrabAll = function()
		for i = 1, Limit do
			local Scene = GetResourceKvpString("dpscene"..i)
			if Scene then
				local SceneTable = json.decode(Scene)
				local NewScene = json.decode(SceneTable.Data)
				local Old = NewScene.Location
				NewScene["Created"] = SceneTable.Created
				NewScene["Owner"] = SceneTable.Owner
				NewScene["Hours"] = SceneTable.Hours
				NewScene.Location = vector3(Old.x, Old.y, Old.z)
				Scenes.Current[i] = NewScene
			end
		end
		TriggerClientEvent("Scene:RecieveAll", -1, Scenes.Current)
	end

	DB.RemoveScene = function(id)
		DeleteResourceKvp("dpscene"..id)
		Scenes.Current[id] = nil
		TriggerClientEvent("Scene:Delete", -1, id)
	end

end
