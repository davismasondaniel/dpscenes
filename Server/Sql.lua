if Config.Database == "SQL" then

	-- One DELETE and one network event for all expired scenes, instead of one of each per scene.
	DB.Timecheck = function()
		local Ids = GetExpiredScenes(os.time())
		if #Ids == 0 then return end
		for i = 1, #Ids do Scenes.Current[Ids[i]] = nil end
		TriggerClientEvent("Scene:DeleteMany", -1, Ids)
		MySQL.Async.execute("DELETE FROM scenes WHERE id IN ("..table.concat(Ids, ",")..")", {})
		log("Deleted "..#Ids.." expired scenes.")
	end

	DB.NewScene = function(scene, Src, Id, CreationTime, NewScene)
		MySQL.Async.insert('INSERT INTO scenes (`data`, `owner`, `created`, `hours`) VALUES (@data, @owner, @created, @hours);',
			{data = NewScene, owner = Id, created = CreationTime, hours = scene.Hours},
		function(databaseid)
			scene["Created"] = CreationTime
			scene["Owner"] = Id
			Scenes.Current[databaseid] = scene
			TriggerClientEvent("Scene:Recieve", -1, scene, databaseid)
		end)
	end

	DB.GrabAll = function()
		MySQL.Async.fetchAll("SELECT * FROM `scenes`", {}, function(result)
			for _, v in ipairs(result) do
				local NewScene = json.decode(v.data)
				NewScene["Created"] = tonumber(v.created)
				NewScene["Owner"] = v.owner
				NewScene["Hours"] = v.hours
				local Old = NewScene.Location
				NewScene.Location = vector3(Old.x, Old.y, Old.z)
				Scenes.Current[v.id] = NewScene
			end
			TriggerClientEvent("Scene:RecieveAll", -1, Scenes.Current)
		end)
	end

	DB.RemoveScene = function(id)
		Scenes.Current[id] = nil
		TriggerClientEvent("Scene:Delete", -1, id)
		MySQL.Async.execute("DELETE FROM scenes WHERE id = @id", {['@id'] = id})
	end

end
