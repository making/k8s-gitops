```
kubectl apply -f https://github.com/carvel-dev/kapp-controller/releases/download/v0.53.0/release.yml
```

```
NAMESPACE=app-install
kubectl create ns ${NAMESPACE}
kubectl create -n ${NAMESPACE} sa kapp
kubectl create clusterrolebinding kapp-cluster-admin-${NAMESPACE} --clusterrole cluster-admin --serviceaccount=${NAMESPACE}:kapp
```