openssl req -newkey rsa:1024 -sha1 -keyout clientkey.pem -out clientreq.pem -nodes -config ./client.cnf -days 365 -batch

openssl x509 -req -in clientreq.pem -sha1 -extfile ./client.cnf -extensions usr_cert -CA rootA.pem -CAkey rootAkey.pem -CAcreateserial -out clientcert.pem -days 365

cat clientcert.pem rootA.pem > client.pem

openssl x509 -subject -issuer -noout -in client.pem
