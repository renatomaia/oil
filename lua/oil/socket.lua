local socket
if scheduler
	then socket = scheduler.socketapi(require "socket")
	else socket = require "socket"
end
oil = oil or {}
oil.socket = socket
package.loaded["oil.socket"] = socket
