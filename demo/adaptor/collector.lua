local oil = require "oil"
local oo = require "oil.oo"

--------------------------------------------------------------------------------

Adaptor = oo.class()

function Adaptor:__new(class)
	return oo.rawnew(self, { class = class })
end

function Adaptor:apply_change(triggers, state, code, iface)
	local adaptor, errmsg = load("return function(self)\n"..state.."\nend")
	if not adaptor then
		oil.assert.exception{ "IDL:CompileError:1.0",
			message = errmsg,
			code = "function(self)\n"..state.."\nend",
		}
	end
	adaptor = adaptor()

	local original = _G[self.class]
	local adapted = oo.class({}, original)
	_G[self.class] = adapted
	for _, name in ipairs(triggers) do
		local operation = name
		local function trigger(object, ...)
			adaptor(object) -- update object state
			oo.rawnew(adapted, object) -- update object class
			return object[operation](object, ...)
		end
		original[operation] = trigger
	end

	orb:loadidl(iface)
	
	local updater, errmsg = load(code)
	if not updater then
		oil.assert.exception{ "IDL:CompileError:1.0",
			message = errmsg,
			code = code,
		}
	end
	updater()
end

--------------------------------------------------------------------------------

Collector = oo.class{}

function Collector:__new()
	return oo.rawnew(self, { emails = {} })
end

local MailSent = {}
function Collector:send_to(email)
	assert(type(email) == "string", "attempt to send message to address "..tostring(email))
	assert(string.find(email, ".+@.+"), "attempt to send message to address "..tostring(email))
	if MailSent[email] 
		then io.write(" ", email, " got ", MailSent[email], " duplicates ")
		else io.write(".")
	end
	MailSent[email] = (MailSent[email] or 0) + 1
end

function Collector:request_mail()
	print("\n=== Start mail session ========================")
	MailSent = {}
end

function Collector:submit(paper)
	self:request_mail()
	for _, email in ipairs(self.emails) do
		self:send_to(email, "New paper submitted")
	end
	for _, author in ipairs(paper.authors) do
		table.insert(self.emails, author.email)
	end
end

--------------------------------------------------------------------------------

oil.main(function()
	orb = oil.init()
	orb:loadidl[[
		typedef sequence<string> StringSequence;

		exception CompileError {
			string message;
			string code;
		};

		interface ComponentAdaptor {
			void apply_change(
				in StringSequence triggers,
				in string state_adaptation_code,
				in string code_adaptation_code,
				in string new_interface_def
			) raises (CompileError);
		};
	]]
	orb:loadidl[[
		struct Author {
			string name;
			string email;
		};
		typedef sequence<Author> AuthorSeq;
		struct Paper {
			string title;
			AuthorSeq authors;
		};
		interface Collector {
			void submit(in Paper somepaper);
		};
	]]
	
	local c1      = orb:newservant(Collector(), nil, "Collector")
	local c2      = orb:newservant(Collector(), nil, "Collector")
	local c3      = orb:newservant(Collector(), nil, "Collector")
	local adaptor = orb:newservant(Adaptor("Collector"), nil, "ComponentAdaptor")
	
	oil.writeto("c1.ior"     , tostring(c1))
	oil.writeto("c2.ior"     , tostring(c2))
	oil.writeto("c3.ior"     , tostring(c3))
	oil.writeto("adaptor.ior", tostring(adaptor))
end)
