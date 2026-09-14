# Security and public-repository policy

This repository is public. Treat every committed file as internet-visible.

## Never commit

- passwords or password hashes intended for real use;
- SSH private keys or authorized public keys tied to a real host/user;
- API tokens, Cloudflare tokens, debrid credentials, application secrets, cookies, session material, or bearer tokens;
- populated `.env` files;
- real internal/private IP addresses or network topology details that are not required for public documentation;
- personal email addresses or account identifiers;
- production database files, backups, logs, certificates, or ACME state;
- screenshots or diagnostic output containing credentials or personally identifying data.

## Allowed in documentation

Use obvious placeholders such as:

```text
<HOSTNAME>
<DOMAIN>
<LXC_IP>
<SSH_PUBLIC_KEY>
<LETSENCRYPT_EMAIL>
<CLOUDFLARE_API_TOKEN>
<AUTHELIA_SESSION_SECRET>
```

Example domains and addresses must use reserved documentation values such as `example.com`, `192.0.2.0/24`, `198.51.100.0/24`, or `203.0.113.0/24`.

## Local secret handling

Real configuration belongs only on the deployment host, preferably in files excluded by `.gitignore` or in a dedicated secret-management mechanism.

Before every commit:

```bash
git diff --cached
git grep -nEi '(password|passwd|token|secret|api[_-]?key|private[_-]?key|authorization)' -- . ':!SECURITY.md'
```

The grep is only a safety check and does not replace manual review.

## Credential exposure

If a credential is pasted into chat, a terminal transcript, an issue, a commit, or any other potentially retained location, treat it as exposed and rotate it before production use.
