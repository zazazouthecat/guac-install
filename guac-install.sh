#Script SBER v1.0 - 25/08/2021
#Script basé sur les sources https://github.com/MysticRyuujin/guac-install
# - Ajout Fail2Band
# - Ajout LDAP
# - Correctif droit root pour RDP
# - Un peu de trad fr

#!/bin/bash
# Something isn't working? # tail -f /var/log/messages /var/log/syslog /var/log/tomcat*/*.out /var/log/mysql/*.log

# Check if user is root or sudo
if ! [ $( id -u ) = 0 ]; then
    echo "Merci de lancer ce script en sudo" 1>&2
    exit 1
fi

# Check to see if any old files left over
if [ "$( find . -maxdepth 1 \( -name 'guacamole-*' -o -name 'mysql-connector-java-*' \) )" != "" ]; then
    echo "Fichiers d'installation temporaire detectés. Merci d'executer 'rm guacamole-* -R' & 'rm mysql-connector-java-* -R'" 1>&2
    exit 1
fi

# Version number of Guacamole to install
# Homepage ~ https://guacamole.apache.org/releases/
GUACVERSION="1.3.0"

# Latest Version of MySQL Connector/J if manual install is required (if libmariadb-java/libmysql-java is not available via apt)
# Homepage ~ https://dev.mysql.com/downloads/connector/j/
MCJVER="8.0.19"

# Colors to use for output
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log Location
LOG="/tmp/guacamole_${GUACVERSION}_build.log"

# Initialize variable values
installTOTP=""
installDuo=""
installMySQL=""
installFail2ban=""
installLDAP=""
mysqlHost=""
mysqlPort=""
mysqlRootPwd=""
guacDb=""
guacUser=""
guacPwd=""
PROMPT=""
MYSQL=""
ldapHost=""
ldapPort=""
ldapDC1=""
ldapDC2=""
ldapUserOu=""
ldapUserAttribute=""
ldapUserBind=""
ldapUserBindOu=""
ldapUserBindPassword=""
fail2banbanTime=""
fail2banfindTime=""
fail2banmaxRetry=""
fail2bancustomIp=""
fail2banNotBanIpRange=""

#Prez !
clear
echo -e "${YELLOW} |'-._/\_.-'| ***************************************** |'-._/\_.-'| "
echo -e "${YELLOW} |    ||    | ***************************************** |    ||    | "
echo -e "${YELLOW} |___o()o___| ***************************************** |___o()o___| "
echo -e "${YELLOW} |__((<>))__| ********** BASTION DE SECURITE ********** |__((<>))__| "
echo -e "${YELLOW} \   o\/o   / **********   Apache Guacamole  ********** \   o\/o   /"
echo -e "${YELLOW}  \   ||   /  **********        Ver 1.0      **********  \   ||   /"
echo -e "${YELLOW}   \  ||  /   *****************************************   \  ||  /"
echo -e "${YELLOW}    '.||.'    **********************************SBER***    '.||.'"
echo -e "${YELLOW}      ''      *****************************************      ''"
echo
echo
# Fin de Prez !


# Get script arguments for non-interactive mode
while [ "$1" != "" ]; do
    case $1 in
        # Install MySQL selection
        -i | --installmysql )
            installMySQL=true
            ;;
        -n | --nomysql )
            installMySQL=false
            ;;

        # MySQL server/root information
        -h | --mysqlhost )
            shift
            mysqlHost="$1"
            ;;
        -p | --mysqlport )
            shift
            mysqlPort="$1"
            ;;
        -r | --mysqlpwd )
            shift
            mysqlRootPwd="$1"
            ;;

        # Guac database/user information
        -db | --guacdb )
            shift
            guacDb="$1"
            ;;
        -gu | --guacuser )
            shift
            guacUser="$1"
            ;;
        -gp | --guacpwd )
            shift
            guacPwd="$1"
            ;;

        # MFA selection
        -t | --totp )
            installTOTP=true
            ;;
        -d | --duo )
            installDuo=true
            ;;
        -o | --nomfa )
            installTOTP=false
            installDuo=false
            ;;
    esac
    shift
done

#if [[ -z "${installTOTP}" ]] && [[ "${installDuo}" != true ]]; then
    # Prompt the user if they would like to install TOTP MFA, default of no
 #   echo -e -n "${CYAN}MFA: Would you like to install TOTP? (y/N): ${NC}"
 #   read PROMPT
 #   if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
 #       installTOTP=true
 #       installDuo=false
 #   else
 #       installTOTP=false
 #   fi
#fi

#if [[ -z "${installDuo}" ]] && [[ "${installTOTP}" != true ]]; then
    # Prompt the user if they would like to install Duo MFA, default of no
 #   echo -e -n "${CYAN}MFA: Would you like to install Duo (configuration values must be set after install in /etc/guacamole/guacamole.properties)? (y/N): ${NC}"
 #   read PROMPT
 #   if [[ ${PROMPT} =~ ^[Yy]$ ]]; then
 #       installDuo=true
 #       installTOTP=false
 #   else
 #       installDuo=false
 #   fi
#fi

