# Cutover Runbook (Aya)

This runbook describes a safe cutover from Rust `fast-frontend` to Phoenix `frontend-ex`.

## Principles

- Deploy `frontend-ex` side-by-side first (no Caddy routing changes).
- Switch Caddy routing only after verification.
- Keep Rust `fast-frontend` available for rollback during the stability window.

## Side-by-Side Verification

1. Ensure the service is running:

```bash
ssh aya "systemctl status frontend-ex --no-pager"
```

2. Verify locally on `aya` (no Caddy involved):

```bash
ssh aya "curl -fsS http://127.0.0.1:5174/ >/dev/null && echo OK"
ssh aya "curl -fsS http://127.0.0.1:5174/exportData >/dev/null && echo OK"
```

Optional spot checks (use a known real tx/address on the target network):

```bash
ssh aya "curl -fsS http://127.0.0.1:5174/tx/<hash> >/dev/null && echo OK"
ssh aya "curl -fsS http://127.0.0.1:5174/address/<address> >/dev/null && echo OK"
```

## Enable Caddy Routing

1. Merge `ops/caddy/Caddyfile.frontend-ex.snippet` into the main `:80 { ... }` block of:

- `/mnt/sepolia/blockscout-proxy/Caddyfile`

2. Restart Caddy:

```bash
ssh aya "podman restart blockscout-proxy_caddy_1"
```

3. Verify external traffic is served by `frontend-ex`:

- Check response headers for `X-Frontend: frontend-ex`
- Spot-check `/`, `/tx/<hash>`, `/address/<address>`

## Rollback

1. Revert the Caddyfile changes (remove/undo the `frontend-ex` handle blocks).
2. Restart Caddy:

```bash
ssh aya "podman restart blockscout-proxy_caddy_1"
```

## Stability Window

- Keep Rust `fast-frontend` service and binaries intact until the agreed stability window passes.
- Monitor `journalctl -u frontend-ex`
- Monitor Caddy logs
- Monitor upstream API error rates/latency
