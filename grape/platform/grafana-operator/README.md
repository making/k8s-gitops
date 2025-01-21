
```bash
helm upgrade --install --create-namespace \
  -n grafana \
  grafana \
  oci://registry-1.docker.io/bitnamicharts/grafana-operator \
  -f helm-values.yaml \
  --version 4.8.1 \
  --wait
```


* username: `admin`
* password: Run `kubectl get secret -n grafana grafana-grafana-operator-grafana-admin-credentials -otemplate='{{.data.GF_SECURITY_ADMIN_PASSWORD | base64decode}}'`