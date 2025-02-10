
```bash
helm upgrade --install \
  -n korifi \
  korifi \
  https://github.com/cloudfoundry/korifi/releases/download/v0.14.0/korifi-0.14.0.tgz \
  -f pineapple/platform/korifi/helm-values.yaml \
  --wait
```