local port = require "oil.port"
local component = require "oil.component"

return {
	TypeRepository = component.Template{
		types = port.Facet,
		indexer = port.Facet,
	},
}
