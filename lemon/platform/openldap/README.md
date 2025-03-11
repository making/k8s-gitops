backup

```
kubectl --context lemon -n openldap cp openldap-stack-ha-0:/var/lib/ldap/data.mdb ./data.mdb
kubectl --context lemon -n openldap cp openldap-stack-ha-0:/var/lib/ldap/lock.mdb ./lock.mdb
```

restore

```
kubectl --context lemon -n openldap cp ./data.mdb openldap-stack-ha-0:/var/lib/ldap/data.mdb 
kubectl --context lemon -n openldap cp ./lock.mdb openldap-stack-ha-0:/var/lib/ldap/lock.mdb
kubectl --context lemon -n openldap delete pod -l app=openldap-stack-ha --force
```