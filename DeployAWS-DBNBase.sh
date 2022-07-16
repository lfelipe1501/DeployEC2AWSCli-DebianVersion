#!/bin/bash

#
# Script to deploy EC2 server with basic config.
#
# @author   Luis Felipe <lfelipe1501@gmail.com>
# @website  https://www.lfsystems.com.co
# @version  1.0

#Color variables
W="\033[0m"
B='\033[0;34m'
R="\033[01;31m"
G="\033[01;32m"
OB="\033[44m"
OR='\033[101m'
OG='\033[42m'
UY='\033[4;33m'
UG='\033[4;32m'

echo ""
echo -e "==================================\n$OB EC2 AUTO DEPLOY$W \n=================================="
echo ""

echo "Please indicate the AMI ID..."
echo -e "++++++++++++++++++++++++++++++\n$OR If you do NOT indicate the AMI ID\n by default the script installs \n the official version of Ubuntu from AWS$W \n++++++++++++++++++++++++++++++"
read -p "$(echo -e "Enter the Debian-based AMI ID you wish to use$UY\notherwise leave this field blank $W(e.g.$R ami-052efd3df9dad4825$W): \n> ")" amid

echo ""
echo "Please indicate the Instance type..."
echo -e "++++++++++++++++++++++++++++++\n$OR If you do NOT indicate the INSTANCE TYPE\n by default the script installs \n the t2.micro instance of the free tier$W \n++++++++++++++++++++++++++++++"
read -p "$(echo -e "Enter the Instance type you wish to use$UY\notherwise leave this field blank $W(e.g.$R t2.micro$W): \n> ")" ectype

echo ""
echo "Please indicate the Disk space..."
echo -e "++++++++++++++++++++++++++++++\n$OR If you do NOT indicate the Disk space\n by default the script\n set 30GB space of the free tier$W \n++++++++++++++++++++++++++++++"
read -p "$(echo -e "Enter the Disk space you wish to use$UY\notherwise leave this field blank $W(e.g.$R 120$W): \n> ")" dskspa

echo ""
echo "Please indicate the New Name for user..."
read -p "$(echo -e "Full name of the new user that replaces ubuntu\n(e.g.$R felipe$W): \n> ")" newUSR

echo ""
echo "Please indicate the HOSTNAME for a server..."
read -p "$(echo -e "Full Hostname\n(e.g.$R server.lfsystems.io$W): \n> ")" hostname

echo ""
echo "Please indicate the SSH PORT for a server..."
read -p "$(echo -e "New port for SSH to increase security\n(e.g.$R 2211$W): \n> ")" sshprt

echo ""
echo "Please indicate the PEM KEY NAME for a server..."
read -p "$(echo -e "Specify the name of the key for the SSH connection\n(e.g.$R llave22$W): \n> ")" newUSRIFN

rnumber=$((RANDOM%995+1))
nametgServer=ServerUBNL"$rnumber"

##DEPLOY-TXT

cat > deploy.txt <<EOF
#!/bin/bash

hostnamectl set-hostname $hostname

export DEBIAN_FRONTEND=noninteractive

sed '/Port/s/^#//' -i /etc/ssh/sshd_config
sed -i 's/22/$sshprt/g' /etc/ssh/sshd_config

sed '/ListenAddress 0.0.0.0/s/^#//' -i /etc/ssh/sshd_config

sed '/MaxAuthTries/s/^#//' -i /etc/ssh/sshd_config
sed -i 's/MaxAuthTries 6/MaxAuthTries 2/g' /etc/ssh/sshd_config

sed '/ClientAliveInterval/s/^#//' -i /etc/ssh/sshd_config
sed -i 's/ClientAliveInterval 0/ClientAliveInterval 60/g' /etc/ssh/sshd_config

mkdir -p /root/.ssh
cat /home/ubuntu/.ssh/authorized_keys > /root/.ssh/authorized_keys

usermod -l $newUSR -d /home/$newUSR -m ubuntu && groupmod -n $newUSR ubuntu

ln -sf /usr/share/zoneinfo/America/Bogota /etc/localtime

apt update && apt dist-upgrade -y && apt install zip unzip lsof strace htop bash-completion ncdu git perl net-tools neofetch wget curl rsync nano build-essential -y

reboot
EOF

echo ""
echo -e "==================================\n$OB Deploy new Server...$W \n=================================="
echo -e "$G>> Deploying...$W please wait.....\n"

if [ -z "$amid" ]
then
	amid="ami-052efd3df9dad4825"
fi

if [ -z "$ectype" ]
then
	ectype="t2.micro"
fi

if [ -z "$dskspa" ]
then
	dskspa="30"
fi

aws ec2 create-security-group --group-name segr-nwServer-ec2-sg --description "Grupo de seguridad By FelipeScript" > /dev/null 2>&1

aws ec2 authorize-security-group-ingress --group-name segr-nwServer-ec2-sg --ip-permissions IpProtocol=tcp,FromPort=$sshprt,ToPort=$sshprt,IpRanges='[{CidrIp=0.0.0.0/0,Description="Puerto Seguro SSH"}]' > /dev/null 2>&1 && aws ec2 authorize-security-group-ingress --group-name segr-nwServer-ec2-sg --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="Puerto Acceso http"}]' > /dev/null 2>&1 && aws ec2 authorize-security-group-ingress --group-name segr-nwServer-ec2-sg --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="Puerto Acceso https"}]' > /dev/null 2>&1

aws ec2 create-key-pair --key-name $newUSRIFN --query 'KeyMaterial' --output text > $newUSRIFN.pem

chmod 600 $newUSRIFN.pem

ELIP=$(aws ec2 allocate-address | grep -oP '(?<="AllocationId": ")[^"]*')

aws ec2 create-tags --resources $ELIP --tags $TagIPSET1

getIP=$(aws ec2 describe-addresses --allocation-id $ELIP | grep -oP '(?<="PublicIp": ")[^"]*')

TagSET1="ResourceType=instance,Tags=[{Key=Name,Value="${nametgServer}"}]"
TagSET2="ResourceType=volume,Tags=[{Key=Name,Value=D"${nametgServer}"}]"
DskSET='[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":'${dskspa}"}}]"

aws ec2 run-instances --image-id ${amid} --count 1 --instance-type ${ectype} --key-name ${newUSRIFN} --security-groups segr-nwServer-ec2-sg --block-device-mapping ${DskSET} --tag-specifications ${TagSET1} ${TagSET2} --user-data file://deploy.txt > /dev/null 2>&1

TagNI1="Name=tag:Name,Values="${nametgServer}

EC2INST=$(aws ec2 describe-instances --filters $TagNI1  | grep -oP '(?<="InstanceId": ")[^"]*')

sleep 45

aws ec2 associate-address --instance-id $EC2INST --allocation-id $ELIP > /dev/null 2>&1

echo -e "$G>> All ready...$W the new SERVER is$B RUNNING$W\n"
echo -e "++++++++++++++++++++++++++++++\n$OB Normally the instance takes a few minutes to finish\n adjusting the data sent for updates and adjustments \n so it is recommended that you wait 1 \n to 2 minutes to start using your new server...$W\n++++++++++++++++++++++++++++++"
echo ""
echo "You can enter to SSH using:"
echo ""
echo -e "$OB>> ssh -p ${sshprt} -i ${newUSRIFN}.pem root@${getIP} $W"
echo "or"
echo -e "$OG>> ssh -p ${sshprt} -i ${newUSRIFN}.pem ${newUSR}@${getIP} $W"
echo ""