# We can't install TOTP and Duo at the same time...
#if [[ "${installTOTP}" = true ]] && [ "${installDuo}" = true ]; then
 #   echo -e "${RED}MFA: The script does not support installing TOTP and Duo at the same time.${NC}" 1>&2
 #   exit 1
#fi
#echo

if [[ -z ${installMySQL} ]]; then
    # Prompt the user to see if they would like to install MySQL, default of yes
    echo "${YELLOW} MySQL est requis pour l'installation, Si vous souhaitez utiliser un serveur Mysql Distant répondre 'n'"
    echo -e -n "${CYAN}Voulez-vous installer MySQL en local ? (O/n): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        installMySQL=false
    else
        installMySQL=true
    fi
fi

if [ "${installMySQL}" = false ]; then
    # We need to get additional values
    [ -z "${mysqlHost}" ] \
      && read -p "Entrez le hostname ou l'adresse ip du serveir MySQL Distant: " mysqlHost
    [ -z "${mysqlPort}" ] \
      && read -p "Entrez le port du serveur MySQL Distant [ex: 3306]: " mysqlPort
    [ -z "${guacDb}" ] \
      && read -p "Entrez le nom de la bas de donnée Guacamole [ex: guacamole_db]: " guacDb
    [ -z "${guacUser}" ] \
      && read -p "Entrez l'utilisateur de la base de donnée Guacamole [ex: guacamole_user]: " guacUser
fi

# Checking if mysql host given
if [ -z "${mysqlHost}" ]; then
    mysqlHost="localhost"
fi

# Checking if mysql port given
if [ -z "${mysqlPort}" ]; then
    mysqlPort="3306"
fi

# Checking if mysql user given
if [ -z "${guacUser}" ]; then
    guacUser="guacamole_user"
fi

# Checking if database name given
if [ -z "${guacDb}" ]; then
    guacDb="guacamole_db"
fi

if [ -z "${mysqlRootPwd}" ]; then
    # Get MySQL "Root" and "Guacamole User" password
    while true; do
        echo
        read -s -p "Entrez le mot de passe root ${mysqlHost}'s MySQL : " mysqlRootPwd
        echo
        read -s -p "Confirmer le mot de passe root ${mysqlHost}'s MySQL : " PROMPT2
        echo
        [ "${mysqlRootPwd}" = "${PROMPT2}" ] && break
        echo -e "${RED}Les mots de passe ne correspondent pas. Veuillez réessayer.${NC}" 1>&2
    done
else
    echo -e "${CYAN}Lecture des informations MySQL saisis${NC}"
fi
echo

if [ -z "${guacPwd}" ]; then
    while true; do
        echo -e "${CYAN}Un nouvel utilisateur MySQL va etre créé (${guacUser})${NC}"
        read -s -p "Entrez le mot de passe de l'utilisateur guacamole ${mysqlHost}'s MySQL: " guacPwd
        echo
        read -s -p "Confirmez le mot de passe de l'utilisateur guacamole ${mysqlHost}'s MySQL: " PROMPT2
        echo
        [ "${guacPwd}" = "${PROMPT2}" ] && break
        echo -e "${RED}Les mots de passe ne correspondent pas. Veuillez réessayer.${NC}" 1>&2
        echo
    done
else
    echo -e "${CYAN}Lecture des informations MySQL saisis${NC}"
fi
echo

if [ "${installMySQL}" = true ]; then
    # Seed MySQL install values
    debconf-set-selections <<< "mysql-server mysql-server/root_password password ${mysqlRootPwd}"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${mysqlRootPwd}"
fi

############
### LDAP ###
############
# On demande si on veut utiliser le LDAP
if [[ -z ${installLDAP} ]]; then
    echo -e -n "${CYAN}Voulez-vous utiliser la fonction LDAP Active Directory ? (O/n): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        installLDAP=false
    else
        installLDAP=true
    fi
fi

if [ "${installLDAP}" = true ]; then
    # We need to get additional values
    [ -z "${ldapHost}" ] \
      && read -p "Entrez le hostname ou l'adresse ip du serveur LDAP (ex : 'mondomaine.fr') : " ldapHost
    [ -z "${ldapPort}" ] \
      && read -p "Entrez le port du serveur LDAP [ex: 389]: " ldapPort
    [ -z "${ldapDC1}" ] \
      && read -p "Entrez le DC (domain component) de 1er niveau (ex 'mondomaine.fr' saisir 'domaine' : " ldapDC1
    [ -z "${ldapDC2}" ] \
      && read -p "Entrez le DC (domain component) de 2eme niveau (ex 'mondomaine.fr' saisir 'fr' : " ldapDC2
	[ -z "${ldapUserOu}" ] \
      && read -p "Entrez le nom de l'OU ou se trouve vos utilisateurs (ex : 'Utilisateurs') : " ldapUserOu
	[ -z "${ldapUserAttribute}" ] \
      && read -p "Entrez le l'atrribut utilisateur LDAP (Souvent : 'sAMAccountName') : " ldapUserAttribute
	[ -z "${ldapUserBind}" ] \
      && read -p "Entrez le login de l'utilisateur ayant les droits de lecture LDAP  : " ldapUserBind
	[ -z "${ldapUserBindOu}" ] \
      && read -p "Entrez le nom de l'OU ou se trouve l'utilisateur ayant les droits de lecture LDAP  : " ldapUserBindOu


	if [ -z "${ldapUserBindPassword}" ]; then
		while true; do
			echo
			read -s -p "Entrez le mot de passe de l'utilisateur ayant les droits de lecture LDAP  : " ldapUserBindPassword
			echo
			read -s -p "Confirmer le mot de passe : " PROMPT2
			echo
			[ "${ldapUserBindPassword}" = "${PROMPT2}" ] && break
			echo -e "${RED}Les mots de passe ne correspondent pas. Veuillez réessayer.${NC}" 1>&2
		done
	else
		echo -e "${CYAN}Lecture des informations LDAP saisis${NC}"
	fi
