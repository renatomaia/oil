require "oil"

oil.loadidlfile("../hello/hello.idl")

local hello = oil.newproxy("corbaloc::/MyHello", "IDL:Hello:1.0")

local secs = 1
local dots = 3
while hello:_non_existent() do
	io.write "Server object is not avaliable yet "
	for i=1, dots do io.write "." socket.sleep(secs/dots) end
	print()
end

hello.quiet = false
for i = 1, 3 do print(hello:say_hello_to("world")) end
print("Object already said hello "..hello.count.." times till now.")
