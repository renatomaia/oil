require "scheduler"
require "oil"
require "oil.cos.event"

local helpmsg = [[
Usage:
	eventd.lua [options]
	
	options:
		--port <port number>
		--ior <IOR file>
		--name <channel name>
		--ns <NameService reference>
		--log <log file>
		--verb <level>
		--oil.cos.event.max_queue_length <value>
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

oil.loadidlfile "CosEvent.idl"
channel = oil.newobject(oil.cos.event.new(arg))

if arg then
	if arg.name then
		local ns = arg.ns
		scheduler.new(function()
			if arg.ns
				then ns = oil.narrow(oil.newproxy(ns))
				else ns = oil.narrow(oil.newproxy("corbaloc::localhost:7000/NameService"))
			end
			if ns then ns:rebind({{id=arg.name,kind="EventChannel"}}, channel) end
		end)
	end
	if arg.ior then oil.writeIOR(channel, arg.ior) end
end

scheduler.new(oil.run)
scheduler.run()
