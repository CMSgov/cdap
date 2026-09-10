# mTLS Sidecar

A lightweight Go proxy that terminates mutual TLS (mTLS) in front of an
application container, using a private certificate issued by AWS Private CA
and fetched from ACM at startup.

## What This Is *Not* For

**This sidecar does not work behind an ALB target group.** ALB never
presents a client certificate on the ALB-to-target hop — it can validate
*inbound* client certs via a trust store on the listener (`verify` mode),
but it does not forward a client cert onward to targets. Pairing this
sidecar with `RequireAndVerifyClientCert` behind an ALB will fail every
handshake, because the certificate the sidecar is waiting for never
arrives.

For ALB-fronted mTLS — validating the *caller's* certificate at the edge —
use an ALB listener trust store instead (`aws_lb_trust_store` +
`mutual_authentication { mode = "verify" }`). See the trust-store example
stack (follow-up PR) for that pattern.

## What This Is For

- **NLB TLS passthrough.** An NLB forwards raw TCP without terminating
  TLS, so the real client certificate reaches this sidecar unmodified —
  the scenario this proxy was built to handle.
- **Egress from a service or Lambda function.** A workload that needs to
  present its own client certificate when calling another internal system
  that enforces mTLS. The ACM-export and in-memory decrypt logic here is
  reusable for that direction with a small change to `cmd/proxy/main.go`
  (dial out with the client cert instead of listening for one).

This is not currently wired into any live stack. It's being merged now as
a tested, documented building block for cross-service egress work as we
refine network access controls between services in this account.

## Architecture
Client (NLB passthrough / internal caller) ↓ mTLS handshake — client cert required mTLS proxy sidecar :8443 (PROXY_LISTEN_PORT) ↓ terminates mTLS, reverse-proxies over plain HTTP App container :8080 (localhost, UPSTREAM_URL)


A separate plain-HTTP health endpoint runs on `:8081` (`HEALTH_PORT`) for
ECS container health checks — this port never requires a client cert, so
health checks aren't blocked by mTLS enforcement.

## Startup Self-Test

On startup, the proxy performs a full mTLS handshake against itself
(`localhost:PROXY_LISTEN_PORT`) before accepting real traffic. If it
fails, the container exits non-zero — ECS marks the task unhealthy and
the deployment circuit breaker rolls back to the last good revision. This
catches cert/key mismatches and misconfiguration before they reach
traffic, rather than after.

## Certificate Handling

At startup (unless `USE_LOCAL_CERTS=true`), the proxy:

1. Generates a fresh random passphrase (never logged, never written to
   disk).
2. Calls ACM `ExportCertificate` for `ACM_CERTIFICATE_ARN`.
3. Decrypts the returned PKCS#8 private key entirely in memory.
4. Verifies the cert/key pair matches before writing anything to disk.
5. Writes cert, key, and CA chain to `/run/certs` (tmpfs, mode `0600`).

Private key material — encrypted or plaintext, passphrases, and raw ACM
response bytes — is never logged under any circumstance. Task
definitions should mount `/run/certs` as a `tmpfs` volume with
`noexec,nosuid,nodev` and no persistent storage.

## Known Limitations / Follow-Ups

    No CRL/OCSP revocation checking — a compromised-but-unexpired client cert is still trusted. Tracked as a future enhancement if PCA revocation lists are needed.
    Built for ingress (listen mTLS, proxy plain HTTP). An egress variant (listen plain HTTP, dial out with a client cert) shares this code's ACM logic but needs a separate main.go — not yet built.
    No retry/backoff around the ACM ExportCertificate call itself. If many tasks start simultaneously during a deploy, ACM rate limits could cause spurious startup failures.
