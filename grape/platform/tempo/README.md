
```bash
helm upgrade --install --create-namespace \
  -n tempo \
  tempo \
  oci://registry-1.docker.io/bitnamicharts/grafana-tempo \
  -f helm-values.yaml \
  --version 3.8.3 \
  --wait
```
