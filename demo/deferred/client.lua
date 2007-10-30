if select("#", ...) == 0 then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
local arg = {...}

--------------------------------------------------------------------------------

OIL_FLAVOR = "corba;typed;base" -- no concurrency support

require "oil"

oil.main(function()
	local proxy = oil.newproxy(assert(oil.readfrom("server.ior")))
	
	-- make deferred calls
	local calls = {}
	for id, time in ipairs(arg) do
		print(id, "about to request work for "..time.." seconds")
		calls[proxy:___do_something_for(tonumber(time))] = id
	end
	
	-- wait for the replies
	repeat
		for call, id in pairs(calls) do
			if call:ready() then
				if call:results()
					then print(id, "result received successfully")
					else print(id, "got an unexpected result")
				end
				calls[call] = nil
			end
		end
	until next(calls) == nil
end)