fi
echo




# Different version of Ubuntu/Linux Mint and Debian have different package names...
source /etc/os-release
if [[ "${NAME}" == "Ubuntu" ]] || [[ "${NAME}" == "Linux Mint" ]]; then
    # Ubuntu > 18.04 does not include universe repo by default
    # Add the "Universe" repo, don't update
    add-apt-repository -y universe
    # Set package names depending on version
    JPEGTURBO="libjpeg-turbo8-dev"
    if [[ "${VERSION_ID}" == "16.04" ]]; then
        LIBPNG="libpng12-dev"
    else
        LIBPNG="libpng-dev"
    fi
    if [ "${installMySQL}" = true ]; then
        MYSQL="mysql-server mysql-client mysql-common"
    # Checking if (any kind of) mysql-client or compatible command installed. This is useful for existing mariadb server
    elif [ -x "$( command -v mysql )" ]; then
        MYSQL=""
    else
        MYSQL="mysql-client"
    fi
elif [[ "${NAME}" == *"Debian"* ]] || [[ "${NAME}" == *"Raspbian GNU/Linux"* ]] || [[ "${NAME}" == *"Kali GNU/Linux"* ]] || [[ "${NAME}" == "LMDE" ]]; then
    JPEGTURBO="libjpeg62-turbo-dev"
    if [[ "${PRETTY_NAME}" == *"stretch"* ]] || [[ "${PRETTY_NAME}" == *"buster"* ]] || [[ "${PRETTY_NAME}" == *"Kali GNU/Linux Rolling"* ]] || [[ "${NAME}" == "LMDE" ]]; then
        LIBPNG="libpng-dev"
    else
        LIBPNG="libpng12-dev"
    fi
    if [ "${installMySQL}" = true ]; then
        MYSQL="default-mysql-server default-mysql-client mysql-common"
    # Checking if (any kind of) mysql-client or compatible command installed. This is useful for existing mariadb server
    elif [ -x "$( command -v mysql )" ]; then
        MYSQL=""
    else
        MYSQL="default-mysql-client"
    fi
	sudo bash -c 'echo "deb http://deb.debian.org/debian buster-backports main" >> /etc/apt/sources.list.d/backports.list'
	sudo apt update
	sudo apt -y -t buster-backports install freerdp2-dev libpulse-dev
else
    echo "Unsupported distribution - Debian, Kali, Raspbian, Linux Mint or Ubuntu only"
    exit 1
fi

# Update apt so we can search apt-cache for newest Tomcat version supported & libmariadb-java/libmysql-java
echo -e "${CYAN}Mise à jour de apt...${NC}"
apt-get -qq update

# Check if libmariadb-java/libmysql-java is available
# Debian 10 >= ~ https://packages.debian.org/search?keywords=libmariadb-java
if [[ $( apt-cache show libmariadb-java 2> /dev/null | wc -l ) -gt 0 ]]; then
    # When something higher than 1.1.0 is out ~ https://issues.apache.org/jira/browse/GUACAMOLE-852
    #echo -e "${CYAN}Found libmariadb-java package...${NC}"
    #LIBJAVA="libmariadb-java"
    # For v1.1.0 and lower
    echo -e "${YELLOW}Found libmariadb-java package (known issues). Will download libmysql-java ${MCJVER} and install manually${NC}"
    LIBJAVA=""
# Debian 9 <= ~ https://packages.debian.org/search?keywords=libmysql-java
elif [[ $( apt-cache show libmysql-java 2> /dev/null | wc -l ) -gt 0 ]]; then
    echo -e "${CYAN}Found libmysql-java package...${NC}"
    LIBJAVA="libmysql-java"
else
    echo -e "${YELLOW}lib{mariadb,mysql}-java not available. Will download mysql-connector-java-${MCJVER}.tar.gz and install manually${NC}"
    LIBJAVA=""
fi

# tomcat9 is the latest version
# tomcat8.0 is end of life, but tomcat8.5 is current
# fallback is tomcat7
if [[ $( apt-cache show tomcat9 2> /dev/null | egrep "Version: 9" | wc -l ) -gt 0 ]]; then
    echo -e "${CYAN}Paquets tomcat9 trouvé...${NC}"
    TOMCAT="tomcat9"
