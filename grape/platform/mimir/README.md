
```bash
helm upgrade --install --create-namespace \
  -n mimir \
  mimir \
  oci://registry-1.docker.io/bitnamicharts/grafana-mimir \
  -f helm-values.yaml \
  --version 1.3.2 \
  --wait
```

