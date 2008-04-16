local print = print

local assert   = assert
local error    = error
local ipairs   = ipairs
local pairs    = pairs
local rawget   = rawget
local setfenv  = setfenv
local tonumber = tonumber
local tostring = tostring
local type     = type

local coroutine = require "coroutine"
local math      = require "math"
local os        = require "os"
local string    = require "string"
local table     = require "table"

local oo    = require "loop.base"
local oil   = require "oil"
local utils = require "dtest.run.utils"

local Suite = require "loop.test.Suite"

module("oil.dtests.Template", oo.class)

local sockets = oil.BasicSystem.sockets
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
	"oil.dtests.hosts = {%s}",
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
function newtest(self, infos)
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
		
		-- start processes
		for name, info in pairs(Processes) do
			local code = CodeBody:format(
				info.command.flavor,
				getpackage(info.command.flavor),
				table.concat(HostTable, ","),
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
		local size = assert(tonumber(assert(Master:receive())))
		local result = assert(Master:receive(size))
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
--------------------------------------------------------------------------------
-- Full Suite Generation
--
local nestedlist = oo.class()
function nestedlist:__tostring()
	local result = {}
	for _, value in ipairs(self) do
		value = tostring(value)
		if value ~= "" then
			result[#result+1] = value
		end
	end
	return table.concat(result, ";")
end

local function seqnext(self, sequence, index)
	index = index or 1
	sequence = nestedlist(sequence)
	for current in self[index]:combinations() do
		sequence[index] = current
		if index < #self
			then seqnext(self, sequence, index+1)
			else coroutine.yield(sequence)
		end
	end
end

local function altnext(self, prev, index)
	index = index or 1
	for current in self[index]:combinations() do
		coroutine.yield(current)
	end
	if index < #self then return altnext(self, prev, index+1) end
end
--------------------------------------------------------------------------------
function strnext(self, prev)
	if prev == nil then return self end
end
function string:combinations()
	return strnext, self
end

local seq = oo.class()
function seq:combinations()
	return coroutine.wrap(seqnext), self
end

local alt = oo.class()
function alt:combinations()
	return coroutine.wrap(altnext), self
end
--------------------------------------------------------------------------------
--[intercepted?;gencode?;corba;typed|ludo];cooperative?;base

local Names = {
	ludo = "LuDO",
	corba = "CORBA",
	cooperative = "Co",
	intercepted = "Icept",
	gencode = "Gen",
}
local Tags = {
	"gencode",
	"intercepted",
	"cooperative",
	"corba",
	"ludo",
}
local function findtag(flavor, tag)
	for _, flavor in ipairs(flavor) do
		if flavor == tag then return true end
	end
	return false
end
local function getname(cltflavor, srvflavor)
	local client, server, common = {}, {}, {}
	for _, tag in ipairs(Tags) do
		if srvflavor:find(tag, nil, true) then
			if cltflavor:find(tag, nil, true) then
				common[#common+1] = Names[tag]
			else
				server[#server+1] = Names[tag]
			end
		elseif cltflavor:find(tag, nil, true) then
			client[#client+1] = Names[tag]
		end
	end
	if #client > 0 then client[#client+1] = "Client" end
	if #server > 0 then server[#server+1] = "Server" end
	return table.concat(client)..
	       table.concat(server)..
	       table.concat(common)
end

function newsuite(self, required)
	required = required or {}
	local ludo = "ludo"
	local corba = seq{
		alt{"gencode"    , ""};
		alt{"intercepted", ""};
		"corba";
		"typed";
	}
	local flavors = seq{
		"";
		alt{"cooperative", ""};
		"base";
	};
	local protocols = {
		ludo    = true,
		[corba] = true,
	}
	if required.gencode          then corba[1][2]      = nil end
	if required.intercepted      then corba[2][2]      = nil end
	if required.cooperative      then flavors[2][2]    = nil end
	if rawget(required, "ludo")  then protocols[corba] = nil end
	if rawget(required, "corba") then protocols[ludo]  = nil end
	local suite = Suite()
	for protocol in pairs(protocols) do
		flavors[1] = protocol
		for client in flavors:combinations() do
			for server in flavors:combinations() do
				client = tostring(client)
				server = tostring(server)
				suite[getname(client, server)] = self:newtest{
					Client = { flavor = client },
					Server = { flavor = server },
				}
			end
		end
	end
	return suite
end
