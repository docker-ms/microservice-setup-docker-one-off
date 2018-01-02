openssl genrsa \
  -des3 \
  -out root/root_cert_private_key.pem \
  2048

openssl req \
  -x509 \
  -nodes \
  -sha256 \
  -new \
  -key root/root_cert_private_key.pem \
  -days 3650 \
  -out root/root_cert.pem \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=V-CUBE, Inc./OU=DEV/CN=*.sgdev.vcube.com/emailAddress=leonard.shi@vcube.com.sg"

==========================================================End of generating root CA==========================================================

openssl genrsa \
  -out server/server_cert_private_key.pem \
  2048

openssl req \
  -new \
  -key server/server_cert_private_key.pem \
  -out server/server_cert.csr \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=V-CUBE, Inc./OU=DEV/CN=*.sgdev.vcube.com/emailAddress=leonard.shi@vcube.com.sg"

openssl x509 \
  -sha256 \
  -req -in server/server_cert.csr \
  -CA root/root_cert.pem \
  -CAkey root/root_cert_private_key.pem \
  -CAcreateserial \
  -out server/server_cert.pem \
  -days 3650 \
  -extfile ../v3.ext

=========================================================End of generating server CA=========================================================

openssl genrsa \
  -des3 \
  -out client/client_cert_private_key.pem \
  2048

openssl req \
  -new \
  -key client/client_cert_private_key.pem \
  -out client/client_cert.csr \
  -subj "/C=SG/ST=Singapore/L=Singapore/O=V-CUBE, Inc./OU=DEV/CN=*.sgdev.vcube.com/emailAddress=leonard.shi@vcube.com.sg"

openssl x509 \
  -sha256 \
  -req -in client/client_cert.csr \
  -CA root/root_cert.pem \
  -CAkey root/root_cert_private_key.pem \
  -CAcreateserial \
  -out client/client_cert.pem \
  -days 3650 \
  -extfile ../v3.ext

=========================================================End of generating client CA=========================================================

openssl pkcs12 -export -out root/root_cert.pfx -inkey root/root_cert_private_key.pem -in root/root_cert.pem

Export Password: 1234567890


