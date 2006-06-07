require "oil"

oil.verbose.output(io.open("ird.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("ir", true)

oil.writeIOR(oil.getLIR(), arg and arg[1] or "ir.ior")
oil.run()