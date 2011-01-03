oil = require "oil"
Timer = require "cothread.Timer"
oil.main(function()
	TimeEventService = { __type = "TimeEventService" }
	function TimeEventService:newtimer(rate, callback)
		return Timer{
			callback = callback,
			count = 0,
			rate = rate,
			action = function(timer)
				local count = timer.count+1
				timer.callback:triggered(count)
				timer.count = count
			end,
		}
	end
	function TimeEventService:print(msg)
		print(msg)
	end
	
	orb = oil.init()
	orb:loadidlfile("interfaces.idl")
	ref = tostring(orb:newservant(TimeEventService))
	if not oil.writeto("ref.ior", ref) then
		print(ref)
	end
	orb:run()
end)
