Timer = require "cothread.Timer"
oil = require "oil"

--oil.verbose:level(4)
--oil.verbose:flag("channel", true)
--cothread.verbose:flag("cosocket", true)
local port = ...

oil.main(function()
	function callobj(timer)
		local count = timer.count+1
		timer.callback:triggered(count)
		timer.count = count
	end
	TimeEventService = { __type = "TimeEventService" }
	function TimeEventService:newtimer(rate, callback)
		return Timer{
			rate = rate,
			action = callobj,
			callback = callback,
			count = 0,
		}
	end
	function TimeEventService:print(msg)
		print(msg)
	end
	
	orb = oil.init{port=port}
	orb:loadidl[[
		interface TimeEventTimer {
			readonly attribute long count;
			boolean enable();
			boolean disable();
		};
		interface TimeEventCallback {
			void triggered(in long count);
		};
		interface TimeEventService {
			TimeEventTimer newtimer(in double rate, in TimeEventCallback callback);
			void print(in string msg);
		};
	]]
	ref = tostring(orb:newservant(TimeEventService))
	if not oil.writeto("ref.ior", ref) then
		print(ref)
	end
	orb:run()
end)
