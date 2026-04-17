ExUnit.start()

# Pin the release-version overrides so golden HTML snapshots don't drift on
# every commit. Production uses the compile-time values; tests get fixed ones.
Application.put_env(:frontend_ex, :app_version_override, "test")
Application.put_env(:frontend_ex, :git_sha_override, "testsha")
# Backend version: pin to a fixed value so goldens don't depend on the
# fixture `/api/v2/health` response (and don't need a fixture at all).
Application.put_env(:frontend_ex, :backend_version_override, "test-backend")
