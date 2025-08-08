# Certificate Management in `secrets/`

This folder contains scripts and files for managing SSL/TLS certificates for your IAM HA stack.

## Usage
- Store your Dynu API key, email, and domain in `.env` (do not hardcode in scripts).
- Use `request_cert.sh` to request certificates using lego and Dynu DNS.
- Generated certificates are found in `.lego/certificates/`.
- To create a fullchain certificate, concatenate your domain certificate and issuer certificate:

```bash
cat .lego/certificates/_wildcard.<your-domain>.crt .lego/certificates/_wildcard.<your-domain>.issuer.crt > fullchain.pem
```

## Security
- `.env` and `.lego/` are ignored by git via `.gitignore`.
- Never commit your API keys or private certificates.
