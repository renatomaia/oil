outputdir = "website",

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
{ index="About"     , href="about/index.html"  , title="General Information",
	--{ index="Reports" , href="about/reports.html", title="Evaluation Reports" },
	{ index="Papers"  , href="about/papers.html" , title="Conference Papers" },
	--{ index="Slides"  , href="about/slides.html" , title="Presentation Slides" },
},
{ index="Contact" , href="contact.html" , title="Contact People" },
{ index="LuaForge", href="http://luaforge.net/projects/oil/", title="Project at LuaForge" },

[==============================================================================[
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
<small>This project is currently being maintained by <a href="http://www.tecgraf.puc-rio.br">Tecgraf</a> at <a href="http://www.puc-rio.br">PUC-Rio</a> with grants from <a href="http://www.capes.gov.br">CAPES</a> and <a href="http://www.cnpq.br">CNPq</a>.</small>
</div>

<%
if item.board then
	return '<div id="Board">\n'..contents("board")..'</div>\n'
end
%>

</body>

</html>
]==============================================================================]
