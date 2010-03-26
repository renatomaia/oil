local loop = require "loop"
local multiple = require "loop.multiple"
local hierarchy = require "loop.hierarchy"

return {
	initclass = multiple.initclass,
	class = multiple.class,
	rawnew = multiple.rawnew,
	new = loop.new,
	
	isclass = multiple.isclass,
	isinstanceof = loop.isinstanceof,
	issubclassof = loop.issubclassof,
	
	getclass = loop.getclass,
	getsuper = loop.getsuper,
	getmember = loop.getmember,
	
	supers = loop.supers,
	members = loop.members,
	allmembers = loop.allmembers,
	topdown = hierarchy.topdown,
}
