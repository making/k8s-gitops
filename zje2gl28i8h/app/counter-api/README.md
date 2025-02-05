
```
ibmcloud login -r jp-tok --sso -g Default
ibmcloud ce project select --name blog
export KUBECONFIG=$(ibmcloud ce project current --output jsonpath='{.kube_config_file}')
```

### Secret

```
./decrypt.sh zje2gl28i8h/app/counter-api/credentials.sops.yaml
ytt -f zje2gl28i8h/app/counter-api/config/secret.yaml --data-values-file zje2gl28i8h/app/counter-api/credentials.yaml | kapp deploy -a counter-config -c --diff-mask=false -f - -y
./encrypt.sh zje2gl28i8h/app/counter-api/credentials.yaml 
```

### KService

```
cd /tmp
rm -rf counter-api
git clone https://github.com/categolj/counter-api -b images 
cd -

ytt -f zje2gl28i8h/app/counter-api/config/workload.yaml -f zje2gl28i8h/app/counter-api/config/kapp-config.yaml --data-values-file /tmp/counter-api/image.yaml | kapp deploy -a counter-api -c -f - -y
```