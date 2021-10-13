mkdir -p /usr/local/sbin/internetMonitor
\cp internetMonitor.sh /usr/local/sbin/internetMonitor/
\cp internetMonitor.service /etc/systemd/system/
systemctl daemon-reload 
systemctl enable internetMonitor
systemctl restart internetMonitor
systemctl status internetMonitor
