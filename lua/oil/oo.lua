local loop = require "loop"
local multiple = require "loop.multiple"
local hierarchy = require "loop.hierarchy"

local newclass = multiple.class
local mutator = hierarchy.mutator
local function oilclass(...)
	local class = newclass(...)
	if class.__new == nil then
		class.__new = mutator
	end
	return class
end

return {
	class = oilclass,
	rawnew = loop.rawnew,
	new = loop.new,
	
	isclass = loop.isclass,
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
