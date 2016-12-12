var express   = require('express');
var app       = express();
var httpProxy = require('http-proxy');
var http      = require('http');
var dns 	  = require ('dns');
var apiProxy  = httpProxy.createProxyServer();

var configuredUrl = process.env.DCOS_NEO4J_DNS_ENTRY || "core-neo4j.marathon.containerip.dcos.thisdcos.directory";
var dnsUrl = "http://" + configuredUrl + ":7474"
var user = process.env.DCOS_NEO4J_USER
var pass = process.env.DCOS_NEO4J_PASS
var auth = (user != undefined && pass != undefined) ? (user + ":" + pass) : "";

var options = {
	host: configuredUrl,
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
					throw "Not able to parse chunk";
				}
			});
		});
		var query = {
			statements:
			[
				{
					statement: 'CALL dbms.cluster.overview() yield addresses, role where role = "LEADER" return head([a IN addresses where a starts with "http:"]) as http'
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
		management: concreteServer + "/db/manage/",
		data: concreteServer + "/db/data/"
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

app.listen(7474);
