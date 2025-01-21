
```bash
htpasswd -c auth myuser
kubectl create ns nginx
kubectl create secret -n nginx generic nginx-basic-auth --from-file=auth

helm upgrade --install --create-namespace \
  -n nginx \
  nginx \
  oci://registry-1.docker.io/bitnamicharts/nginx \
  -f helm-values.yaml \
  --version 18.3.5 \
  --wait
```

