local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Service = {}
function Service:sleep(time)
	oil.sleep(time)
end
function Service:signal(callback)
	oil.newthread(callback.notify, callback)
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	orb:loadidl[[
	interface Callback {
		void notify();
	};
	interface Service {
		void signal(in Callback cb);
		void sleep(in double time);
	};
	]]
	Service.__type = "Service"
end
orb:newservant(Service, "object")
--[Server]=====================================================================]

Client = [=====================================================================[
cothread = require "cothread"

orb = oil.dtests.init()
Service = oil.dtests.resolve("Server", 2809, "object")
Callback = {
	notify = function()
		notified = true
		if thread then
			cothread.schedule(thread)
			thread = nil
		end
		Service:sleep(.1)
		completed = true
		if thread then
			cothread.schedule(thread)
			thread = nil
		end
	end,
}
if oil.dtests.flavor.ludo then
	Callback = orb:newproxy(tostring(orb:newservant(Callback)))
end
Service:signal(Callback)
if not notified then
	thread = cothread.running()
	oil.sleep(3)
end
orb:shutdown()
if not completed then
	thread = cothread.running()
	oil.sleep(3)
end

assert(notified and completed)
--[Client]=====================================================================]

return template:newsuite{ cooperative = true, corba = true }
