#!/bin/bash
#Debian Stable fully automatic installation by HTTP Repos and response file via local HTTP.
name="$1"
vcpus="$2"
ram="$3"
storage="$4"
silent="$5"
bridge="virbr0"
bridgeip4="192.168.122.1"
country="fr"

url_debian_mirror="http://ftp.debian.org/debian/dists/stable/main/installer-amd64/"

curl -V >/dev/null 2>&1 || { echo >&2 "Please install curl"; exit 2; }

debian_mirror=$url_debian_mirror

autoconsole=""
#autoconsole="--noautoconsole"
url_configuration="http://${bridgeip4}/conf/debian-${name}.cfg"

usage () {
echo "Usage : $0 vm_name nb_vcpus amout_ram amount_storage"
}

check_guest_name () {
if [ -z "${name}" ]; then
echo "Debian Stable fully automatic installation by HTTP Repos and response file via local HTTP."
usage
echo "Please provide one distribution debian and one guest name: exit"
exit
fi
if grep -qw ${name} <<< $(virsh list --all --name)  ; then
usage
echo "Please provide a defined guest name that is not in use : exit"
exit
fi
if [ "${silent}" = "--silent" ] ; then
  autoconsole="--noautoconsole"
fi
}

check_apache () {
apt-get -y install apache2 curl
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
systemctl enable httpd
systemctl start httpd
mkdir -p /var/www/html/conf
echo "this is ok" > /var/www/html/conf/ok
local check_value="this is ok"
local check_remote=$(curl -s http://127.0.0.1/conf/ok)
if [ "$check_remote"="$check_value" ] ; then
 echo "Apache is working"
else
 echo "Apache is not working"
 exit
fi
}

launch_guest () {
if ! grep -q 'vmx\|svm' /proc/cpuinfo ; then echo "Please enable virtualization instructions" ; exit 1 ; fi
{ grep -q 'vmx\|svm' /proc/cpuinfo ; [ $? == 0 ]; } || { echo "Please enable virtualization instructions" ; exit 1 ;  }
[ `grep -c 'vmx\|svm' /proc/cpuinfo` == 0 ] && { echo "Please enable virtualization instructions" ; exit 1 ;  }
virt-install -h >/dev/null 2>&1 || { echo >&2 "Please install libvirt"; exit 2; }
virt-install \
--virt-type kvm \
--name=$name \
--disk path=/kvm/disk/$name.img,size=$storage,format=qcow2 \
--ram=$ram \
--vcpus=$vcpus \
--os-variant debian10   \
--os-type linux \
--network bridge=$bridge \
--graphics none \
--noreboot \
--console pty,target_type=serial \
--location $mirror \
-x "auto=true hostname=$name domain=$config text console=ttyS0 $autoconsole"
}

debian_response_file () {
touch /var/www/html/conf/debian-${name}.cfg
cat << EOF > /var/www/html/conf/debian-${name}.cfg
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select be
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string unassigned-hostname
d-i netcfg/get_domain string unassigned-domain
d-i netcfg/wireless_wep string
d-i mirror/country string manual
d-i mirror/http/hostname string ftp.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i passwd/make-user boolean false
d-i passwd/root-password password testtest
d-i passwd/root-password-again password testtest
d-i clock-setup/utc boolean true
d-i time/zone string Europe/Paris
d-i clock-setup/ntp boolean true
d-i partman-auto/method string lvm
d-i partman-auto-lvm/guided_size string max
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server vim
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev  string /dev/vda
d-i finish-install/keep-consoles boolean true
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string in-target sed -i 's/PermitRootLogin\ without-password/PermitRootLogin\ yes/' /etc/ssh/sshd_config ; in-target wget https://gist.githubusercontent.com/goffinet/f515fb4c87f510d74165780cec78d62c/raw/db89976e8c5028ce5502e272e49c3ed65bbaba8e/ubuntu-grub-console.sh ; in-target chmod +x ubuntu-grub-console.sh && sh ubuntu-grub-console.sh ; in-target shutdown -h now
EOF
}

configure_installation () {
  mirror=$debian_mirror
  os="debian10"
  config="url=$url_configuration"
  debian_response_file
}

check_guest_name
check_apache
configure_installation
launch_guest
