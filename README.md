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


#### Fonctionnement LDAP

Apres avoir installé le module LDAP (demandé lors de l'installation) 
- Se connecte avec le compte admin local créé (guacadmin/guacadmin)
- Créez vous un compte local dans guacamole avec le meme identifiant que votre compte AD, mais avec un mot de passe différent.
- Donnez vous les droits d'administrations total
- Enfin connectez vous avec votre compte AD (Vous allez récupérer l'administration de guacamole + la gestion des comptes de votre AD)
