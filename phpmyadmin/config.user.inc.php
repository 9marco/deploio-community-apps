<?php
/**
 * Dynamic phpMyAdmin server configuration for Deploio service references.
 */

$deploioServices = (static function (): array {
    $identifiers = ['MYSQL', 'MYSQLDB'];
    $keys = ['FQDN', 'PORT', 'USER', 'PASSWORD', 'CA_CERT', 'CA_FILE'];
    usort($keys, static fn(string $a, string $b): int => strlen($b) <=> strlen($a));

    $services = [];

    foreach ($identifiers as $identifier) {
        $prefix = 'NINE_' . $identifier . '_';

        foreach (getenv() as $variable => $value) {
            if (!str_starts_with($variable, $prefix)) {
                continue;
            }

            foreach ($keys as $key) {
                $suffix = '_' . $key;
                if (!str_ends_with($variable, $suffix)) {
                    continue;
                }

                $name = substr($variable, strlen($prefix), -strlen($suffix));
                if ($name !== '') {
                    $slug = strtolower(strtr($identifier . '_' . $name, '_', '-'));
                    $services[$slug]['reference'] = $name;
                    $services[$slug][$key] = $value;
                }

                break;
            }
        }
    }

    $services = array_filter($services, static fn(array $s): bool => !empty($s['FQDN']));
    ksort($services);

    return $services;
})();

if ($deploioServices !== []) {
    // Clear default upstream server placeholder
    $cfg['Servers'] = [];

    $i = 0;
    foreach ($deploioServices as $service) {
        $i++;

        $label = strtolower(strtr($service['reference'], '_', '-'));
        $project = getenv('DEPLOIO_PROJECT_NAME');

        $cfg['Servers'][$i]['verbose'] = $project ? $project . ' / ' . $label : $label;
        $cfg['Servers'][$i]['host'] = $service['FQDN'];
        $cfg['Servers'][$i]['port'] = $service['PORT'] ?? '3306';
        $cfg['Servers'][$i]['compress'] = false;
        $cfg['Servers'][$i]['AllowNoPassword'] = false;

        $cfg['Servers'][$i]['auth_type'] = 'config';
        $cfg['Servers'][$i]['user'] = $service['USER'] ?? '';
        $cfg['Servers'][$i]['password'] = $service['PASSWORD'] ?? '';

        if (!empty($service['CA_FILE'])) {
            $cfg['Servers'][$i]['ssl'] = true;
            $cfg['Servers'][$i]['ssl_ca'] = $service['CA_FILE'];
            $cfg['Servers'][$i]['ssl_verify'] = true;
        }
    }
}

$cfg['TempDir'] = '/tmp';
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
