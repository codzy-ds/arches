#!/usr/bin/env bash

# For Ubuntu 18.04 (bionic)

# Use the yes command if you would like to install postgres/postgis, couchdb,
# node/yarn, and elasticsearch.
# Example:
# yes | sudo ./ubuntu_setup.sh

function install_postgres {
  sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main"
  wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update
  sudo apt-get install postgresql-12 postgresql-contrib-12 -y
  sudo apt-get install postgresql-12-postgis-3 -y
  sudo -u postgres psql -d postgres -c "ALTER USER postgres with encrypted password 'postgis';"
  sudo echo "*:*:*:postgres:postgis" >> ~/.pgpass
  sudo chmod 600 ~/.pgpass
  sudo chmod 666 /etc/postgresql/12/main/postgresql.conf
  sudo chmod 666 /etc/postgresql/12/main/pg_hba.conf
  sudo tee -a /etc/postgresql/12/main/postgresql.conf >> /dev/null <<EOF
standard_conforming_strings = off
listen_addresses = '*'
EOF
  sudo tee -a /etc/postgresql/12/main/pg_hba.conf > /dev/null << EOF
#TYPE   DATABASE  USER  CIDR-ADDRESS  METHOD
local   all       all                 trust
host    all       all   127.0.0.1/32  trust     
host    all       all   ::1/128       trust
host    all       all   0.0.0.0/0     md5
EOF
  sudo service postgresql restart

  sudo -u postgres createdb -E UTF8 -T template0 --locale=en_US.utf8 template_postgis
  sudo -u postgres psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis'"
  sudo -u postgres psql -d template_postgis -c "CREATE EXTENSION postgis;"
  sudo -u postgres psql -d template_postgis -c "CREATE EXTENSION \"uuid-ossp\";"
  sudo -u postgres psql -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"
  sudo -u postgres psql -d template_postgis -c "GRANT ALL ON geography_columns TO PUBLIC;"
  sudo -u postgres psql -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"
}

function install_couchdb {
  sudo apt update && sudo apt install -y curl apt-transport-https gnupg
  curl https://couchdb.apache.org/repo/keys.asc | gpg --dearmor | sudo tee /usr/share/keyrings/couchdb-archive-keyring.gpg >/dev/null 2>&1
  echo "deb [signed-by=/usr/share/keyrings/couchdb-archive-keyring.gpg] https://apache.jfrog.io/artifactory/couchdb-deb/ $(lsb_release -sc) main" \
    | sudo tee /etc/apt/sources.list.d/couchdb.list >/dev/null
  sudo apt-get update
  sudo apt-get install couchdb
}

function install_yarn {
  wget --quiet -O - https://deb.nodesource.com/setup_14.x | sudo -E bash -
  sudo apt-get update
  sudo apt-get install -y nodejs
  sudo apt install curl
  curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt update
  sudo apt install yarn
}

function install_elasticsearch {
  sudo apt-get install apt-transport-https
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list'
  sudo apt-get update
  sudo apt-get install elasticsearch
  sudo /bin/systemctl enable elasticsearch.service
  sudo systemctl enable elasticsearch.service
  sudo systemctl start elasticsearch.service
}

function install_python {
  python_package=3

  python_version=$(apt-cache show python3-dev | grep Version: | awk -F '[ -]' '{print $2}' | head -n1)

  if [[ $python_version < 3.7 ]]; then
	  sudo apt-get purge python3-dev python3-venv
	  python_package=3.7
  fi

  sudo apt-get install -y python${python_package}-dev
  sudo apt-get install -y python${python_package}-venv
  python
}

function main {
  INSTALL_DEPENDENCIES=" \
	        lsb-core
		make \
		software-properties-common \
		build-essential \
		libxml2-dev \
		libproj-dev \
		libjson-c-dev \
		xsltproc \
		docbook-xsl \
                docbook-mathml \
                libgdal-dev \
		libpq-dev \
		"
  sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
  sudo apt-get update -y
  sudo apt-get install -y $INSTALL_DEPENDENCIES

  install_python

  echo -n "Would you like to install elasticsearch? (y/N)? "
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    echo Yes, installing Elasticsearch
    install_elasticsearch
  else
    echo Skipping Elasticsearch installation
  fi

  echo -n "Would you like to install and configure postgres/postgis? (y/N)? "
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    echo Yes, Installing Postgres/PostGIS
    install_postgres
  else
    echo Skipping Postgres/PostGIS installation
  fi

  echo -n "Would you like to install and configure couchdb? (y/N)? "
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    echo Yes, Installing CouchDB
    install_couchdb
  else
    echo Skipping CouchDB installation
  fi

  echo -n "Would you like to install and nodejs/npm/and yarn (y/N)? "
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    echo Yes, installing Node/Yarn
    install_yarn
  else
    echo Skipping Node/Yarn installation
  fi
}

main
