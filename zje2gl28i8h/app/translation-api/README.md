

```
cd /tmp
git clone https://github.com/categolj/translation-api -b images 
cd -

export KUBECONFIG=~/.kube/config-ibmcloud

ytt -f zje2gl28i8h/app/translation-api/config --data-values-file /tmp/translation-api/native_amd64.yaml | kapp deploy -a translation-api -c -f - -y
```