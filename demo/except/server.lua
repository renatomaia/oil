local Server = { data = { a_number = 1234 } }

function Server:read(tag)
	local value = Server.data[tag]
	if value == nil then
		error(oil.newexcept{"Control::AccessError",
			tagname=tag,
			reason="unknown tag name",
		})
	end
	return value
end

function Server:write(tag, value)
	local old = Server.data[tag]
	if type(old) ~= type(value) then
		error(oil.newexcept{"Control::AccessError",
			tagname=tag,
			reason="invalid value for tag",
		})
	end
	Server.data[tag] = value
end

require "oil"

oil.main(function()
	oil.loadidlfile("control.idl")
	oil.writeto("ref.ior",
		oil.tostring(
			oil.newservant(Server, "Control::Server")))
	oil.run()
end)
