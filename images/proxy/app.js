var express   = require('express');
var app       = express();
var httpProxy = require('http-proxy');
var tcpProxy  = require('tcp-proxy');
var http      = require('http');
var dns       = require ('dns');
var apiProxy  = httpProxy.createProxyServer();
var net       = require('net')

var configuredUrl = process.env.DCOS_NEO4J_DNS_ENTRY || "core-neo4j.marathon.containerip.dcos.thisdcos.directory";
var dnsUrl = "http://" + configuredUrl + ":7474"
var user = process.env.DCOS_NEO4J_USER
var pass = process.env.DCOS_NEO4J_PASS
var auth = (user != undefined && pass != undefined) ? (user + ":" + pass) : "";

var options = {
	host: "core-neo4j.marathon.containerip.dcos.thisdcos.directory",
	path: "/db/data/transaction/commit",
	method: "POST",
	port: 7474,
	headers: {
		"Content-Type": "application/json",
		"Accept": "application/json"
	},
	auth: auth
};
var concreteServer = dnsUrl;
var concreteBolt = {
  target: {
    host: "core-neo4j.marathon.containerip.dcos.thisdcos.directory",
    port: 7687
  }
}

function updateUrl() {
	try {
		var req = http.request(options, (res) => {
			res.on("data", (chunk) => {
				console.log("cron response: " + chunk.toString());
				var obj = JSON.parse(chunk.toString());
				var url = obj.results[0].data[0].row[0];
				if (url.startsWith("http")) {
					console.log("updating proxy url to : " + url);
					concreteServer = url;
				} else {
					throw "Not able to parse chunk for http";
				}

				var url2 = obj.results[0].data[0].row[1];
				if (url2.startsWith("bolt")) {
					var targetUrl = url2.substring(url2.lastIndexOf("/") + 1, url2.lastIndexOf(":"));
					console.log("updating bolt url to : " + targetUrl);
					concreteBolt = {
						target: {
							host: targetUrl,
							port: 7687
						}
					}
				} else {
					throw "Not able to parse chunk for bolt";
				}
			});
		});
		var query = {
			statements:
			[
				{
					statement: 'CALL dbms.cluster.overview() yield addresses, role where role = "LEADER" return head([a IN addresses where a starts with "http:"]) as http, head([a IN addresses where a starts with "bolt:"]) as bolt'
				}
			]
		};
		req.write(JSON.stringify(query));
		req.end();
	} catch(e) {
		console.log("Unable to perform cron request to update leader url: " + e);
	}
	setTimeout(updateUrl, 25000);
}

setTimeout(updateUrl, 25000);

console.log("initial leader http url: " + concreteServer);

app.all("/", function(req, res) {
	var response = {
		management: req.protocol + "http://" + req.hostname + ":7474/db/manage/",
		data: req.protocol + "://" + req.hostname + ":7474/db/data/",
		bolt: "bolt://" + req.hostname + ":7687"
	};
	res.send(JSON.stringify(response));
});

app.all("/*", function(req, res) {
	dns.resolve4(configuredUrl, function(err, addresses) {
		if (err) {
			console.log("Could not proxy the following request to the host (" + concreteServer + "): " + err);
		} else {
			apiProxy.web(req, res, {target: concreteServer});
		}
	});
});

var server = net.createServer(requestHandler);

var proxy = tcpProxy(concreteBolt);
proxy.on('error', server.emit.bind(server, 'error'));

function requestHandler(socket) {
  proxy.proxy(socket, concreteBolt);
}

console.log("Starting http server...")
app.listen(7474); 
console.log("Starting tcp server...")
server.listen(7687);
