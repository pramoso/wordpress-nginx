server {
	# Ports to listen on
	listen 80;
	listen [::]:80;

	# Server name to listen for
	server_name single-site-no-ssl.com;

	# Path to document root
	root /var/www/single-site-no-ssl.com/public;

	# File to be used as index
	index index.php index.html;

	# Overrides logs defined in nginx.conf, allows per site logs.
	access_log /var/www/single-site-no-ssl.com/logs/access.log;
	error_log /var/www/single-site-no-ssl.com/logs/error.log;

	# Default server block rules
	include global/server/defaults.conf;

	# Nginx redirect to HTTPS
	# Fix WordPress HTTPS issues when behind an Amazon Load Balancer
	# https://stackoverflow.com/a/46984243/6890699
	# https://docs.elastx.cloud/docs/virtuozzo-paas/guides/nginx_redirect_to_https/
	if ($http_x_forwarded_proto != 'https') {
        rewrite ^ https://$host$request_uri? permanent;
    }

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to /index.php.
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;

		# Nginx redirect to HTTPS
		# Fix WordPress HTTPS issues when behind an Amazon Load Balancer
		if ($http_x_forwarded_proto = 'https') {
                set $fe_https 'on';
		}

		include global/fastcgi-params-elb.conf;

		# Use the php pool defined in the upstream variable.
		# See global/php-pool.conf for definition.
		fastcgi_pass   $upstream;
	}
}

# Redirect www to non-www
server {
	listen 80;
	listen [::]:80;
	server_name www.single-site-no-ssl.com;

	return 301 $scheme://single-site-no-ssl.com$request_uri;
}