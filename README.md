```
kubectl apply -f https://github.com/carvel-dev/kapp-controller/releases/download/v0.59.0/release.yml
```

```
NAMESPACE=app-install
kubectl create ns ${NAMESPACE}
kubectl create -n ${NAMESPACE} sa kapp
kubectl create clusterrolebinding kapp-cluster-admin-${NAMESPACE} --clusterrole cluster-admin --serviceaccount=${NAMESPACE}:kapp
kubectl create secret generic -n ${NAMESPACE} age-key --from-file=key.txt --dry-run=client -oyaml | kubectl apply -f-
```

```
brew install age
```

```
kubectl get secrets -n app-install age-key -otemplate='{{index .data "key.txt" | base64decode}}' > key.txt
chmod 600 key.txt
```