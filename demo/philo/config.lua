require "oil"

oil.loadidlfile("philo.idl")

ForkHome        = oil.newproxy(oil.readIOR("fork.ior"))
PhilosopherHome = oil.newproxy(oil.readIOR("philo.ior"))
ObserverHome    = oil.newproxy(oil.readIOR("observer.ior"))

Observer = ObserverHome:create()

Fork = {
	ForkHome:create(),
	ForkHome:create(),
	ForkHome:create(),
}

Philo = {
	PhilosopherHome:create("Socrates"),
	PhilosopherHome:create("Plato"),
	PhilosopherHome:create("Aristoteles"),
}

Philo[1].info = Observer
Philo[1].left_fork  = Fork[1]
Philo[1].right_fork = Fork[2]

Philo[2].info = Observer
Philo[2].left_fork  = Fork[2]
Philo[2].right_fork = Fork[3]

Philo[3].info = Observer
Philo[3].left_fork  = Fork[3]
Philo[3].right_fork = Fork[1]

Philo[1]:start()
Philo[2]:start()
Philo[3]:start()
