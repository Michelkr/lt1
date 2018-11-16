library:
 cmd.script:
   - source: salt://metricbeat.sh

filebeat:
  pkg.installed


/etc/metricbeat/metricbeat.yml:
  file:
    - managed
    - source: salt://metricbeat.yml

restart_filebeat:
  service.running:
    - name: filebeat
    - enable: true
    - reload: True
