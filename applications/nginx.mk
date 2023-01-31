/usr/bin/nginx:
	pacman -Syu nginx
	systemctl enable --now nginx

/etc/nginx/nginx.conf: configs/nginx/nginx.conf /usr/bin/nginx
	@mkdir -p $(@D)
	cp $< $@
