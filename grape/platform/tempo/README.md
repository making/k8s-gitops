
```bash
helm upgrade --install --create-namespace \
  -n tempo \
  tempo \
  oci://registry-1.docker.io/bitnamicharts/grafana-tempo \
  -f helm-values.yaml \
  --version 3.8.3 \
  --wait
```

* username: `admin`
* password: Run `kubectl get secret -n grafana grafana-grafana-operator-grafana-admin-credentials -otemplate='{{.data.GF_SECURITY_ADMIN_PASSWORD | base64decode}}'
`