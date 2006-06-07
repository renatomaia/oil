require "scheduler"
require "oil"

oil.verbose.output(io.open("client.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("marshall", true)
oil.verbose.flag("threads", true)

--------------------------------------------------------------------------------
oil.init{ manager = oil.manager.new() } -- IR object manager does not suport
                                        -- adaptation yet.
--------------------------------------------------------------------------------
if not arg then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
--------------------------------------------------------------------------------
oil.loadidl [[
	module Adaptation {
		interface Proxy {
			boolean request_work_for(in long seconds);
		};
		interface Adaptor {
			void update_definition(in string definition);
		};
	};
]]
--------------------------------------------------------------------------------
local proxy = oil.newproxy(oil.readIOR("proxy.ior"), "IDL:Adaptation/Proxy:1.0")
local padpt = oil.newproxy(oil.readIOR("proxyadaptor.ior"), "IDL:Adaptation/Adaptor:1.0")
local sadpt = oil.newproxy(oil.readIOR("serveradaptor.ior"), "IDL:Adaptation/Adaptor:1.0")
--------------------------------------------------------------------------------
local function showprogress(id, time)
	print(id, "about to request work for "..time.." seconds")
	if proxy:request_work_for(time)
		then print(id, "result received successfully")
		else print(id, "got an unexpected result")
	end
end

local maximum = 0
for id, time in ipairs(arg) do
	time = tonumber(time)
	scheduler.new(showprogress, id, time)
	maximum = math.max(time, maximum)
end
--------------------------------------------------------------------------------
local NewServerIDL = [[
	module Adaptation {
		interface Server {
			boolean do_something_for(in double seconds);
		};
	};
]]

local NewProxyIDL = [[
	module Adaptation {
		interface Proxy {
			boolean request_work_for(in double seconds);
		};
	};
]]

local function adaptafter(time)
	scheduler.sleep(time + 1)
	oil.loadidl(NewProxyIDL)
	padpt:update_definition(NewProxyIDL)
	padpt:update_definition(NewServerIDL)
	sadpt:update_definition(NewServerIDL)

	for id, time in ipairs(arg) do
		scheduler.new(showprogress, id, tonumber(time))
	end
end

scheduler.new(adaptafter, maximum)
--------------------------------------------------------------------------------
scheduler.run()
