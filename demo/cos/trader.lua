require "oil"

oil.setIR(oil.newproxy(oil.readIOR("ir.ior")))

trader = oil.newproxy(oil.readIOR("trader.ior"))
t_rep = oil.narrow(trader.type_repos)
types = t_rep:list_types{ _switch = "all" }

print("types = "..loop.debug.Viewer:tostring(types))
