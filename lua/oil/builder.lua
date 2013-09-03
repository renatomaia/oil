local _G = require "_G"
local error = _G.error
local pairs = _G.pairs
local pcall = _G.pcall
local require = _G.require
local setmetatable = _G.setmetatable
local tostring = _G.tostring
local type = _G.type                                                            --[[VERBOSE]] local verbose = require "oil.verbose"
local traceback = _G.debug and _G.debug.traceback -- only if available

if traceback ~= nil then
	local xpcall = _G.xpcall
	local func2call, funcarg
	local function callwith1arg() return func2call(funcarg) end
	function pcall(func, arg)
		func2call = func
		funcarg = arg
		return xpcall(callwith1arg, traceback)
	end
end

local none = setmetatable({}, { __newindex = function() end })

local Environment = {
	__index = function(self, name)
		return none
	end,
}

local function create(factories, comps)
	for name, factory in pairs(factories) do
		if name:match("^%u") and comps[name] == nil then
			comps[name] = factory()
		end
	end
end

local module = { create = create }

local NamePat    = "[^;]+"
local FactoryFrm = "oil.builder.%s"
local ArchFrm    = "oil.arch.%s"
local ErrorFrm   = "module '%s' not found:"
function module.build(customization, built)
	if built == nil then built = {} end
	for name in customization:gmatch(NamePat) do                                  --[[VERBOSE]] verbose:built(true, "creating ",name," components")
		local package = FactoryFrm:format(name)
		local success, module = pcall(require, package)
		if success then
			local builder = module.create
			if builder ~= nil then
				builder(built)
			else
				create(module, built)
			end
		elseif not tostring(module):find(ErrorFrm:format(package), nil, true) then  --[[VERBOSE]] verbose:built(false)
			error(module, 2)                                                          --[[VERBOSE]] else verbose:built("unable to load builder for architecture ",name)
		end                                                                         --[[VERBOSE]] verbose:built(false)
	end
	for name in customization:gmatch(NamePat) do                                  --[[VERBOSE]] verbose:built(true, "assembling ",name," components")
		local package = ArchFrm:format(name)
		local success, module = pcall(require, package)
		if success then
			local assemble = module.assemble
			if assemble ~= nil then
				if _G._VERSION == "Lua 5.1" then _G.setfenv(assemble, built) end
				setmetatable(built, Environment)
				module.assemble(built)
				setmetatable(built, nil)
			end
		elseif not module:find(ErrorFrm:format(package), nil, true) then            --[[VERBOSE]] verbose:built(false)
			error(module, 2)                                                          --[[VERBOSE]] else verbose:built("unable to load architecture definition for ",name)
		end                                                                         --[[VERBOSE]] verbose:built(false)
	end
	return built
end

return module
