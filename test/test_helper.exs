ExUnit.start()

# Pin the release-version overrides so golden HTML snapshots don't drift on
# every commit. Production uses the compile-time values; tests get fixed ones.
Application.put_env(:frontend_ex, :app_version_override, "test")
Application.put_env(:frontend_ex, :git_sha_override, "testsha")
