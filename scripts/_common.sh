#!/bin/bash


# Wait until cap answers 200 on /health (app AND redis healthy).
cap_wait_ready() {
    local cap_ready=""
    for i in $(seq 1 30); do
        if curl -s --max-time 3 "http://127.0.0.1:$port/health" | grep -q '"ok"'; then
            cap_ready=1
            break
        fi
        sleep 1
    done
    if [ -z "$cap_ready" ]; then
        journalctl --quiet --no-pager --lines=50 --unit="$app" >&2 || true
        ynh_die "cap did not become healthy on http://127.0.0.1:$port"
    fi
}

# in_subdir=2 would flatten every second-level dir and clobber standalone/package.json; hand-move standalone/ out, preserving node_modules/.bun-cache/bin/env/redis.conf.
cap_place_standalone() {
    local repo_dir="$install_dir/.repo"
    [ -d "$repo_dir/standalone" ] || ynh_die "extracted source has no standalone/ subdir"
    mv "$repo_dir/standalone" "$install_dir/.standalone"
    rm -rf "$repo_dir"

    # Drop the previous app files that the tarball re-supplies.
    rm -rf "$install_dir/src" "$install_dir/public" "$install_dir/test"
    rm -f "$install_dir/package.json" "$install_dir/bun.lock" \
          "$install_dir/Dockerfile" "$install_dir/Dockerfile.dockerignore" \
          "$install_dir/docker-compose.yml" "$install_dir/docker-compose.dev.yml"

    shopt -s nullglob dotglob
    for f in "$install_dir/.standalone"/*; do
        mv -f "$f" "$install_dir/"
    done
    shopt -u nullglob dotglob
    rmdir "$install_dir/.standalone"
    chown -R "$app:$app" "$install_dir"
}
