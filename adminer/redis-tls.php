<?php

namespace Adminer;

require_once __DIR__ . '/drivers/redis.php';

/** Open the connection of the Redis driver over TLS
*
* An On-Demand Key-Value Store accepts encrypted connections only and its
* certificate does not match the host name of the service. The driver connects
* with fsockopen(), which negotiates TLS for a tls:// address but takes no
* stream context, ignores the default one and therefore always verifies the
* host name.
*
* The driver calls the function unqualified from the Adminer namespace, where
* this definition takes precedence over the one in the global namespace, so the
* connection is opened with stream_socket_client() and the certificate of
* AdminerDeploio::connectSsl() instead. redis.php is the only caller of
* fsockopen() in Adminer.
*
* @param int $errno
* @param string $errstr
* @return resource|false
* @link https://www.php.net/manual/en/language.namespaces.fallback.php
*/
function fsockopen($hostname, $port = -1, &$errno = null, &$errstr = null, $timeout = null) {
	$ssl = adminer()->connectSsl();
	if (!$ssl) {
		return \fsockopen($hostname, $port, $errno, $errstr, $timeout); // a server which is not referenced keeps the behaviour of the driver
	}

	$options = array(
		// The certificate of an On-Demand service does not match its host
		// name, so the chain is verified and the host name is not, the same
		// way PostgreSQL is connected with sslmode=verify-ca.
		'verify_peer' => ($ssl['ca'] != ''),
		'verify_peer_name' => false,
	);
	if ($ssl['ca'] != '') {
		$options['cafile'] = $ssl['ca'];
	}

	// host_port() keeps a transport in the host name and strips the brackets of an IPv6 address
	$address = (strpos($hostname, '://') !== false ? '' : 'tls://')
		. (strpos($hostname, ':') !== false ? "[$hostname]" : $hostname)
		. ":$port"
	;
	// a failed handshake is reported as warnings only, of which the first names the reason
	$warnings = array();
	set_error_handler(function ($severity, $message) use (&$warnings) {
		$warnings[] = preg_replace('~^stream_socket_client\(\): ~', '', $message);
		return true;
	});
	$fp = stream_socket_client(
		$address, $errno, $errstr, $timeout, STREAM_CLIENT_CONNECT,
		stream_context_create(array('ssl' => $options))
	);
	restore_error_handler();

	if (!$fp && $errstr == '') {
		$errstr = (string) idx($warnings, 0, '');
	}
	return $fp;
}
