local _G = require "_G"
local error = _G.error
local pairs = _G.pairs
local pcall = _G.pcall
local require = _G.require
local type = _G.type                                                            --[[VERBOSE]] local verbose = require "oil.verbose"
local traceback = _G.debug and _G.debug.traceback -- only if available
if traceback then
	local xpcall = _G.xpcall
	local func2call, funcarg
	local function callwith1arg() return func2call(funcarg) end
	function pcall(func, arg)
		func2call = func
		funcarg = arg
		return xpcall(callwith1arg, traceback)
	end
end

module "oil.builder"

function create(factories, comps)
	comps = comps or {}
	for name, factory in pairs(factories) do
		if name:match("^%u") and comps[name] == nil then
			comps[name] = factory()
		end
	end
	return comps
end


local NamePat    = "[^;]+"
local FactoryFrm = "oil.builder.%s"
local ArchFrm    = "oil.arch.%s"
local ErrorFrm   = "module '%s' not found:"
function build(customization, built)
	for name in customization:gmatch(NamePat) do                                  --[[VERBOSE]] verbose:built(true, "creating ",name," components")
		local package = FactoryFrm:format(name)
		local success, module = pcall(require, package)
		if success then
			built = module.create(built)
		elseif not module:find(ErrorFrm:format(package), nil, true) then            --[[VERBOSE]] verbose:built(false)
			error(module, 2)                                                          --[[VERBOSE]] else verbose:built("unable to load builder for architecture ",name)
		end                                                                         --[[VERBOSE]] verbose:built(false)
	end
	for name in customization:gmatch(NamePat) do                                  --[[VERBOSE]] verbose:built(true, "assembling ",name," components")
		local package = ArchFrm:format(name)
		local success, module = pcall(require, package)
		if success then
			if module.assemble then
				module.assemble(built)
			end
		elseif not module:find(ErrorFrm:format(package), nil, true) then            --[[VERBOSE]] verbose:built(false)
			error(module, 2)                                                          --[[VERBOSE]] else verbose:built("unable to load architecture definition for ",name)
		end                                                                         --[[VERBOSE]] verbose:built(false)
	end
	return built
end
