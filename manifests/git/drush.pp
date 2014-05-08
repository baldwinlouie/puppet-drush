class drush::git::drush (
  $git_branch = '',
  $git_tag    = '',
  $git_repo   = 'https://github.com/drush-ops/drush.git',
  $update     = false
  ) inherits drush::params {

  include php::params

  Exec { path => ['/bin', '/usr/bin', '/usr/local/bin', '/usr/share'], }

  if !defined(Package['git']) and !defined(Package['git-core']) {
    package { 'git':
      ensure => present,
      before => Drush::Git[$git_repo]
    }
  }

  if !defined(Package[$php::params::module_prefix]) {
    package { $php::params::module_prefix:
      ensure => present
    }
  }

  if ! defined(Class['composer']) {
    class { 'composer':
      target_dir      => '/usr/local/bin',
      composer_file   => 'composer',
      download_method => 'curl',
      logoutput       => false,
      tmp_path        => '/tmp',
      php_package     => "${php::params::module_prefix}cli",
      curl_package    => 'curl',
      suhosin_enabled => false,
    }
  }

  drush::git { $git_repo :
    path       => '/usr/share',
    git_branch => $git_branch,
    git_tag    => $git_tag,
    update     => $update,
  }

  exec {'setup drush' :
    environment => ["COMPOSER_HOME=/root"],
    command     => '/usr/local/bin/composer install',
    cwd         => '/usr/share/drush',
    require     => [
      Class['composer'],
      Drush::Git[$git_repo],
    ],
    notify      => File['symlink drush'],
  }

  file {'symlink drush':
    ensure  => link,
    path    => '/usr/bin/drush',
    target  => '/usr/share/drush/drush',
    require => Exec['setup drush'],
    notify  => Exec['first drush run'],
  }

  exec {'Make Composer globally executable' :
    command => 'mv composer.phar /usr/local/bin/composer',
    require => Class['composer'],
    before  => Exec['Install Drush dependencies'],
  }

  exec {'Install Drush dependencies' :
    command => 'composer install',
    cwd     => '/usr/share/drush',
  }

  # Needed to download a Pear library
  exec {'first drush run':
    command     => 'drush cache-clear drush',
    refreshonly => true,
    require     => [
      File['symlink drush'],
      Class['composer'],
      Exec['Install Drush dependencies'],
    ],
  }

}
