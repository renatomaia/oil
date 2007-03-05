local type = type

local pairs   = pairs
local pcall   = pcall
local require = require                                                         --[[VERBOSE]] local verbose = require "oil.verbose"

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

local NamePat    = "[^%.]+"
local FactoryFrm = "oil.builder.%s"
local ArchFrm    = "oil.arch.%s"
function build(customization) -- corba.cooperative
	local built
	for name in customization:gmatch(NamePat) do                                  --[[VERBOSE]] verbose:built(true, "creating ",name," components")
		built = require(FactoryFrm:format(name)).create(built)                      --[[VERBOSE]] verbose:built(false)
	end
	for name in customization:gmatch(NamePat) do                                  --[[VERBOSE]] verbose:built(true, "assembling ",name," components")
		local success, architecture = pcall(require, ArchFrm:format(name))
		if success then
			architecture.assemble(built)                                              --[[VERBOSE]] else verbose:built("unable to load architecture definition for ",name)
		end                                                                         --[[VERBOSE]] verbose:built(false)
	end
	return built
end
