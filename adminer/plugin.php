<?php

require_once __DIR__ . '/../plugins/login-servers.php';
require_once __DIR__ . '/../plugins/drivers/elastic.php';
require_once __DIR__ . '/../plugins/deploio-redis-tls.php'; // loads drivers/redis.php and connects it over TLS

/** Connect to the On-Demand services referenced by a Deplo.io application
* @link https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services
*/
class AdminerDeploio extends Adminer\Plugin {
	/** Service types injected by Deplo.io; the driver of MySQL is called 'server'
	* @var array<string, array{system: string, driver: string, scheme: string, port: int}>
	*/
	private const KINDS = array(
		'MYSQL' => array('system' => 'MySQL', 'driver' => 'server', 'scheme' => '', 'port' => 3306),
		'MYSQLDB' => array('system' => 'MySQL', 'driver' => 'server', 'scheme' => '', 'port' => 3306),
		'PG' => array('system' => 'PostgreSQL', 'driver' => 'pgsql', 'scheme' => '', 'port' => 5432),
		'PGDB' => array('system' => 'PostgreSQL', 'driver' => 'pgsql', 'scheme' => '', 'port' => 5432),
		// OpenSearch injects no port and is reachable over HTTPS only
		'OS' => array('system' => 'OpenSearch', 'driver' => 'elastic', 'scheme' => 'https://', 'port' => 443),
		'KVS' => array('system' => 'Key-Value Store', 'driver' => 'redis', 'scheme' => '', 'port' => 6379),
	);

	/** Injected keys; CA_FILE is written by entrypoint.sh from CA_CERT */
	private const KEYS = array('FQDN', 'PORT', 'USER', 'PASSWORD', 'DSN', 'CA_FILE');

	/** @var array<string, string[]> connection parameters keyed by the label in the login form */
	private $services;

	/** @var ?AdminerLoginServers renders the list of services, null without any */
	private $servers = null;

	function __construct() {
		$this->services = $this->discover();
		if (!$this->services) {
			return; // every hook below falls through to Adminer, which asks for a server
		}

		$servers = array();
		foreach ($this->services as $label => $service) {
			$servers[$label] = array('server' => $service['server'], 'driver' => $service['driver']);
		}
		$this->servers = new AdminerLoginServers($servers);
	}

	/** Connection parameters of the referenced services
	* @return array<string, string[]>
	*/
	private function discover(): array {
		$pattern = '~^NINE_(' . implode('|', array_keys(self::KINDS)) . ')_(.+)_(' . implode('|', self::KEYS) . ')$~';
		$variables = array();
		foreach (getenv() as $variable => $value) {
			if (preg_match($pattern, $variable, $match)) {
				$variables[$match[1]][$match[2]][$match[3]] = $value;
			}
		}

		$services = array();
		foreach (self::KINDS as $identifier => $kind) {
			foreach (($variables[$identifier] ?? array()) as $name => $service) {
				if (($service['FQDN'] ?? '') === '') {
					continue; // a reference without a host name cannot be connected to
				}
				$services[$this->label($kind, $name)] = $this->service($kind, $service);
			}
		}

		ksort($services);
		return $services;
	}

	/** Name of a service in the login form and the breadcrumb
	* @param string[] $kind
	*/
	private function label(array $kind, string $name): string {
		$reference = strtolower(strtr($name, '_', '-'));
		$project = getenv('DEPLOIO_PROJECT_NAME');
		// the system tells two references of the same name apart and replaces
		// the driver of the login form, which is hidden below
		return ($project ? "$project / $reference" : $reference) . ' (' . $kind['system'] . ')';
	}

	/** Connection parameters of one service
	* @param string[] $kind
	* @param string[] $variables
	* @return string[]
	*/
	private function service(array $kind, array $variables): array {
		$port = (($variables['PORT'] ?? '') !== '' ? $variables['PORT'] : $kind['port']);

		return array(
			'driver' => $kind['driver'],
			'server' => $kind['scheme'] . $variables['FQDN'] . ":$port",
			'username' => ($variables['USER'] ?? ''),
			'password' => ($variables['PASSWORD'] ?? ''),
			'database' => $this->defaultDatabase($kind, $variables),
			'ca' => ($variables['CA_FILE'] ?? ''),
		);
	}

	/** Database to connect to
	*
	* PostgreSQL needs one already when connecting, so fall back to the user
	* name, which is the database name of an Economy service. MySQL, OpenSearch
	* and the Key-Value Store select the database after connecting.
	* @param string[] $kind
	* @param string[] $variables
	*/
	private function defaultDatabase(array $kind, array $variables): string {
		$path = ltrim((string) parse_url(($variables['DSN'] ?? ''), PHP_URL_PATH), '/');
		if ($path !== '') {
			return rawurldecode($path);
		}

		return ($kind['driver'] == 'pgsql' ? ($variables['USER'] ?? '') : '');
	}

	/** Service the request connects to
	* @return ?string[]
	*/
	private function selected(): ?array {
		return ($this->services[Adminer\SERVER] ?? null);
	}

	function credentials() {
		$service = $this->selected();
		if (!$service) {
			return null;
		}
		return array($service['server'], $service['username'], $service['password']);
	}

	function login($login, $password) {
		if (!$this->services) {
			return null;
		}
		// the credentials come from the service reference, so the form asks for
		// none; false rejects a server which is not referenced
		return (bool) $this->selected();
	}

	function connectSsl() {
		$service = $this->selected();
		if (!$service) {
			return null;
		}

		$ca = $service['ca'];
		if ($ca != '' && $service['driver'] == 'pgsql') {
			putenv("PGSSLROOTCERT=$ca"); // the driver passes only sslmode, libpq reads the certificate from the environment
		}

		return array(
			'ca' => $ca,
			'cert' => '',
			'key' => '',
			// The certificate of an On-Demand service does not match its host
			// name. mysqli and the Elasticsearch driver take both the
			// certificate and the host name check from this single flag, so
			// those connections are encrypted but not verified. PostgreSQL
			// verifies the chain through sslmode below.
			'verify' => false,
			'mode' => ($ca != '' ? 'verify-ca' : 'require'),
		);
	}

	function database() {
		$service = ($this->selected() ?: array('database' => ''));
		// an empty DB is the list of databases, which is reached through the one below
		return (Adminer\DB == '' && $service['database'] != '' ? $service['database'] : null);
	}

	function loginFormField($name, $heading, $value) {
		if (!$this->services) {
			return null;
		}
		if ($name == 'server') {
			return $this->servers->loginFormField($name, $heading, $value)
				// the connection details come from the service reference; the
				// fields are still posted so that Adminer starts a session
				. '<input type="hidden" name="auth[username]" value="">'
				. '<input type="hidden" name="auth[password]" value="">'
				. '<input type="hidden" name="auth[db]" value="">'
			;
		}
		return (in_array($name, array('driver', 'username', 'password', 'db'), true) ? '' : null);
	}
}

return new AdminerDeploio();
