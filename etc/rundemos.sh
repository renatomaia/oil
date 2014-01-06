#!/bin/sh

demos="adapt
       adaptor
       concurrent
       cos
       deferred
       doubleserver
       except
       hello
       hello_simple
       interceptors
       ludo_byref
       ludo_icepted
       ludo_objects
       objectmap
       persist
       philo
       selfcall
       valuetype"

cd ../demo

for demo in $demos ; do
	cd "$demo"
	echo "<<< $demo >>>"
	./execute
	read -p "Press any key to continue..."
	cd ..
done
