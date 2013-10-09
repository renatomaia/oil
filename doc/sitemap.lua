pages = {
	{ index="Home"   , href="index.html", board="latests.html" },
	{                  href="news.html" , title="News" },
	{ index="Install"   , href="release/index.html"   , title="Installation",
		{ index="Changes" , href="release/changes.html" , title="Release Notes" },
		{ index="Previous", href="release/previous.html", title="Previous Releases" },
	},
	{ index="Manual" , href="manual/index.html", title="User Manual",
		--{ index="Intro", href="manual/intro.html", title="Introduction" },
		{ index="Basics"    , href="manual/basics/index.html"   , title="Basic Concepts",
			{ index="Module"  , href="manual/basics/module.html"  , title="The oil Module" },
			{ index="Brokers" , href="manual/basics/brokers.html" , title="Initializing Brokers" },
			{ index="Servants", href="manual/basics/servants.html", title="Registering Servants" },
			{ index="Proxies" , href="manual/basics/proxies.html" , title="Using Remote Servants" },
			{ index="Threads" , href="manual/basics/threads.html" , title="Cooperative Multithreading" },
		},
		{ index="CORBA"       , href="manual/corba/index.html"    , title="CORBA Support", style="table.css",
			{ index="Config"    , href="manual/corba/config.html"   , title="Configuration Options" },
			{ index="IDL"       , href="manual/corba/loadidl.html"  , title="Loading IDL" },
			{ index="Mapping"   , href="manual/corba/mapping.html"  , title="Value Mapping" },
			{ index="Features"  , href="manual/corba/features.html" , title="Additional Features" },
			{ index="Intercept" , href="manual/corba/intercept.html", title="Intercepting Invocations" },
		},
		{ index="LuDO", href="manual/ludo.html", title="LuDO Support" },
		{ index="Arch"     , href="manual/arch/index.html"  , title="Internal Architecture",
			{ index="Layers" , href="manual/arch/layers.html" , title="Defining Layers" },
			{ index="Flavors", href="manual/arch/flavors.html", title="Using Flavors" },
			{ index="Core"   , href="manual/arch/core.html"   , title="Core Architecture" },
			{ index="RMI"    , href="manual/arch/rmi.html"    , title="RMI Architecture" },
		},
	},
	--{ index="About"     , href="about/index.html"  , title="General Information",
		--{ index="Reports" , href="about/reports.html", title="Evaluation Reports" },
		{ index="Papers"  , href="about/papers.html" , title="Conference Papers" },
		--{ index="Slides"  , href="about/slides.html" , title="Presentation Slides" },
	--},
	{ index="Contact" , href="contact.html" , title="Contact People" },
}

refs = {
	{ index="CORBA.org"         , href="http://www.corba.org/"                              , title="CORBA"                       },
	{ index="MitLicense"        , href="http://www.opensource.org/licenses/mit-license.html", title="MIT License"                 },
	{ index="LuaLicense"        , href="http://www.lua.org/license.html"                    , title="Lua License"                 },
	{ index="LuaRocks"          , href="http://www.luarocks.org/"                           , title="LuaRocks"                    },
	{ index="LuaSite"           , href="http://www.lua.org/"                                , title="Lua"                         },
	{ index="PiLBook"           , href="http://www.lua.org/pil"                             , title="Programming in Lua"          },
	{ index="PiL1stEd"          , href="http://www.lua.org/pil/contents.html"               , title="Programming in Lua (1st ed.)",
		{ index="PiL1stEd.Memoize", href="http://www.lua.org/pil/17.1.html"                   , title="Memoize Functions"           },
	},
	{ index="LuaWiki"           , href="http://lua-users.org/wiki"                          , title="Lua Wiki"                    ,
		{ index="LuaWiki.OOP"     , href="http://lua-users.org/wiki/ObjectOrientedProgramming", title="Object Oriented Programming" },
	},
	{ index="LuaManual"         , href="http://www.lua.org/manual/5.2/manual.html"          , title="Lua Manual",
		alias = {
			["2.4"] = "Metatables",
			["2.5.2"] = "WeakTables",
			["6"] = "StdLibs",
			["6.3"] = "Modules",
			["6.5"] = "TableLib",
			["6.10"] = "DebugLib",
			["pdf-package.path"] = "LuaPath",
		},
	},
	{ index="LOOP"           , href="http://www.tecgraf.puc-rio.br/~maia/loop"                               , title="LOOP Portal",
		{ index="LOOP.v23"     , href="http://www.tecgraf.puc-rio.br/~maia/loop/v23"                           , title="LOOP 2.3" },
		{ index="LOOP.v22"     , href="http://www.tecgraf.puc-rio.br/~maia/loop/v22"                           , title="LOOP 2.2" },
		{ index="LOOP.v21"     , href="http://www.tecgraf.puc-rio.br/~maia/loop/v21"                           , title="LOOP 2.1" },
		{ index="LOOP.v3.tgz"  , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-3.0.tar.gz"      , title="LOOP 3.0 (tar.gz)" },
		{ index="LOOP.v3.zip"  , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-3.0.zip"         , title="LOOP 3.0 (zip)" },
		{ index="LOOP.v23.tgz" , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-2.3-alpha.tar.gz", title="LOOP 2.3 (tar.gz)" },
		{ index="LOOP.v23.zip" , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-2.3-alpha.zip"   , title="LOOP 2.3 (zip)" },
		{ index="LOOP.v22.tgz" , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-2.2-alpha.tar.gz", title="LOOP 2.2 (tar.gz)" },
		{ index="LOOP.v22.zip" , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-2.2-alpha.zip"   , title="LOOP 2.2 (zip)" },
		{ index="LOOP.v21.tgz" , href="http://www.tecgraf.puc-rio.br/~maia/loop/download/loop-2.1-alpha.tar.gz", title="LOOP 2.1 (tar.gz)" },
	},
}

template = [===================================================================[
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">

<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>OiL: <%=item.title or "ORB in Lua"%></title>
	<style type="text/css" media="all"><!--
		@import "<%=href("oil.css")%>";
		@import "<%=href("layout"..(item.board and 3 or 1)..".css")%>";
		<%=item.style and '@import "'..href(item.style)..'"'%>;
	--></style>
</head>

<body>

<div id="Header">An Object Request Broker in Lua </div>
<div id="Logo"><img alt="small (1K)" src="<%=href("small.gif")%>" height="49" width="80"></div>

<div id="Menu">
<%=menu()%>
</div>

<div class="content">
<% if item.title then return "<h1>"..item.title.."</h1>" end %>
<%
	local contents = contents()
	if contents then
		return contents:gsub("<pre>(.-)</pre>", function(code)
			return "<pre>"..code:gsub("\t", "  ").."</pre>"
		end)
	end
%>
</div>

<div class="content">
<p><small><strong>Copyright (C) 2004-2008 Tecgraf, PUC-Rio</strong></small></p>
<small>This project is currently being maintained by <a href="http://www.tecgraf.puc-rio.br">Tecgraf</a> at <a href="http://www.puc-rio.br">PUC-Rio</a>.</small>
</div>

<%
if item.board then
	return '<div id="Board">\n'..contents("board")..'</div>\n'
end
%>

</body>

</html>    ]===================================================================]
