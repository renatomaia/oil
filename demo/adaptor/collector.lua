require "scheduler"
require "oil"
require "adaptor"

oil.loadidl[[
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
		void submit(in Paper paper);
	};
]]

Collector = oo.class{}

function Collector:__init()
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

local c1 = oil.newobject(Collector(), "Collector")
local c2 = oil.newobject(Collector(), "Collector")
local c3 = oil.newobject(Collector(), "Collector")

oil.writeIOR(c1, "c1.ior")
oil.writeIOR(c2, "c2.ior")
oil.writeIOR(c3, "c3.ior")

oil.writeIOR(oil.newobject(Adaptor("Collector"), "ComponentAdaptor"), "adaptor.ior")

scheduler.new(oil.run)
scheduler.run()