elif [[ $( apt-cache show tomcat8 2> /dev/null | egrep "Version: 8.[5-9]" | wc -l ) -gt 0 ]]; then
    echo -e "${CYAN}Paquets tomcat8.5+ trouvé...${NC}"
    TOMCAT="tomcat8"
elif [[ $( apt-cache show tomcat7 2> /dev/null | egrep "Version: 7" | wc -l ) -gt 0 ]]; then
    echo -e "${CYAN}Paquets tomcat7 trouvé...${NC}"
    TOMCAT="tomcat7"
else
    echo -e "${RED}Echec. Impossible de trouver les paquets Tomcat${NC}" 1>&2
    exit 1
fi

# Uncomment to manually force a Tomcat version
#TOMCAT=""

# Install features
echo -e "${CYAN}Installation des paquets. Ceci peut prendre quelques minutes...${NC}"

# Don't prompt during install
export DEBIAN_FRONTEND=noninteractive

# Required packages
apt-get -y install build-essential libcairo2-dev ${JPEGTURBO} ${LIBPNG} libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev \
libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev libpulse-dev libssl-dev \
libvorbis-dev libwebp-dev libwebsockets-dev freerdp2-x11 libtool-bin ghostscript dpkg-dev wget crudini libc-bin \
${MYSQL} ${LIBJAVA} ${TOMCAT} &>> ${LOG}

