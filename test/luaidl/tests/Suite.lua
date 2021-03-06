local database = (os.getenv("OIL_HOME") or "..").."/test/luaidl/tests/db/"

local luaidl = require "luaidl"
local FileStream = require "loop.serial.FileStream"
local Suite = require "loop.test.Suite"
local checks = require "loop.test.checks"

local files = {
	"valuetype",
	"const",
	"core",
	"data_service",
	"enum",
	"enum_cases",
	"exception",
	"interface",
	"module",
	"sequence",
	"typedef",
	"union",
	"hello",
	"newidl",
	"test",
	"apptest",
	"pragmaid",
	"ir",
	"pragmaprefix_1",
	"pragmaprefix_2",
	"pragmaprefix_3",
	"pragmaprefix_4",
	"pragmaprefix_5",
	"pragmaprefix_6",
	"pragmaprefix_7",
	"project_service",
	"adaptor",
	"ApplicationRepository",
	"BspLib",
	"CosNaming",
	"registry_service",
	"ResourceManagement",
	"security",
	"session_service",
	"sga-daemon",
	"sga-manager",
	"sga",
	"wio",
	"adaptor2",
	"ss",
	"csfs",
	"struct",
	"perf",
	"pragmaid2",
	"comp",
	"attributes",
	"distdebug",
	"facets",
	"receptacles",
	"inheritance",
	"supports",
	"mpacomponents",
	"home",
	"value",
	"TestOBV", -- from Orbacus tests
	"event",
	"CCM",
	"interfaces",
	"module2",
	"module3",
	"access_control_service",
	"scope",
	"bug04",
	"inters",
	"operations",
	"structs",
	"typedefs",
	"unions",
	"scs",
	"server",
	"echo",
	"UndeclaredException",
	"project", -- from OpenBus
}

local Suite = Suite()
for _, name in ipairs(files) do
	local path = database..name
	local idlfile = path..".idl"
	local luafile = path..".lua"
	Suite[name] = function()
		checks.viewer.maxdepth = -1
		local new = {luaidl.parsefile(idlfile)}
		local file = io.open(luafile)
		if file then
			local old = FileStream{file=file}:get()
			file:close()
			checks.assert(new, checks.like(old, "output changed"))
		else
			file = assert(io.open(luafile, "w"))
			FileStream{file=file}:put(new)
			file:close()
		end
	end
end
return Suite
