FAIL2BAN_FILES :=

dummy:
	echo "Please specify a target" && false

/usr/bin/ufw:
	pacman -Syu --needed --noconfirm ufw
	ufw default deny
	ufw allow ssh
	systemctl enable --now ufw
	yes | ufw enable

/usr/bin/fail2ban-client: /usr/bin/ufw
	pacman -Syu --needed --noconfirm fail2ban

FAIL2BAN_FILES := /etc/fail2ban/action.d/ufw.conf /etc/fail2ban/jail.local /etc/fail2ban/jail.d/ssh.conf

/etc/fail2ban/action.d/ufw.conf: configs/fail2ban/ufw.conf /usr/bin/fail2ban-client
/etc/fail2ban/jail.local: configs/fail2ban/jail.local /usr/bin/fail2ban-client
/etc/fail2ban/jail.d/ssh.conf: configs/fail2ban/ssh.conf /usr/bin/fail2ban-client

$(FAIL2BAN_FILES):
	@mkdir -p $(@D)
	cp $< $@

all: $(FAIL2BAN_FILES)
	systemctl enable --now fail2ban
	sed -i -E 's/#?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
	systemctl reload sshd
