# Traefik plugin pre-baked image

Traefik downloads the plugins listed in `helm-values.yaml` (`experimental.plugins.*`) from
`plugins.traefik.io` at every container start. When the registry is slow or unreachable, the
container fails to come up. `build-image.sh` produces a multi-arch Docker image that ships
those plugins inside the image, and a ytt overlay that switches the rendered Deployment from
`experimental.plugins` (download) to `experimental.localPlugins` (offline).

## When to run

- After editing `helm-values.yaml` `experimental.plugins` (added, removed, or version-bumped a
  plugin).
- After bumping the chart version in `lemon/platform/_apps/traefik.yaml` (the script picks up the
  new appVersion automatically and re-tags the image).

## Requirements

- `docker` with `buildx` (the script invokes `mikefarah/yq:4` via `docker run` for YAML parsing,
  so no host `yq` is needed).
- For `--push` / `--multi-arch`: a `docker login ghcr.io` session under the `making` org.

## Usage

```sh
cd lemon/platform/traefik

# Default: build for the host arch, --load into local docker, verify by booting
# traefik briefly and checking that "Plugins loaded" appears in the logs.
./build-image.sh

# Push a single-arch image (host arch) to ghcr.io.
./build-image.sh --push

# Build linux/amd64 + linux/arm64 and push as a manifest list. First run creates
# a 'traefik-image-builder' buildx builder (docker-container driver); reused
# afterwards.
./build-image.sh --multi-arch --push

# Skip the in-container verification (e.g. when iterating).
./build-image.sh --no-verify

# Override base image / repo / tag.
./build-image.sh --traefik-version=v3.7.0 \
                 --image=ghcr.io/making/traefik \
                 --tag=v3.7.0-mybranch
```

## What the script produces

| Path                                       | Committed | Purpose                                                                            |
| ------------------------------------------ | --------- | ---------------------------------------------------------------------------------- |
| `Dockerfile.generated`                      | no        | Multi-stage Dockerfile that downloads each plugin zip and unpacks under `/plugins-local/src/<moduleName>/` |
| `config/local-plugins-overlay.yaml`         | yes       | ytt overlay that rewrites the Helm-rendered Traefik Deployment image and swaps `experimental.plugins` args for `experimental.localPlugins` |

The image tag is `<traefik-version>-<plugin-hash>`, where `plugin-hash` is the first 7 chars of
sha256 over a sorted `<name>=<moduleName>@<version>` list. Adding a plugin or bumping a version
produces a new tag automatically.

## Deployment flow

1. Edit plugins in `helm-values.yaml` (or bump the chart in `_apps/traefik.yaml`).
2. Run `./build-image.sh --multi-arch --push`.
3. Commit the regenerated `config/local-plugins-overlay.yaml` (the new tag changes the `image:`
   line). `Dockerfile.generated` is `.gitignore`d.
4. `kapp-controller` re-renders the App on its next sync (or `kubectl annotate ... kapp-controller.k14s.io/reconcile`
   to force it). The ytt step in `_apps/traefik.yaml` already loads everything under
   `lemon/platform/traefik/config/`, so the overlay is picked up without any `_apps` change.

## Verifying without re-running the build

```sh
docker run --rm ghcr.io/making/traefik:<tag> \
  --log.level=INFO --api.insecure=true --entryPoints.web.address=:8000 \
  --experimental.localPlugins.coraza.moduleName=github.com/jcchavezs/coraza-http-wasm-traefik \
  --experimental.localPlugins.oidc-auth.moduleName=github.com/sevensolutions/traefik-oidc-auth \
  --experimental.localPlugins.api-token.moduleName=github.com/Aetherinox/traefik-api-token-middleware
```

Look for `Loading plugins...` followed by `Plugins loaded.` with all three plugin names listed.
