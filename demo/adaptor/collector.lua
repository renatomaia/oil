local oo = require "oil.oo"

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

local oil = require "oil"
oil.main(function()
	require "adaptor"
	
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
	
	orb:run()
end)
