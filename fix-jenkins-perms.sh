chown -R jenkins:jenkins /etc/jenkins/certs/
chmod 640 /etc/jenkins/certs/jenkins.p12
systemctl restart jenkins
sleep 10
systemctl status jenkins --no-pager | tail -5
