

### Secret

```
export KUBECONFIG=~/.kube/config-ibmcloud

./decrypt.sh zje2gl28i8h/app/translation-api/credentials.sops.yaml
ytt -f zje2gl28i8h/app/translation-api/config/secret.yaml --data-values-file zje2gl28i8h/app/translation-api/credentials.yaml | kapp deploy -a translation-config -c --diff-mask=false -f - -y
./encrypt.sh zje2gl28i8h/app/translation-api/credentials.yaml 
```

### KService

```
cd /tmp
git clone https://github.com/categolj/translation-api -b images 
cd -

export KUBECONFIG=~/.kube/config-ibmcloud

ytt -f zje2gl28i8h/app/translation-api/config/workload.yaml -f zje2gl28i8h/app/translation-api/config/kapp-config.yaml --data-values-file /tmp/translation-api/native_amd64.yaml | kapp deploy -a translation-api -c -f - -y
```