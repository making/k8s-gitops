
```
ibmcloud login -r jp-tok --sso -g Default
ibmcloud ce project select --name blog
export KUBECONFIG=$(ibmcloud ce project current --output jsonpath='{.kube_config_file}')
```

### Secret

```
./decrypt.sh zje2gl28i8h/app/translation-api/credentials.sops.yaml
ytt -f zje2gl28i8h/app/translation-api/config/secret.yaml --data-values-file zje2gl28i8h/app/translation-api/credentials.yaml | kapp deploy -a translation-config -c --diff-mask=false -f - -y
./encrypt.sh zje2gl28i8h/app/translation-api/credentials.yaml 
```

### KService

```
cd /tmp
rm -rf translation-api
git clone https://github.com/categolj/translation-api -b images 
cd -

ytt -f zje2gl28i8h/app/translation-api/config/workload.yaml -f zje2gl28i8h/app/translation-api/config/kapp-config.yaml --data-values-file /tmp/translation-api/native_amd64.yaml | kapp deploy -a translation-api -c -f - -y
```