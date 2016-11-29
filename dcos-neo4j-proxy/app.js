var express  = require('express');
var app      = express();
var httpProxy = require('http-proxy');
var http = require('http');
var apiProxy = httpProxy.createProxyServer();

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
	var req = http.request(options, (res) => {
		res.on("data", (chunk) => {
			try {
				var obj = JSON.parse(chunk.toString());
				var url = obj.results[0].data[0].row[0];
				if (url.startsWith("http")) {
					concreteServer = chunk.toString();
				} else {
					throw "Not able to parse chunk";
				}
			} catch(e) {
			  	console.log("Do not got the correct answer for updating leader http url, got:")
			  	console.log(chunk.toString());
			}
		});
	});
	req.write('{"statements":[{"statement":"CALL dbms.cluster.overview() yield addresses, role where role = \"LEADER\" return head([a IN addresses where a starts with \"http:\"]) as http"}]}');
	req.end();
	setTimeout(updateUrl, 10000);
}

updateUrl();

console.log("initial leader http url: " + concreteServer);

app.all("/*", function(req, res) {
    apiProxy.web(req, res, {target: concreteServer});
});

app.listen(7474);
