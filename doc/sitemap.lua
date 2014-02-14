pages = {
	{ index="Home"        , href="index.html"                   , board="latests.html" },
	{                       href="news.html"                    , title="News" },
	{ index="Download"      , href="release/index.html"         ,
		{ index="Previous"    , href="release/previous.html"      , title="Previous Releases" },
	},
	{ index="Manual"      , href="manual/index.html"            , title="User Manual",
		{ index="Basics"    , href="manual/basics/index.html"     , title="Basic Concepts",
			{ index="Brokers" , href="manual/basics/brokers.html"   , title="Initializing Brokers" },
			{ index="Servants", href="manual/basics/servants.html"  , title="Creating Distributed Objects" },
			{ index="Proxies" , href="manual/basics/proxies.html"   , title="Accessing Distributed Objects" },
			{ index="Threads" , href="manual/basics/threads.html"   , title="Cooperative Multithreading" },
		},
		{ index="CORBA"       , href="manual/corba/index.html"    , title="CORBA Support", style="table.css",
			{ index="IDL"       , href="manual/corba/loadidl.html"  , title="Loading IDL" },
			{ index="Mapping"   , href="manual/corba/mapping.html"  , title="Value Mapping" },
			{ index="Features"  , href="manual/corba/features.html" , title="Additional Features" },
			{ index="Intercept" , href="manual/corba/intercept.html", title="Intercepting Invocations" },
		},
		{ index="LuDO"        , href="manual/ludo.html"           , title="LuDO Support" },
		{ index="Architecture", href="manual/arch/index.html"     , title="Internal Architecture",
			--{ index="Layers"  , href="manual/arch/layers.html"    , title="Defining Layers" },
			{ index="Flavors"   , href="manual/arch/flavors.html"   , title="Using Flavors" },
			{ index="Core"      , href="manual/arch/core.html"      , title="Core Architecture" },
			{ index="RMI"       , href="manual/arch/rmi.html"       , title="RMI Architecture" },
		},
		{ index="Reference"   , href="manual/reference.html"      , title="API Reference" },
		{ index="Changes"     , href="manual/changes.html"        , title="Release Notes" },
	},
--{ index="About"         , href="about/index.html"           , title="General Information",
	--{ index="Reports"     , href="about/reports.html"         , title="Evaluation Reports" },
		{ index="Papers"      , href="about/papers.html"          , title="Conference Papers" },
	--{ index="Slides"      , href="about/slides.html"          , title="Presentation Slides" },
	--},
	{ index="Contact"       , href="contact.html"               , title="Contact People" },
}


refs = {
	{ index="noemi"             , href="http://www.inf.puc-rio.br/~noemi"                   , title="Noemi Rodriguez"             },
	{ index="roberto"           , href="http://www.inf.puc-rio.br/~roberto"                 , title="Roberto Ierusalimschy"       },
	{ index="rcerq"             , href="http://www.inf.puc-rio.br/~rcerq"                   , title="Renato Cerqueira"            },
	{ index="maia"              , href="http://www.inf.puc-rio.br/~maia"                    , title="Renato Maia"                 },
	{ index="maciel"            , href="http://www.maciel.org/"                             , title="Leonardo Maciel"             },
	{ index="Tecgraf"           , href="http://www.tecgraf.puc-rio.br/"                     , title="Tecgraf"                     },
	{ index="PUC-Rio"           , href="http://www.puc-rio.br/"                             , title="PUC-Rio"                     },
	{ index="CORBA.org"         , href="http://www.corba.org/"                              , title="CORBA"                       },
	{ index="MitLicense"        , href="http://www.opensource.org/licenses/mit-license.html", title="MIT License"                 },
	{ index="LuaLicense"        , href="http://www.lua.org/license.html"                    , title="Lua License"                 },
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
			["6.2"] = "Coroutines",
			["6.3"] = "Modules",
			["6.5"] = "TableLib",
			["6.10"] = "DebugLib",
			["pdf-package.path"] = "LuaPath",
			["pdf-io.open"] = "io.open",
			["pdf-tostring"] = "tostring",
			["pdf-print"] = "print",
			["pdf-pcall"] = "pcall",
			["pdf-coroutine.yield"] = "coroutine.yield",
			["pdf-coroutine.running"] = "coroutine.running",
		},
	},
	{ index="LuaRocks"        , href="http://www.luarocks.org/"                                        , },
	{ index="LuaSocket"       , href="http://w3.impa.br/~diego/software/luasocket/"                    , },
	{ index="LuaStruct"       , href="http://www.inf.puc-rio.br/~roberto/struct/"                      , title="Structs" },
	{ index="LuaCompat52"     , href="https://github.com/hishamhm/lua-compat-5.2/"                     , title="Lua 5.2 Compatibility Module"},
	{ index="LuaTuple"        , href="http://www.tecgraf.puc-rio.br/~maia/lua/tuple"                   , },
	{ index="CoThread"        , href="http://www.tecgraf.puc-rio.br/~maia/lua/cothread"                , },
	{ index="LOOP"            , href="http://www.tecgraf.puc-rio.br/~maia/lua/loop"                    ,
		{ index="LOOP.ClassLib" , href="http://www.tecgraf.puc-rio.br/~maia/lua/loop/classlib"           , title="LOOP Class Library" },
		{ index="LOOP.Component", href="http://www.tecgraf.puc-rio.br/~maia/lua/loop/component"          , title="LOOP Component Models" },
	},
	{ index="OiL"             , href="http://www.tecgraf.puc-rio.br/~maia/lua/oil"                     , title="OiL",
		{ index="OiL.v05"       , href="http://www.tecgraf.puc-rio.br/~maia/lua/oil/v05"                 , title="OiL 0.5" },
		{ index="OiL.v04"       , href="http://www.tecgraf.puc-rio.br/~maia/lua/oil/v04"                 , title="OiL 0.4" },
		{ index="OiL.v06.tgz"   , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.6.tar.gz"    , title="OiL 0.6 (tar.gz)" },
		{ index="OiL.v06.zip"   , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.6.zip"       , title="OiL 0.6 (zip)" },
		{ index="OiL.v034"      , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.3.4.tar.gz"  , title="OiL 0.3.4" },
		{ index="OiL.v033"      , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.3.3.tar.gz"  , title="OiL 0.3.3" },
		{ index="OiL.v032"      , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.3.2.tar.gz"  , title="OiL 0.3.2" },
		{ index="OiL.v031"      , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.3.1.tar.gz"  , title="OiL 0.3.1" },
		{ index="OiL.v03"       , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.3.tar.gz"    , title="OiL 0.3" },
		{ index="OiL.v02"       , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.2.tar.gz"    , title="OiL 0.2" },
		{ index="OiL.v01"       , href="http://www.tecgraf.puc-rio.br/~maia/lua/packs/oil-0.1.tar.gz"    , title="OiL 0.1" },
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
<p><small><strong>Copyright (C) 2004-2014 Tecgraf, PUC-Rio</strong></small></p>
<small>This project is currently being maintained by <%=link("Tecgraf")%> at <%=link("PUC-Rio")%>.</small>
</div>

<%
if item.board then
	return '<div id="Board">\n'..contents("board")..'</div>\n'
end
%>

</body>

</html>    ]===================================================================]
