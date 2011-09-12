class puppet::client {

  package { "facter":
    ensure  => present,
    require => Package["lsb-release"],
  }

  package { "puppet":
    ensure  => present,
    require => Package["facter"],
  }

  package { "lsb-release":
    ensure => present,
    name   => $operatingsystem ? {
      Debian => "lsb-release",
      Ubuntu => "lsb-release",
      Redhat => "redhat-lsb",
      fedora => "redhat-lsb",
      CentOS => "redhat-lsb",
    },
  }

  service { "puppet":
    ensure    => stopped,
    enable    => false,
    hasstatus => false,
    pattern   => $operatingsystem ? {
      Debian => "ruby /usr/sbin/puppetd -w 0",
      Ubuntu => "ruby /usr/sbin/puppetd -w 0",
      RedHat => "/usr/bin/ruby /usr/sbin/puppetd$",
      CentOS => "/usr/bin/ruby /usr/sbin/puppetd$",
    }
  }

  user { "puppet":
    ensure => present,
    require => Package["puppet"],
  }

  if ( ! $puppet_environment ) {
    $puppet_environment = "production"
  }

  if (versioncmp($puppetversion, 2) > 0) {
    $agent = "agent"
  } else {
    $agent = "puppetd"
  }

  puppet::config {
    "main/ssldir":          value => "/var/lib/puppet/ssl";
    "$agent/server":        value => $puppet_server;
    "$agent/reportserver":  value => $puppet_reportserver;
    "$agent/report":        value => "true";
    "$agent/configtimeout": value => "3600";
    "$agent/pluginsync":    value => "true";
    "$agent/plugindest":    value => "/var/lib/puppet/lib";
    "$agent/libdir":        value => "/var/lib/puppet/lib";
    "$agent/pidfile":       value => "/var/run/puppet/puppetd.pid";
    "$agent/environment":   value => $puppet_environment;
    "$agent/diff_args":     value => "-u";
  }

  file{"/usr/local/bin/launch-puppet":
    ensure => present,
    mode => 755,
    content => template("puppet/launch-puppet.erb"),
  }

  # Run puppetd with cron instead of having it hanging around and eating so
  # much memory.
  cron { "puppetd":
    ensure  => present,
    command => "/usr/local/bin/launch-puppet",
    user    => 'root',
    environment => "MAILTO=root",
    minute  => $puppet_run_minutes ? {
      ""      => ip_to_cron(2),
      "*"     => undef,
      default => $puppet_run_minutes,
    },
    hour    => $puppet_run_hours ? {
      ""      => undef,
      "*"     => undef,
      default => $puppet_run_hours,
    },
    require => File["/usr/local/bin/launch-puppet"],
  }         
}
