
local assert  = assert
local error   = error
local ipairs  = ipairs
local pairs   = pairs
local setfenv = setfenv
local type    = type

local math   = require "math"
local os     = require "os"
local string = require "string"
local table  = require "table"

local oo    = require "loop.base"
local oil   = require "oil"
local utils = require "dtest.run.utils"

module("oil.dtests.Template", oo.class)

local sockets = oil.OperatingSystem.sockets
local helper = utils.helper

local OIL_HOME = assert(os.getenv("OIL_HOME"), "OIL_HOME environment variable not defined")
local PortLowerBound = 2809 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive
local Message = "%s\n%d\n%s\n"
local TableEntry = "[%q]=%q"
local LuaProcess = 'lua -eHOST=[[%s]]PORT=%d -loil.dtests.LuaProcess'
local CodeBody = table.concat({
	"OIL_FLAVOR=%q",
	"local flavor = {}",
	"for name in OIL_FLAVOR:gmatch('[^;]+') do flavor[name] = true end",
	"require 'oil'",
	"require 'oil.dtests.%s'",
	"oil.dtests.flavor = flavor",
	"oil.dtests.hosts = %s",
	"oil.dtests.checks = ...",
	"oil.main(function(...) %s\nend)",
}, ";")

local Command = oo.class{
	execpath = OIL_HOME.."/test/",
	requirements = {},
	flavor = "corba;cooperative;typed;base",
}

local Packages = { {"corba"}, {"ludo"} }
local function getpackage(flavor)
	for _, names in pairs(Packages) do
		local found = true
		for _, name in ipairs(names) do
			if not flavor:find(name, 1, true) then
				found = false
				break
			end
		end
		if found then return table.concat(names) end
	end
	error("no oil.dtests package available for flavor "..flavor)
end

function __init(self, object)
	self = oo.rawnew(self, object)
	setfenv(3, self)
	return self
end

local Empty = {}
function __call(self, infos)
	if not infos then infos = Empty end
	return function(checks)
		-- find a free port
		local first = PortLowerBound + math.random(PortUpperBound - PortLowerBound)
		local portno = first
		local port, errmsg
		repeat
			port, errmsg = sockets:tcp()
			if port:bind("*", portno) and port:listen() then break end
			if portno >= PortUpperBound
				then portno = PortLowerBound
				else portno = portno + 1
			end
			if portno == first then error("unable to find an available port") end	
		until false
		port:settimeout(10)
		local hostname = sockets.dns.gethostname()
		
		-- create processes
		local Master
		local Processes = {}
		local HostTable = {}
		for name, code in pairs(self) do
			if type(name) == "string" then
				local command = Command(infos[name])
				command.id = name
				command.command = LuaProcess:format(hostname, portno)
				local process = helper:start(command)
				HostTable[#HostTable+1] = TableEntry:format(name, process:_get_host())
				Processes[name] = {
					command = command,
					process = process,
					connection = assert(port:accept()),
					code = code,
				}
			end
		end
		HostTable = string.format("{%s}", table.concat(HostTable, ","))
		
		-- start processes
		for name, info in pairs(Processes) do
			local code = CodeBody:format(
				info.command.flavor,
				getpackage(info.command.flavor),
				HostTable,
				info.code
			)
			assert(info.connection:send(Message:format(name, #code, code)))
			if name == self[1]
				then Master = info.connection
				else info.connection:close()
			end
		end
		
		-- get results
		local success = assert(Master:receive())
		local result = assert(Master:receive())
		Master:close()
		
		-- kill all processes
		for name, info in pairs(Processes) do
			info.process:halt()
		end
		
		-- wait processes to be killed
		oil.sleep(1)
		
		-- report results
		if success == "protocol" then
			error("LuaProcess: "..result)
		elseif success == "failure" then
			checks:fail(result)
		elseif success ~= "success" then
			error(result)
		end
	end
end
