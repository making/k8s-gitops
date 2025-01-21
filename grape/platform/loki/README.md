
```bash
helm upgrade --install --create-namespace \
  -n loki \
  loki \
  oci://registry-1.docker.io/bitnamicharts/grafana-loki \
  -f helm-values.yaml \
  --version 4.7.2 \
  --wait
```

