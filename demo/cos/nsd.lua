require "oil"
require "oil.cos.naming"

assemble "corba.typed.cooperative.base"

local helpmsg = [[
Usage:
	nsd.lua [options]
	
	options:
		--port <port number>
		--ior <IOR file>
		--log <log file>
		--verb <level>
]]
if arg then
	local i = 1
	while arg[i] do
		local val = arg[i]
		if val == "--help" or not string.find(val, "^--") then
			io.stderr:write(helpmsg)
			os.exit()
		else
			i = i + 1
			arg[string.sub(val, 3)] = tonumber(arg[i]) or arg[i]
		end
		i = i + 1
	end
	if arg.log then oil.verbose.output(io.open(arg.log, "w")) end
	if arg.verb then oil.verbose.level(arg.verb) end

	oil.init(arg)
end
	
oil.loadidlfile "CosNaming.idl"
ns = oil.newobject(oil.cos.naming.new())

if arg and arg.ior then oil.writeIOR(ns, arg.ior) end

oil.run()
