#!/bin/bash

if [[ -z "${PASSWORD}" ]]; then
  export PASSWORD="5c301bb8-6c77-41a0-a606-4ba11bbab084"
fi
echo ${PASSWORD}

export PASSWORD_JSON="$(echo -n "$PASSWORD" | jq -Rc)"

if [[ -z "${ENCRYPT}" ]]; then
  export ENCRYPT="chacha20-ietf-poly1305"
fi

if [[ -z "${V2_Path}" ]]; then
  export V2_Path="s233"
fi
echo ${V2_Path}

if [[ -z "${QR_Path}" ]]; then
  export QR_Path="/getconfig"
fi
echo ${QR_Path}

case "$AppName" in
	*.*)
		export DOMAIN="$AppName"
		;;
	*)
		export DOMAIN="$AppName.herokuapp.com"
		;;
esac

bash /conf/shadowsocks-libev_config.json >  /etc/shadowsocks-libev/config.json
echo /etc/shadowsocks-libev/config.json
cat /etc/shadowsocks-libev/config.json

htpasswd -b -c /etc/nginx/pwd ${QR_User} ${QR_Pass}
rm -rf /var/cache
mkdir /var/cache
bash /conf/nginx_ss.conf > /etc/nginx/conf.d/ss.conf
echo /etc/nginx/conf.d/ss.conf
cat /etc/nginx/conf.d/ss.conf
sed -e '/http {/a\' -e "\tlog_format proxied '\$time_local\\\t\$request\\\t\$http_x_forwarded_for\
\\\t\$status\\\t\$request_time\\\t\$upstream_addr\\\t\$upstream_status\\\t\$upstream_cache_status\\\t\$upstream_response_time';" /etc/nginx/nginx.conf -i


if [ "$AppName" = "no" ]; then
  echo "Do not generate QR-code"
else
  [ ! -d /wwwroot/${QR_Path} ] && mkdir /wwwroot/${QR_Path}
  plugin=$(echo -n "v2ray;path=/${V2_Path};host=${DOMAIN};tls" | sed -e 's/\//%2F/g' -e 's/=/%3D/g' -e 's/;/%3B/g')
  ss="ss://$(echo -n ${ENCRYPT}:${PASSWORD} | base64 -w 0)@${DOMAIN}:443?plugin=${plugin}" 
  echo "<a href='${QR_Path}/access.txt'>access_log</a><br>" > /wwwroot/${QR_Path}/index.html
  echo "<a href='${QR_Path}/error.txt'>error_log</a><br><br>" >> /wwwroot/${QR_Path}/index.html
  echo "${ss}" | tr -d '\n' >> /wwwroot/${QR_Path}/index.html
  echo -n "<br><br><img src='${QR_Path}/qr.png'>" >> /wwwroot/${QR_Path}/index.html
  echo -n "${ss}" | qrencode -s 6 -o /wwwroot/${QR_Path}/qr.png
  echo -e "User-agent: * \nDisallow: /" > /wwwroot/${QR_Path}/robots.txt
fi

ss-server -c /etc/shadowsocks-libev/config.json &
rm -rf /etc/nginx/sites-enabled/default
nginx -g 'daemon off;'
