# == Definition: curator::job
#
# Schedules an elasticsearch curator maintainence job
#
#
define curator::job (
  $command,
  $ensure                = 'present',
  $sub_command           = 'indices',
  $bin_file              = $::curator::bin_file,

  # ES config
  $host                  = $::curator::host,
  $port                  = $::curator::port,

  # Auth options
  $use_ssl               = $::curator::use_ssl,
  $ssl_validate          = $::curator::ssl_validate,
  $ssl_certificate_path  = $::curator::ssl_certificate_path,
  $http_auth             = $::curator::http_auth,
  $user                  = $::curator::user,
  $password              = $::curator::password,

  # Options for all indexes
  $prefix                = 'logstash-',
  $suffix                = undef,
  $regex                 = undef,
  $exclude               = undef,
  $index                 = undef,
  $snapshot              = undef,
  $older_than            = undef,
  $newer_than            = undef,
  $time_unit             = 'days',
  $timestring            = '\%Y.\%m.\%d',
  $master_only           = false,
  $logfile               = $::curator::logfile,
  $log_level             = $::curator::log_level,
  $logformat             = $::curator::logformat,

  # Alias options
  $alias_name            = undef,
  $remove                = false,

  # Allocation options
  $rule                  = undef,

  # Delete options
  $disk_space            = undef,

  # Optimize options
  $delay                 = 0,
  $max_num_segments      = 2,
  $request_timeout       = 218600,

  # Replicas options
  $count                 = 2,

  # Snapshot options
  $repository            = undef,

  # Schedule type
  $schedule_type         = $::curator::schedule_type,

  # Cron params
  $cron_weekday          = '*',
  $cron_hour             = 1,
  $cron_minute           = 10,

  # Systemd timer params
  $systemd_timer         = '*-*-* 01:10:00',

) {

  include ::curator

  # Validations and set index options

  if $prefix {
    $_prefix = "--prefix '${prefix}'"
  } else {
    $_prefix = undef
  }

  if $suffix {
    $_suffix = "--suffix '${suffix}'"
  } else {
    $_suffix = undef
  }

  if $regex {
    $_regex = "--regex '${regex}'"
  } else {
    $_regex = undef
  }

  $_timestring = "--timestring '${timestring}'"

  if !member(['days', 'hours', 'weeks', 'months'], $time_unit) {
    fail("curator::job[${name}] time_unit must be hours, days, weeks, or months")
  } else {
    $_time_unit = "--time-unit ${time_unit}"
  }

  if !is_integer($port) {
    fail("curator::job[${name}] port must be integer")
  }

  if $exclude {
    if !is_string($exclude) and !is_array($exclude) {
      fail("curator::job[${name}]: exclude must be an array or array of strings")
    } else {
      $_exclude = inline_template("<%= Array(@exclude).map { |element| \"--exclude \'#{element}\'\" }.join(' ') %>")
    }
  } else {
    $_exclude = undef
  }

  if $index {
    if !is_string($index) and !is_array($index) {
      fail("curator::job[${name}]: index must be an array or array of strings")
    } else {
      $_index = inline_template("<%= Array(@index).map { |element| \"--index #{element}\" }.join(' ') %>")
    }
  } else {
    $_index = undef
  }

  if $snapshot {
    if !is_string($snapshot) and !is_array($snapshot) {
      fail("curator::job[${name}]: snapshot must be an array or array of strings")
    } else {
      $_snapshot = inline_template("<%= Array(@snapshot).map { |element| \"--snapshot #{element}\" }.join(' ') %>")
    }
  } else {
    $_snapshot = undef
  }

  validate_bool($master_only)

  if $older_than {
    if !is_integer($older_than) {
      fail("curator::job[${name}] older_than must be an integer")
    } else {
      $_older_than = "--older-than ${older_than}"
    }
  } else {
    $_older_than = undef
  }

  if $newer_than {
    if !is_integer($newer_than) {
      fail("curator::job[${name}] newer_than must be an integer")
    } else {
      $_newer_than = "--newer-than ${newer_than}"
    }
  } else {
    $_newer_than = undef
  }

  if !member(['default', 'logstash'], $logformat) {
    fail("curator::job[${name}] logformat must be default or logstash")
  }

  if !member(['INFO', 'WARN'], $log_level) {
    fail("curator::job[${name}] log_level must be INFO or WARN")
  }

  case $command {
    'alias': {
      # alias validations
      if !$alias_name {
        fail("curator::job[${name}] alias_name is required with alias")
      }
      if $remove {
        validate_bool($remove)
        $_remove = '--remove'
      } else {
        $_remove = undef
      }

      $exec = join(delete_undef_values(["alias --name ${alias_name}", $_remove, 'indices']), ' ')
    }
    'allocation': {
      # allocation validations
      if !$rule {
        fail("curator::job[${name}] rule is required with allocation")
      }

      $exec = "allocation --rule ${rule} indices"
    }
    'close', 'open': {
      $exec = "${command} indices"
    }
    'delete': {
      # delete validations
      if !member(['indices', 'snapshots'], $sub_command) {
        fail("curator::job[${name}] delete command supports indices and snapshots sub_command")
      }
      if $disk_space {
        if !is_integer($disk_space) {
          fail("curator::job[${name}] disk_space must be an integer")
        }
        $_ds = "--disk-space ${disk_space}"
      } else {
        $_ds = undef
      }
      if $repository {
        $_repo = "--repository ${repository}"
      } else {
        $_repo = undef
      }

      $exec = join(delete_undef_values(['delete', $_ds, $sub_command, $_repo]), ' ')
    }
    'optimize': {
      # optimize validations
      if !is_integer($delay) {
        fail("curator::job[${name}] delay must be an integer")
      } else {
        $_delay = " --delay ${delay}"
      }

      if !is_integer($max_num_segments) {
        fail("curator::job[${name}] max_num_segments must be an integer")
      } else {
        $_segments = " --max_num_segments ${max_num_segments}"
      }

      if !is_integer($request_timeout) {
        fail("curator::job[${name}] request_timeout must be an integer")
      } else {
        $_timeout = " --request_timeout ${request_timeout}"
      }

      $exec = "optimize${_delay}${_segments}${_timeout} indices"
    }
    'replicas': {
      if !is_integer($count) {
        fail("curator::job[${name}] count must be an integer")
      }

      $exec = "replicas --count ${count} indices"
    }
    'snapshot': {
      if !$repository {
        fail("curator::job[${name}] repository is required")
      }

      $exec = "snapshot --repository ${repository} indices"
    }
    default: {
      fail("curator::job[${name}]: command must be alias, allocation, close, delete, open, optimize, replicas, or snapshot")
    }
  }

  $mo_string = $master_only ? {
    true    => '--master-only',
    default => undef,
  }

  $ssl_string = $use_ssl ? {
    true    => '--use_ssl',
    default => undef,
  }

  if $use_ssl {
    if $ssl_validate {
      $ssl_no_validate = undef
    } else {
      $ssl_no_validate = '--ssl-no-validate'
    }
    if $ssl_certificate_path != undef {
      $ssl_certificate = "--certificate ${ssl_certificate_path}"
    } else {
      $ssl_certificate = undef
    }
  } else {
    $ssl_certificate = undef
    $ssl_no_validate = undef
  }

  if $http_auth {
    validate_string($user)
    validate_string($password)
    $auth_string = "--http_auth ${user}:${password}"
  } else {
    $auth_string = undef
  }

  $index_options = join(delete_undef_values([$_prefix, $_suffix, $_regex, $_time_unit, $_exclude, $_index, $_snapshot, $_older_than, $_newer_than, $_timestring]), ' ')
  $options = join(delete_undef_values([$mo_string, $ssl_string, $ssl_certificate, $ssl_no_validate, $auth_string]), ' ')

  validate_re($schedule_type, '^(cron|systemd)$')
  if $schedule_type == 'cron' {

    # Cron Configuration
    cron { "curator_${name}":
      ensure  => $ensure,
      command => "${bin_file} --logfile ${logfile} --loglevel ${log_level} --logformat ${logformat} ${options} --host ${host} --port ${port} ${exec} ${index_options} >/dev/null",
      hour    => $cron_hour,
      minute  => $cron_minute,
      weekday => $cron_weekday,
    }

  } elsif $schedule_type == 'systemd' {

    $curator_command = "${bin_file} --loglevel ${log_level} --logformat ${logformat} ${options} --host ${host} --port ${port} ${exec} ${index_options}"

    # Systemd Configuration
    file { "/lib/systemd/system/curator_${name}.service":
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('curator/systemd/curator.service.erb'),
      notify  => Exec["curator_${name}-daemon-reload"],
    }

    file { "/lib/systemd/system/curator_${name}.timer":
      ensure  => $ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('curator/systemd/curator.timer.erb'),
      notify  => Exec["curator_${name}-daemon-reload"],
    }

    exec { "curator_${name}-daemon-reload":
      command     => 'systemctl daemon-reload',
      path        => ['/usr/bin','/bin','/sbin'],
      refreshonly => true,
    }

    $service_ensure = $ensure ? {
      /present/ => 'running',
      /absent/  => 'stopped',
    }

    $service_enable = $ensure ? {
      /present/ => true,
      /absent/  => false
    }

    service { "curator_${name}.timer":
      ensure    => $service_ensure,
      enable    => $service_enable,
      subscribe => Exec["curator_${name}-daemon-reload"],
    }
  }
}
