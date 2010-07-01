local _ENV = require "loop.object.Exception"

local predefined = {
	Timeout = "timeout",
	Terminated = "terminated",
	AlreadyStarted = "already started",
}

for name, message in pairs(predefined) do
	_ENV[name] = _ENV{
		error = message,
		message = message,
	}
end

return _ENV