require "oil"                                             -- Load OiL package

oil.assemble "corba.typed.base"                           -- Customize OiL

oil.main(function()
	hello = oil.newproxy(assert(oil.readfrom("hello.ref"))) -- Get proxy to object

	hello:_set_quiet(false)                                 -- Access the object
	for i = 1, 3 do print(hello:say_hello_to("world")) end
	print("Object already said hello "..hello:_get_count().." times till now.")
end)
