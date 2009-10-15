package = "LuaIDL"
version = "0.9beta-1"
source = {
	url = "http://www.tecgraf.puc-rio.br/~maia/oil/packs/v05/luaidl-0.9-beta.tar.gz",
}
description = {
	summary = "A OMG IDL Compiler Front End",
	detailed = [[
		LuaIDL is an OMG IDL (Interface Definition Language) compiler front end,
		written in the Lua programming language. It can be used to perform a simple
		IDL parsing with low effort as well as it can be used to implement a
		complete and flexible IDL compiler. LuaIDL is very small, easy to install
		and to use. It offers a callback mechanism that allows its extension to
		generate different output formats. Additionally, it is very portable because
		it is completely implemented in Lua and does not have external dependencies.
	]],
	license = "MIT/X11",
	homepage = "http://oil.luaforge.net/luaidl",
	maintainer = "Ricardo Cosme <rcosme@tecgraf.puc-rio.br>",
}
dependencies = {
	"lua >= 5.1",
}
build = {
	type = "none",
	install = {
		lua = {
			["luaidl.lex"] = "luaidl/lex.lua",
			["luaidl.pre"] = "luaidl/pre.lua",
			["luaidl.sin"] = "luaidl/sin.lua",
			["luaidl"] = "luaidl.lua",
		},
	},
}
