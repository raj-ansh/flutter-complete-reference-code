#!/bin/sh
# Makes a throw-away, self-signed certificate for localhost, valid for 7 days.
# The key is never committed: this script creates it on your own machine.
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 7 \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
