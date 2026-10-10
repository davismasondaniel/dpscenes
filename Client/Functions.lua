Locale = {}
function Lang(what)
	local Dict = Locale[Config.Language]
	return (Dict and Dict[what]) or Locale["en"][what] or what -- fall back to english, then to the key itself.
end

function log(what)
	if type(what) == "table" then
		print(json.encode(what))
	else
		print(tostring(what).." | "..type(what))
	end
end

function Chat(source, Msg)
	TriggerClientEvent("chatMessage", source, "^4Scenes^7", {255,255,255}, Msg)
end

function Distance(first, second)
	return #(first - second)
end

function GetLicense(s, t)
	local Prefix = string.lower(t)
	local Len = #Prefix
	for _, v in ipairs(GetPlayerIdentifiers(s)) do
		if string.sub(v, 1, Len) == Prefix then
			return v
		end
	end
	return false
end
