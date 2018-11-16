library:
 cmd.script:
   - source: salt://filebeatconfigure.sh

filebeat:
  pkg.installed


/etc/filebeat/filebeat.yml:
  file:
    - managed
    - source: salt://filebeat.yml

restart_filebeat:
  service.running:
    - name: filebeat
    - enable: true
    - reload: True
