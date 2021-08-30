# guac-install
Script basé sur les sources https://github.com/MysticRyuujin/guac-install
 - Ajout Fail2Ban & ufw
 - Ajout LDAP
 - Correctif droit root pour RDP
 - Un peu de trad fr

## Script pour Debian 10

## How to Run:

### Télécharger directement depuis :

`wget https://git.io/JEz9u -O guac-install.sh`

### Rendre le script executable:

`chmod +x guac-install.sh`

### Exéctuer le script en root:

`./guac-install.sh`


# Fonctionnement LDAP

Apres avoir installé le module LDAP (demandé lors de l'installation) 
- Se connecte avec le compte admin local créé (guacadmin/guacadmin)
- Créez vous un compte local dans guacamole avec le meme identifiant que votre compte AD, mais avec un mot de passe différent.
- Donnez vous les droits d'administrations total
- Enfin connectez vous avec votre compte AD (Vous allez récupérer l'administration de guacamole + la gestion des comptes de votre AD)

### Exemple
![alt text](https://github.com/zazazouthecat/guac-install/blob/main/ldap_guac.png?raw=true)

### Extrait de /etc/guacamole/guacamole.properties
```
ldap-hostname: JohnDoe.local
ldap-port: 389
ldap-user-base-dn: OU=Accounts_Users,DC=JohnDoe,DC=local
ldap-username-attribute: sAMAccountName
ldap-search-bind-dn: CN=ad_binder,OU=Accounts_Service,DC=JohnDoe,DC=local
ldap-search-bind-password:myverystrongpassword
ldap-encryption-method: none```
