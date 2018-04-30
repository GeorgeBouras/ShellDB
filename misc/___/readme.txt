some commands we used during the development


	firewall-cmd --zone=public --permanent --add-port=7000/tcp
	firewall-cmd --reload
	firewall-cmd --list-all

	setsebool httpd_can_network_connect=1
	semanage port -a -t http_port_t -p tcp 7000

lighthttpd

	/opt/shelldb/bin/lighttpd -tt -f /opt/shelldb/config/webserver.conf -m /opt/shelldb/lib		# test
	/opt/shelldb/bin/lighttpd -D  -f /opt/shelldb/config/webserver.conf -m /opt/shelldb/lib		# start foreground
	/opt/shelldb/bin/lighttpd     -f /opt/shelldb/config/webserver.conf -m /opt/shelldb/lib		# start background
	/usr/bin/kill -s INT $(/usr/bin/cat /opt/shelldb/bin/run/webserver.pid)						# stop
	
generic info routes

	curl http://localhost:7000/info/about
	curl http://localhost:7000/info/enviroment
	curl http://localhost:7000/info/license

insert

	curl -X POST -H "Content-Type: application/json" --data '{"db" : "db*"}'  http://localhost:7000/db/list
	curl -X POST -H "Content-Type: application/json" --data '{"db":"SomeDB","mode":"replace","data":{"2000":{"key":"hello"}}}' http://localhost:7000/insert

