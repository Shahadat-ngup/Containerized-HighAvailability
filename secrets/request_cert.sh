#!/bin/bash
# Script to request certificate from Dyn using lego and verify PEM/KEY files



# Load credentials from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found. Please create it with DYNU_API_KEY, EMAIL, DOMAIN."
    exit 1
fi

# Give the absolute path
CERT_DIR="$(pwd)/.lego/certificates"

# Check if Certs exists
if [[ -f "$CERT_DIR/_wildcard.${DOMAIN}.crt" && -f "$CERT_DIR/_wildcard.${DOMAIN}.issuer.crt" ]]; then
    echo "Certificates already exist. Skipping request."
else
    lego --email "$EMAIL" --dns dynu -d "*.$DOMAIN" -d "$DOMAIN" run
fi

WILDCARD_CERT="$CERT_DIR/_.${DOMAIN}.crt"
WILDCARD_ISSUER="$CERT_DIR/_.${DOMAIN}.issuer.crt"
FULLCHAIN="$CERT_DIR/fullchain.pem"
if [[ -f "$WILDCARD_CERT" && -f "$WILDCARD_ISSUER" ]]; then
    cat "$WILDCARD_CERT" "$WILDCARD_ISSUER" > "$FULLCHAIN"
    echo "Fullchain created at $FULLCHAIN"
else
    echo "Wildcard cert or issuer not found for fullchain creation."
fi

