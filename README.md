# 🛡️ guac-install
Script basé sur les sources https://github.com/MysticRyuujin/guac-install

📝
 - Ajout Fail2Ban & ufw
 - Ajout LDAP
 - Correctif droit root pour RDP
 - Un peu de trad fr

## 🐧 Linux distribution 
✅ Debian 10  ❌ Debian 11  ✅ Ubuntu 20

# 🚩 Installation 🚩

### Télécharger directement depuis :

`wget https://git.io/JEz9u -O guac-install.sh`

### Rendre le script executable:

`chmod +x guac-install.sh`

### Exéctuer le script en root:

`./guac-install.sh`


### 🔹 Exemple connexion RDP

![alt text](https://github.com/zazazouthecat/guac-install/blob/main/rdp_guac.png?raw=true)

### 🔹 Exemple connexion SSH

![alt text](https://github.com/zazazouthecat/guac-install/blob/main/ssh_guac.png?raw=true)


# 📚 Fonctionnement LDAP

Apres avoir installé le module LDAP (demandé lors de l'installation) 
- Se connecte avec le compte admin local créé (guacadmin/guacadmin)
- Créez vous un compte local dans guacamole avec le meme identifiant que votre compte AD, mais avec un mot de passe différent.
- Donnez vous les droits d'administrations total
- Enfin connectez vous avec votre compte AD (Vous allez récupérer l'administration de guacamole + la gestion des comptes de votre AD)

### 🔹 Exemple AD
![alt text](https://github.com/zazazouthecat/guac-install/blob/main/ldap_guac.png?raw=true)

### 🔹 Extrait de /etc/guacamole/guacamole.properties
```
ldap-hostname: JohnDoe.local
ldap-port: 389
ldap-user-base-dn: OU=Accounts_Users,DC=JohnDoe,DC=local
ldap-username-attribute: sAMAccountName
ldap-search-bind-dn: CN=ad_binder,OU=Accounts_Service,DC=JohnDoe,DC=local
ldap-search-bind-password:myverystrongpassword
ldap-encryption-method: none
```

# 🛑 Enregistrement (Video & Keylogger)
## Variables exploitables
```
${GUAC_USERNAME}   --- Nom de l'utilisateur connecté
${GUAC_DATE}   --- Date actuelle
${GUAC_TIME}   --- Heure actuelle
${GUAC_CLIENT_ADDRESS}   --- L'adresse IPv4 ou IPv6 de l'utilisateur actue
${GUAC_CLIENT_HOSTNAME}   --- Le nom d'hôte de l'utilisateur actuel
```

Le serveur n'enregistre pas la video en format lisible directement (protocol dumps).

il faudra exploiter la commande `guacenc` pour encoder la video 

il faudra exploiter la commande `guaclog` pour encoder les frappes clavier

### 🔹 Exemple d'enregistrement
![alt text](https://github.com/zazazouthecat/guac-install/blob/main/rec_guac.png?raw=true)

### 🔹 Exemple d'encodage vidéo & frappes clavier

Encodage de l'enregisrement video **/log/bastion/MON_SRV/MON_SRV_RECORD_johndoe_20210827_105342** en résolution 1920x1080

`guacenc -s 1920x1080 -f /log/bastion/MON_SRV/MON_SRV_RECORD_johndoe_20210827_105342`

Encode des frappes au clavier **/log/bastion/MON_SRV/MON_SRV_RECORD_johndoe_20210827_105342**

`guaclog -f /log/bastion/MON_SRV/MON_SRV_RECORD_johndoe_20210827_105342`

# ✏️ Customisation 
Personalisation du nom et du logo de la page d'acceuil de Guacamole

Il faut placer le fichier `branding.jar` dans `/etc/guacamole/extensions`
https://github.com/zazazouthecat/guac-install/raw/main/branding.jar

Le fichier `branding.jar` peut etre édité avec 7zip.

Pour mettre votre logo  : - Remplacer le fichier `images\logo-placeholder.png`

Pour mettre votre propre nom  : - Editer avec bloc-note le fichier `translations\fr.json`

### 🔹 Exemple fichier fr.json

```
{
    "NAME" : "Français",
		
    "APP":{
	
	"NAME" : "BASTION THE NERD CAT"

	  },
	  
	"CLIENT": {
		  	
	"TEXT_CLIENT_STATUS_CONNECTING": "Connexion...",
    "TEXT_CLIENT_STATUS_DISCONNECTED": "Vous avez été deconnecté.",
    "TEXT_CLIENT_STATUS_UNSTABLE": "La connexion au serveur semble instable.",
	"TEXT_CLIENT_STATUS_WAITING": "Connexion, En attente de réponse..."
		  
	  }
}
```
