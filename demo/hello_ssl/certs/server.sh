openssl req -newkey rsa:1024 -keyout serverkey.pem -out serverreq.pem -config ./server.cnf -nodes -days 365 -batch

openssl x509 -req -in serverreq.pem -sha1 -extfile ./server.cnf -extensions usr_cert -CA rootA.pem -CAkey rootAkey.pem -CAcreateserial -out servercert.pem -days 365

cat servercert.pem rootA.pem > server.pem

openssl x509 -subject -issuer -noout -in server.pem
