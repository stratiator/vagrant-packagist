execute "apt-get" do
  command "apt-get update"
end

%w{
  make
  acl
  vim
  git-core
  subversion
  mercurial
  nginx
  php5-dev
  php5-mysql
  php5-cli
  php5-fpm
  php5-intl
  php5-curl
  php5-xdebug
  php-apc
  php-pear
  mysql-server
  redis-server
  libhiredis-dev
  tomcat6
  solr-common
  curl
}.each do |pkg|
  package pkg do
    action [:install, :upgrade]
  end
end

# nginx
template "/etc/nginx/sites-available/packagist" do
  mode 0644
  source "packagist.conf.erb"
end

bash "nginx config - 1" do
  not_if { File.exists?("/etc/nginx/sites-enabled/default") }
  code "rm /etc/nginx/sites-enabled/default"
end

bash "nginx config - 2" do
  not_if { File.exists?("/etc/nginx/sites-enabled/packagist") }
  code "ln -s /etc/nginx/sites-available/packagist /etc/nginx/sites-enabled/packagist"
end

# composer
bash "install composer" do
  not_if { File.exists?("/usr/local/bin/composer") }
  code <<-EOC
    cd ~
    curl -sS https://getcomposer.org/installer | php
    sudo mv composer.phar /usr/local/bin/composer
  EOC
end

bash "update composer" do
  code <<-EOC
    sudo composer self-update
  EOC
end

# php
if !File.exists?("/usr/lib/php5/20090626/phpiredis.so")
  git "/tmp/phpiredis" do
    repository "https://github.com/nrk/phpiredis"
    reference "1b3195f9debc34b8058d2b2a36b40ab27bc62f27"
    action :checkout
  end
end

bash "install phpiredis" do
  not_if { File.exists?("/usr/lib/php5/20090626/phpiredis.so") }
  code <<-EOC
    cd /tmp/phpiredis
    phpize
    ./configure --enable-phpiredis --with-hiredis-dir=/usr/local
    make
    make install
    echo "extension=phpiredis.so" > /etc/php5/conf.d/phpiredis.ini
  EOC
end

bash "resolve dependencies of packagist" do
  user "vagrant"
  group "www-data"
  not_if { File.exists?("/www/ustream.tv/packagist/packagist/vendor") }
  code <<-EOC
    cd /www/ustream.tv/packagist/packagist
    composer install
  EOC
end

if !File.exists?("/www/ustream.tv/packagist/packagist/app/config/parameters.yml")
  template "/www/ustream.tv/packagist/packagist/app/config/parameters.yml" do
    user "vagrant"
    group "www-data"
    mode 0644
    source "parameters.yml.erb"
  end
end

#bash "setup Symfony project - 2" do
#  user "vagrant"
#  group "www-data"
#  code <<-EOC
#  cd /www/ustream.tv/packagist/packagist
#  php app/console assets:install --symlink web
#  mysqlshow -u root packagist
#  if [ $? -ne 0 ]; then
#    php app/console doctrine:database:create
#    php app/console doctrine:schema:create
#  fi
#EOC
#end

template "/etc/php5/fpm/conf.d/custom.ini" do
	user "vagrant"
	group "www-data"
	mode 0644
	source "custom_php.ini.erb"
end

%w{
  mysql
  redis-server
  tomcat6
  php5-fpm
  nginx
}.each do |service_name|
  service service_name do
    action [:start, :restart]
  end
end

file "/etc/mysql/conf.d/bind.cnf" do
	action :create
	owner "root"
	group "root"
	mode "0644"
	content "[mysqld]
bind-address=0.0.0.0
"
	notifies :restart, "service[mysql]"
end

execute "mysql root all" do
	command "/usr/bin/mysql -u root -e \"grant all on *.* to 'root'@'%' WITH GRANT OPTION;\""
	# not_if
	action :run
end