# If apt fails to run completely the rest of this isn't going to work...
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec. Voir ${LOG}${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
echo

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${GUACVERSION}"
echo -e "${CYAN}Téléchargement des fichiers...${NC}"

# Download Guacamole Server
wget --no-check-certificate -q --show-progress -O guacamole-server-${GUACVERSION}.tar.gz ${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec de téléchargement de guacamole-server-${GUACVERSION}.tar.gz" 1>&2
    echo -e "${SERVER}/source/guacamole-server-${GUACVERSION}.tar.gz${NC}"
    exit 1
else
    # Extract Guacamole Files
    tar -xzf guacamole-server-${GUACVERSION}.tar.gz
fi
echo -e "${GREEN}guacamole-server-${GUACVERSION}.tar.gz Téléchargé${NC}"

# Download Guacamole Client
wget --no-check-certificate -q --show-progress -O guacamole-${GUACVERSION}.war ${SERVER}/binary/guacamole-${GUACVERSION}.war
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec de téléchargement de guacamole-${GUACVERSION}.war" 1>&2
    echo -e "${SERVER}/binary/guacamole-${GUACVERSION}.war${NC}"
    exit 1
fi
echo -e "${GREEN}guacamole-${GUACVERSION}.war Téléchargé${NC}"

# Download Guacamole authentication extensions (Database)
wget --no-check-certificate -q --show-progress -O guacamole-auth-jdbc-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec de téléchargement de guacamole-auth-jdbc-${GUACVERSION}.tar.gz" 1>&2
    echo -e "${SERVER}/binary/guacamole-auth-jdbc-${GUACVERSION}.tar.gz"
    exit 1
else
    tar -xzf guacamole-auth-jdbc-${GUACVERSION}.tar.gz
fi
echo -e "${GREEN}guacamole-auth-jdbc-${GUACVERSION}.tar.gz Téléchargé${NC}"

# Download Guacamole authentication extensions (LDAP)
if [ "${installLDAP}" = true ]; then
	wget --no-check-certificate -q --show-progress -O guacamole-auth-ldap-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-ldap-${GUACVERSION}.tar.gz
	if [ $? -ne 0 ]; then
		echo -e "${RED}Echec de téléchargement de guacamole-auth-ldap-${GUACVERSION}.tar.gz" 1>&2
		echo -e "${SERVER}/binary/guacamole-auth-ldap-${GUACVERSION}.tar.gz"
		exit 1
	else
		tar -xzf guacamole-auth-ldap-${GUACVERSION}.tar.gz
	fi
	echo -e "${GREEN}guacamole-auth-ldap-${GUACVERSION}.tar.gz Téléchargé${NC}"
fi

# Download Guacamole authentication extensions

# TOTP
if [ "${installTOTP}" = true ]; then
    wget --no-check-certificate  -q --show-progress -O guacamole-auth-totp-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Echec de téléchargement de guacamole-auth-totp-${GUACVERSION}.tar.gz" 1>&2
        echo -e "${SERVER}/binary/guacamole-auth-totp-${GUACVERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-totp-${GUACVERSION}.tar.gz
    fi
    echo -e "${GREEN}guacamole-auth-totp-${GUACVERSION}.tar.gz Téléchargé${NC}"
fi

# Duo
if [ "${installDuo}" = true ]; then
    wget  --no-check-certificate -q --show-progress -O guacamole-auth-duo-${GUACVERSION}.tar.gz ${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Echec de téléchargement de guacamole-auth-duo-${GUACVERSION}.tar.gz" 1>&2
        echo -e "${SERVER}/binary/guacamole-auth-duo-${GUACVERSION}.tar.gz"
        exit 1
    else
        tar -xzf guacamole-auth-duo-${GUACVERSION}.tar.gz
    fi
    echo -e "${GREEN}guacamole-auth-duo-${GUACVERSION}.tar.gz Téléchargé${NC}"
fi

# Deal with missing MySQL Connector/J
if [[ -z $LIBJAVA ]]; then
    # Download MySQL Connector/J
    wget --no-check-certificate -q --show-progress -O mysql-connector-java-${MCJVER}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVER}.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}Echec de téléchargement de mysql-connector-java-${MCJVER}.tar.gz" 1>&2
        echo -e "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVER}.tar.gz${NC}"
        exit 1
    else
        tar -xzf mysql-connector-java-${MCJVER}.tar.gz
    fi
    echo -e "${GREEN}mysql-connector-java-${MCJVER}.tar.gz Téléchargé${NC}"
else
    echo -e "${YELLOW}Skipping manually installing MySQL Connector/J${NC}"
fi
echo -e "${GREEN}Téléchargement terminé.${NC}"
echo

# Make directories
rm -rf /etc/guacamole/lib/
rm -rf /etc/guacamole/extensions/
mkdir -p /etc/guacamole/lib/
mkdir -p /etc/guacamole/extensions/

# Install guacd (Guacamole-server)
cd guacamole-server-${GUACVERSION}/

echo -e "${CYAN}Compilation de Guacamole-Server avec GCC $( gcc --version | head -n1 | grep -oP '\)\K.*' | awk '{print $1}' ) ${NC}"

echo -e "${CYAN}Configuration de Guacamole-Server. Ceci peut prendre quelques minutes...${NC}"
./configure --with-systemd-dir=/etc/systemd/system  &>> ${LOG}
if [ $? -ne 0 ]; then
    echo "Echec de configuration de guacamole-server"
    echo "Trying again with --enable-allow-freerdp-snapshots"
    ./configure --with-systemd-dir=/etc/systemd/system --enable-allow-freerdp-snapshots
    if [ $? -ne 0 ]; then
        echo "Failed to configure guacamole-server - again"
        exit
    fi
else
    echo -e "${GREEN}OK${NC}"
fi

echo -e "${CYAN}Lancement de Make sur Guacamole-Server. Ceci peut prendre quelques minutes...${NC}"
make &>> ${LOG}
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec. Voir ${LOG}${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

echo -e "${CYAN}Lancement de  Make Install sur Guacamole-Server...${NC}"
make install &>> ${LOG}
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec. Voir ${LOG}${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
sudo ldconfig
echo

# Move files to correct locations (guacamole-client & Guacamole authentication extensions)
cd ..
mv -f guacamole-${GUACVERSION}.war /etc/guacamole/guacamole.war
mv -f guacamole-auth-jdbc-${GUACVERSION}/mysql/guacamole-auth-jdbc-mysql-${GUACVERSION}.jar /etc/guacamole/extensions/
if [ "${installLDAP}" = true ]; then
	mv -f guacamole-auth-ldap-${GUACVERSION}/guacamole-auth-ldap-${GUACVERSION}.jar /etc/guacamole/extensions/
fi

# Create Symbolic Link for Tomcat
ln -sf /etc/guacamole/guacamole.war /var/lib/${TOMCAT}/webapps/

# Deal with MySQL Connector/J
if [[ -z $LIBJAVA ]]; then
    echo -e "${CYAN}Deplacement mysql-connector-java-${MCJVER}.jar (/etc/guacamole/lib/mysql-connector-java.jar)...${NC}"
    mv -f mysql-connector-java-${MCJVER}/mysql-connector-java-${MCJVER}.jar /etc/guacamole/lib/mysql-connector-java.jar
	echo -e "${GREEN}OK${NC}"
elif [ -e /usr/share/java/mariadb-java-client.jar ]; then
    echo -e "${CYAN}Liaison mariadb-java-client.jar  (/etc/guacamole/lib/mariadb-java-client.jar)...${NC}"
    ln -sf /usr/share/java/mariadb-java-client.jar /etc/guacamole/lib/mariadb-java-client.jar
	echo -e "${GREEN}OK${NC}"
elif [ -e /usr/share/java/mysql-connector-java.jar ]; then
    echo -e "${CYAN}Liaison mysql-connector-java.jar  (/etc/guacamole/lib/mysql-connector-java.jar)...${NC}"
    ln -sf /usr/share/java/mysql-connector-java.jar /etc/guacamole/lib/mysql-connector-java.jar
	echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}Impossible de trouver *.jar file${NC}" 1>&2
    exit 1
fi
echo

# Move TOTP Files
if [ "${installTOTP}" = true ]; then
    echo -e "${CYAN}Deplacement guacamole-auth-totp-${GUACVERSION}.jar (/etc/guacamole/extensions/)...${NC}"
    mv -f guacamole-auth-totp-${GUACVERSION}/guacamole-auth-totp-${GUACVERSION}.jar /etc/guacamole/extensions/
    echo
fi

# Move Duo Files
if [ "${installDuo}" = true ]; then
    echo -e "${CYAN}Deplacement guacamole-auth-duo-${GUACVERSION}.jar (/etc/guacamole/extensions/)...${NC}"
    mv -f guacamole-auth-duo-${GUACVERSION}/guacamole-auth-duo-${GUACVERSION}.jar /etc/guacamole/extensions/
    echo
fi

# Configure guacamole.properties
rm -f /etc/guacamole/guacamole.properties
touch /etc/guacamole/guacamole.properties
echo "mysql-hostname: ${mysqlHost}" >> /etc/guacamole/guacamole.properties
echo "mysql-port: ${mysqlPort}" >> /etc/guacamole/guacamole.properties
echo "mysql-database: ${guacDb}" >> /etc/guacamole/guacamole.properties
echo "mysql-username: ${guacUser}" >> /etc/guacamole/guacamole.properties
echo "mysql-password: ${guacPwd}" >> /etc/guacamole/guacamole.properties

# Output Duo configuration settings but comment them out for now
if [ "${installDuo}" = true ]; then
    echo "# duo-api-hostname: " >> /etc/guacamole/guacamole.properties
    echo "# duo-integration-key: " >> /etc/guacamole/guacamole.properties
    echo "# duo-secret-key: " >> /etc/guacamole/guacamole.properties
    echo "# duo-application-key: " >> /etc/guacamole/guacamole.properties
    echo -e "${YELLOW}Duo is installed, it will need to be configured via guacamole.properties${NC}"
fi

# On inject la conf du LDAP
if [ "${installLDAP}" = true ]; then
    echo "# LDAP properties" >> /etc/guacamole/guacamole.properties
    echo "ldap-hostname: ${ldapHost}" >> /etc/guacamole/guacamole.properties
    echo "ldap-port: ${ldapPort}" >> /etc/guacamole/guacamole.properties
    echo "ldap-user-base-dn: OU=${ldapUserOu},DC=${ldapDC1},DC=${ldapDC2}" >> /etc/guacamole/guacamole.properties
	echo "ldap-username-attribute: ${ldapUserAttribute}" >> /etc/guacamole/guacamole.properties
	echo "ldap-search-bind-dn: CN=${ldapUserBind},OU=${ldapUserBindOu},DC=${ldapDC1},DC=${ldapDC2}" >> /etc/guacamole/guacamole.properties
	echo "ldap-search-bind-password:${ldapUserBindPassword}" >> /etc/guacamole/guacamole.properties
	echo "ldap-encryption-method: none" >> /etc/guacamole/guacamole.properties
	
    echo -e "${YELLOW}LDAP installé et configuré, Vérifiez au besoin dans /etc/guacamole/guacamole.properties${NC}"
	echo -e "${GREEN}OK${NC}"
fi


# Restart Tomcat
echo -e "${CYAN}Redémarrage du service Tomcat & Activation au démarrage...${NC}"
sudo service ${TOMCAT} restart
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
# Start at boot
systemctl enable ${TOMCAT}
echo

# Set MySQL password
export MYSQL_PWD=${mysqlRootPwd}

if [ "${installMySQL}" = true ]; then

    # Restart MySQL service
    echo -e "${CYAN}Redémarrage du service MySQL & Acticvation au démarrage...${NC}"
    sudo service mysql restart
    if [ $? -ne 0 ]; then
        echo -e "${RED}Echec${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}OK${NC}"
    fi
    # Start at boot
    systemctl enable mysql
    echo

    # Default locations of MySQL config file
    for x in /etc/mysql/mariadb.conf.d/50-server.cnf \
             /etc/mysql/mysql.conf.d/mysqld.cnf \
             /etc/mysql/my.cnf \
             ; do
        # Check the path exists
        if [ -e "${x}" ]; then
            # Does it have the necessary section
            if grep -q '^\[mysqld\]$' "${x}"; then
                mysqlconfig="${x}"
                # no point keep checking!
                break
            fi
        fi
    done

    if [ -z "${mysqlconfig}" ]; then
        echo -e "${YELLOW}Couldn't detect MySQL config file - you may need to manually enter timezone settings${NC}"
    else
        # Is there already a value?
        if grep -q "^default_time_zone[[:space:]]?=" "${mysqlconfig}"; then
            echo -e "${YELLOW}Fuseau horaire déjà défini dans ${mysqlconfig}${NC}"
        else
            timezone="$( cat /etc/timezone )"
            if [ -z "${timezone}" ]; then
                echo -e "${YELLOW}mpossible de trouver le fuseau horaire, Utilisation de UTC${NC}"
                timezone="UTC"
            fi
            echo -e "${YELLOW}Fuseau horaire définit comme ${timezone}${NC}"
            # Fix for https://issues.apache.org/jira/browse/GUACAMOLE-760
            mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | mysql -u root -D mysql -h ${mysqlHost} -P ${mysqlPort}
            crudini --set ${mysqlconfig} mysqld default_time_zone "${timezone}"
            # Restart to apply
            sudo service mysql restart
            echo
        fi
    fi
fi

# Create ${guacDb} and grant ${guacUser} permissions to it

# SQL code
guacUserHost="localhost"

if [[ "${mysqlHost}" != "localhost" ]]; then
    guacUserHost="%"
    echo -e "${YELLOW}L'utilisateur MySQL Guacamole est configuré pour accepter la connexion de n'importe quel hôte, veuillez le modifier pour des raisons de sécurité.${NC}"
fi

# Check for ${guacDb} already being there
echo -e "${CYAN}Check si la base de donnée MySQL (${guacDb}) existe déjà${NC}"
SQLCODE="
SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${guacDb}';"

# Execute SQL code
MYSQL_RESULT=$( echo ${SQLCODE} | mysql -u root -D information_schema -h ${mysqlHost} -P ${mysqlPort} )
if [[ $MYSQL_RESULT != "" ]]; then
    echo -e "${RED}Il semble qu'il existe déjà une base de données MySQL (${guacDb}) sur ${mysqlHost}${NC}" 1>&2
    echo -e "${RED}Essayer:    mysql -e 'DROP DATABASE ${guacDb}'${NC}" 1>&2
    #exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Check for ${guacUser} already being there
echo -e "${CYAN}Check si l'utilisateur MySQL (${guacUser}) existe déjà${NC}"
SQLCODE="
SELECT COUNT(*) FROM mysql.user WHERE user = '${guacUser}';"

# Execute SQL code
MYSQL_RESULT=$( echo ${SQLCODE} | mysql -u root -D mysql -h ${mysqlHost} -P ${mysqlPort} | grep '0' )
if [[ $MYSQL_RESULT == "" ]]; then
    echo -e "${RED}Il semble qu'il y ait déjà un utilisateur MySQL (${guacUser}) sur ${mysqlHost}${NC}" 1>&2
    echo -e "${RED}Essayez:    mysql -e \"DROP USER '${guacUser}'@'${guacUserHost}'; FLUSH PRIVILEGES;\"${NC}" 1>&2
    #exit 1
else
    echo -e "${GREEN}OK${NC}"
fi

# Create database & user, then set permissions
SQLCODE="
DROP DATABASE IF EXISTS ${guacDb};
CREATE DATABASE IF NOT EXISTS ${guacDb};
CREATE USER IF NOT EXISTS '${guacUser}'@'${guacUserHost}' IDENTIFIED BY \"${guacPwd}\";
GRANT SELECT,INSERT,UPDATE,DELETE ON ${guacDb}.* TO '${guacUser}'@'${guacUserHost}';
FLUSH PRIVILEGES;"

# Execute SQL code
echo ${SQLCODE} | mysql -u root -D mysql -h ${mysqlHost} -P ${mysqlPort}

# Add Guacamole schema to newly created database
echo -e "${CYAN}Ajout des tables dans la base de donnée...${NC}"
cat guacamole-auth-jdbc-${GUACVERSION}/mysql/schema/*.sql | mysql -u root -D ${guacDb} -h ${mysqlHost} -P ${mysqlPort}
if [ $? -ne 0 ]; then
    echo -e "${RED}Echec${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}OK${NC}"
fi
echo

# Correctif pour faire fonctionner le RDP
# On lance le service guacd en root et non en daemon
echo -e "${CYAN}Patch du service Guacd en root pour fonctionnement RDP...${NC}"
sed -i 's/User=daemon/User=root/' /etc/systemd/system/guacd.service
systemctl daemon-reload
echo


# Ensure guacd is started
echo -e "${CYAN}Démarrage du service Guacd & Activation au démarrage...${NC}"
sudo service guacd stop 2>/dev/null
sudo service guacd start
systemctl enable guacd
echo

# Deal with ufw and/or iptables

# Check if ufw is a valid command
if [ -x "$( command -v ufw )" ]; then
    # Check if ufw is active (active|inactive)
    if [[ $(ufw status | grep inactive | wc -l) -eq 0 ]]; then
        # Check if 8080 is not already allowed
        if [[ $(ufw status | grep "8080/tcp" | grep "ALLOW" | grep "Anywhere" | wc -l) -eq 0 ]]; then
            # ufw is running, but 8080 is not allowed, add it
            sudo ufw allow 8080/tcp comment 'allow tomcat'
        fi
    fi
fi    

# It's possible that someone is just running pure iptables...

# Check if iptables is a valid running service
systemctl is-active --quiet iptables
if [ $? -eq 0 ]; then
    # Check if 8080 is not already allowed
    # FYI: This same command matches the rule added with ufw (-A ufw-user-input -p tcp -m tcp --dport 22 -j ACCEPT)
    if [[ $(iptables --list-rules | grep -- "-p tcp" | grep -- "--dport 8080" | grep -- "-j ACCEPT" | wc -l) -eq 0 ]]; then
        # ALlow it
        sudo iptables -A INPUT -p tcp --dport 8080 --jump ACCEPT
    fi
fi

# I think there is another service called firewalld that some people could be running instead
# Unless someone opens an issue about it or submits a pull request, I'm going to ignore it for now




#################
### FAIL2BAN ###
#################
# On demande si on veut utiliser le Fail2Ban
if [[ -z ${installFail2ban} ]]; then
    echo -e -n "${CYAN}Voulez-vous installer la fonction Fail2Ban (Anti-BruteForce) ? (O/n): ${NC}"
    read PROMPT
    if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
        installFail2ban=false
    else
        installFail2ban=true
    fi
fi

# Installation et configuration de fail2ban
if [ "${installFail2ban}" = true ]; then
	[ -z "${fail2banbanTime}" ] \
	&& read -p "Entrez le nombre de minutes ou l'ip sera bannie (Ex : 15m ): " fail2banbanTime
	[ -z "${fail2banmaxRetry}" ] \
	&& read -p "Entrez le nombre maximum autorisé de tentative de mot de passe (Ex : 5) : " fail2banmaxRetry
	[ -z "${fail2banfindTime}" ] \
	&& read -p "Entrez le laps de temps autorisé pour faire le maximum de tentative (Ex : 10m , Si 5 essais en < 10min = Ban) : " fail2banfindTime
	
	echo -e "${CYAN}Installation du paquet Fail2ban...${NC}"

	apt-get -y install fail2ban &>> ${LOG}
 
	if [ $? -ne 0 ]; then
		echo -e "${RED}Echec. Voir ${LOG}${NC}" 1>&2
		#exit 1 -- useless
	else
		echo -e "${GREEN}OK${NC}"
	fi
	echo
	
	echo -e "${CYAN}Configuration de Fail2ban pour Guacamole...${NC}"
		
	cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

	#sed -i "s/bantime.*=.*/bantime = ${fail2banbanTime}/" /etc/fail2ban/jail.local
	#sed -i "s/findtime.*=.*/findtime = ${fail2banfindTime}/" /etc/fail2ban/jail.local
	#sed -i "s/maxretry.*=.*/maxretry = ${fail2banmaxRetry}/" /etc/fail2ban/jail.local
	#sed -i ':a;N;$!ba;s/\[guacamole\]\n\nport/[guacamole]\nenabled = true\nport/g' /etc/fail2ban/jail.local
	echo "[guacamole]" >> /etc/fail2ban/jail.d/guacamole.conf
    echo "enabled = true" >> /etc/fail2ban/jail.d/guacamole.conf
    echo "bantime=${fail2banbanTime}" >> /etc/fail2ban/jail.d/guacamole.conf
    echo "findtime=${fail2banfindTime}" >> /etc/fail2ban/jail.d/guacamole.conf
	echo "maxretry=${fail2banmaxRetry}" >> /etc/fail2ban/jail.d/guacamole.conf
	
	
	sed -i 's/failregex = /failregex = \\bAuthentication attempt from \\[<HOST>.*\\] for user ".*" failed\\.$/g' /etc/fail2ban/filter.d/guacamole.conf
		
			
	echo
	echo -e "${CYAN}Ajout de regle, pour empêcher les ip locales d'etre ban ${NC}"

	if [[ -z ${fail2bancustomIp} ]]; then
			echo -e -n "${CYAN}Voulez-vous configurer une plage d'ip perso ? (O/n): ${NC}"
			read PROMPT
			if [[ ${PROMPT} =~ ^[Nn]$ ]]; then
				fail2bancustomIp=false
			else
				fail2bancustomIp=true
			fi
	fi
	if [ "${fail2bancustomIp}" = true ]; then
		[ -z "${fail2banNotBanIpRange}" ] \
		&& read -p "Entrez la plage d'ip a exclure (Ex : 172.16.0.0/16): " fail2banNotBanIpRange
		echo "ignoreip=127.0.0.1/8 192.168.0.0/16 ${fail2banNotBanIpRange}" >> /etc/fail2ban/jail.d/guacamole.conf
		#sed -i "s|#ignoreip = 127.0.0.1/8 ::1|ignoreip = 127.0.0.1/8 ::1 192.168.0.0/16 ${fail2banNotBanIpRange}|" /etc/fail2ban/jail.local
	fi
	
	echo
	echo -e "${CYAN}Démarrage du service Fail2ban & Activation au démarrage...${NC}"
	sudo service fail2ban restart
	systemctl enable fail2ban
fi
echo


# Cleanup
echo -e "${CYAN}Nettoyage des fichiers d'installation...${NC}"
rm -rf guacamole-*
rm -rf mysql-connector-java-*
unset MYSQL_PWD
echo




# Done
echo -e "${CYAN} ****************************************************"
echo -e "${CYAN} ********** \o/ Installation Terminée  \o/ **********"
echo -e "${CYAN} ****************************************************\n"
echo -e "${CYAN}- Site : http://$HOSTNAME:8080/guacamole/\n"
echo -e "${CYAN}- Identifiants \033[1m(username/password): guacadmin/guacadmin\n"
echo -e "${RED} \033[1m /!\ ***N'OUBLIEZ PAS DE CHANGER LE MOT DE PASSE !!! *** /!\.${NC}"  1>&2
echo -e "${RED} \033[1m /!\ ***N'OUBLIEZ PAS DE CHANGER LE MOT DE PASSE !!! *** /!\.${NC}"  1>&2
echo -e "${RED} \033[1m /!\ ***N'OUBLIEZ PAS DE CHANGER LE MOT DE PASSE !!! *** /!\.${NC}"  1>&2
echo
echo -e "${CYAN} ****************************************************"
echo -e "${CYAN} ****************************************************"
echo -e "${CYAN} ****************************************************"
