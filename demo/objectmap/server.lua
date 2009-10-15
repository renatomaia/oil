require "oil"

oil.main(function()
	
	local objectMap = {}
	local orb = oil.init{
		objectmap = objectMap,
		port = 2809,
	}
	
	local Hello = {}
	function Hello:say()
		local msg = "Hello "..self.name.."!"
		print(msg)
		return msg
	end
	
	local defaultEntry = {
		object = Hello,
		type = orb:loadidl "interface Hello { string say(); };",
	}
	setmetatable(objectMap, {
		__index = function(map, objkey)
			-- object keys that start with '_' are reserved for OiL
			if not objkey:match("^_") then
				Hello.name = objkey
				return defaultEntry
			end
		end
	})
	
	orb:run()
	
end)
