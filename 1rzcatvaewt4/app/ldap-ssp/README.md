
```
ibmcloud login -r jp-tok --sso -g Default
# ibmcloud ce project create --name ldap
ibmcloud ce project select --name ldap
export KUBECONFIG=$(ibmcloud ce project current --output jsonpath='{.kube_config_file}')
```

### Secret

```
./decrypt.sh 1rzcatvaewt4/app/ldap-ssp/credentials.sops.yaml
ytt -f 1rzcatvaewt4/app/ldap-ssp/config/secret.yaml --data-values-file 1rzcatvaewt4/app/ldap-ssp/credentials.yaml | kapp deploy -a ldap-ssp-config -c --diff-mask=false -f - -y
./encrypt.sh 1rzcatvaewt4/app/ldap-ssp/credentials.yaml 
```

### KService

```
cd /tmp
rm -rf ldap-ssp
git clone https://github.com/categolj/ldap-ssp -b images 
cd -

ytt -f 1rzcatvaewt4/app/ldap-ssp/config/workload.yaml -f 1rzcatvaewt4/app/ldap-ssp/config/kapp-config.yaml --data-values-file /tmp/ldap-ssp/native_amd64.yaml | kapp deploy -a ldap-ssp -c -f - -y
```