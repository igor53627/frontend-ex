# Runbooks

Operational runbooks will live in this directory.

## Index

- `deploy.md` - Deploy/rollback `frontend-ex` on `aya` and restart Caddy (podman).
- `cutover.md` - Switch Caddy routing from Rust `fast-frontend` to `frontend-ex` with rollback.

## Notes

- Service is in migration; only a subset of routes are implemented.
- Deployment/cutover steps are tracked in backlog tasks.
