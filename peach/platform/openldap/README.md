```
kubectl --context peach -n openldap cp openldap-stack-ha-0:/var/lib/ldap/data.mdb ./data.mdb
kubectl --context peach -n openldap cp openldap-stack-ha-0:/var/lib/ldap/lock.mdb ./lock.mdb
```