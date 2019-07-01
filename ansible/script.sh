#!/bin/bash
apt-get update -y
wget https://git.io/vpnsetup -O vpnsetup.sh && sudo \
VPN_IPSEC_PSK=$2 \
VPN_USER=$1 \
VPN_PASSWORD=$2 sh vpnsetup.sh

if ! grep -qs "VPN access" /etc/sysctl.conf; then
  conf_bk "/etc/sysctl.conf"
cat >> /etc/sysctl.conf <<EOF
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.ip_forward = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.lo.send_redirects = 0
net.ipv4.conf.$net_iface.send_redirects = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.lo.rp_filter = 0
net.ipv4.conf.$net_iface.rp_filter = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.core.wmem_max = 12582912
net.core.rmem_max = 12582912
net.ipv4.tcp_rmem = 10240 87380 12582912
net.ipv4.tcp_wmem = 10240 87380 12582912
EOF
fi


ipt_flag=0
IPT_FILE="/etc/iptables.rules"
if ! grep -qs "VPN access" "$IPT_FILE" \
  || ! iptables -t nat -C POSTROUTING -s "$L2TP_NET" -o "$net_iface"-j MASQUERADE 2>/dev/null \
  || ! iptables -t nat -C POSTROUTING -s "$XAUTH_NET" -o "$net_iface"-m policy --dir out --pol none -j MASQUERADE 2>/dev/null; then
  ipt_flag=1
fi

if [ "$ipt_flag" = "1" ]; then
  service fail2ban stop >/dev/null 2>&1
  iptables-save > "$IPT_FILE.old-$SYS_DT"
  iptables -I INPUT 1 -p udp --dport 1701 -m policy --dir in --pol none -j DROP
  iptables -I INPUT 2 -m conntrack --ctstate INVALID -j DROP
  iptables -I INPUT 3 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -I INPUT 4 -p udp -m multiport --dports 500,4500 -j ACCEPT
  iptables -I INPUT 5 -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT
  iptables -I INPUT 6 -p udp --dport 1701 -j DROP
  iptables -I FORWARD 1 -m conntrack --ctstate INVALID -j DROP
  iptables -I FORWARD 2 -i "$net_iface" -o ppp+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -I FORWARD 3 -i ppp+ -o "$net_iface" -j ACCEPT
  iptables -I FORWARD 4 -i ppp+ -o ppp+ -s "$L2TP_NET" -d "$L2TP_NET"-j ACCEPT
  iptables -I FORWARD 5 -i "$net_iface" -d "$XAUTH_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -I FORWARD 6 -s "$XAUTH_NET" -o "$net_iface" -j ACCEPT
  echo "Uncomment if you wish to disallow traffic between VPN clients themselves"
  echo "iptables -I FORWARD 2 -i ppp+ -o ppp+ -s  -d -j DROP"
  echo "iptables -I FORWARD 3 -s  -d  -j DROP"
  iptables -A FORWARD -j DROP
  iptables -t nat -I POSTROUTING -s "$XAUTH_NET" -o "$net_iface" -m policy --dir out --pol none -j MASQUERADE
  iptables -t nat -I POSTROUTING -s "$L2TP_NET" -o "$net_iface" -j MASQUERADE
  echo "# VPN access" > "$IPT_FILE"
  iptables-save >> "$IPT_FILE"

  IPT_FILE2="/etc/iptables/rules.v4"
  if [ -f "$IPT_FILE2" ]; then
    conf_bk "$IPT_FILE2"
    /bin/cp -f "$IPT_FILE" "$IPT_FILE2"
  fi
fi

mkdir -p /etc/network/if-pre-up.d
cat > /etc/network/if-pre-up.d/iptablesload <<'EOF'
#!/bin/bash
iptables-restore < /etc/iptables.rules
exit 0
EOF
for svc in fail2ban ipsec xl2tpd; do
  update-rc.d "$svc" enable >/dev/null 2>&1
  systemctl enable "$svc" 2>/dev/null
done
if ! grep -qs "VPN script" /etc/rc.local; then
  if [ -f /etc/rc.local ]; then
    conf_bk "/etc/rc.local"
    sed --follow-symlinks -i '/^exit 0/d' /etc/rc.local
  else
    echo '#!/bin/sh' > /etc/rc.local
  fi
cat >> /etc/rc.local <<'EOF'


service ipsec start
service xl2tpd start
echo 1 > /proc/sys/net/ipv4/ip_forward
exit 0
EOF
  if grep -qs raspbian /etc/os-release; then
    sed --follow-symlinks -i '/VPN access/a sleep 15' /etc/rc.local
  fi
fi

sysctl -e -q -p
chmod +x /etc/rc.local /etc/network/if-pre-up.d/iptablesload
chmod 600 /etc/ipsec.secrets* /etc/ppp/chap-secrets*
/etc/ipsec.d/passwd*
iptables-restore < "$IPT_FILE"
service fail2ban restart 2>/dev/null
service ipsec restart 2>/dev/null
service xl2tpd restart 2>/dev/null


apt-get install pptpd -y
echo "localip 10.0.0.1" >> /etc/pptpd.conf
echo "remoteip 10.0.0.100-200" >> /etc/pptpd.conf
echo "$1 pptpd $2 *" >> /etc/ppp/chap-secrets
echo "ms-dns 8.8.8.8" >> /etc/ppp/pptpd-options
echo "ms-dns 8.8.4.4" >> /etc/ppp/pptpd-options
service pptpd restart
sudo systemctl enable pptpd


echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE && iptables-save