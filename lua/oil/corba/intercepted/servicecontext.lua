local _G = require "_G"
local ipairs = _G.ipairs
local pairs = _G.pairs

local module = {}

function module.table2sequence(table)
	if table ~= nil then
		local sequence = {}
		local n = 1
		for tag, data in pairs(table) do
			sequence[n] ={
				context_id = tag,
				context_data = data,
			}
			n = n+1
		end
		return sequence
	end
end

function module.sequence2table(sequence)
	if sequence ~= nil then
		local table = {}
		for _, context in ipairs(sequence) do
			table[context.context_id] = context.context_data
		end
		return table
	end
end

return module
