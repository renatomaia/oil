require "oil"

oil.loadidlfile "CosNaming.idl"

fake = oil.newproxy("corbaloc::/FakeObject")
naming = oil.newproxy("corbaloc::localhost:7000/NameService"):_narrow()
naming:bind({{id="AnObject", kind="Fake"}}, fake)
obj = naming:resolve_str("AnObject.Fake")
naming:unbind({{id="AnObject", kind="Fake"}})
assert(fake:_non_existent())
