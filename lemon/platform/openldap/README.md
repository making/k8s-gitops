```
kubectl --context lemon -n openldap cp openldap-stack-ha-0:/var/lib/ldap/data.mdb ./data.mdb
kubectl --context lemon -n openldap cp openldap-stack-ha-0:/var/lib/ldap/lock.mdb ./lock.mdb
```