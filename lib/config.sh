load_config_for_project()
{
  config_file="$root_dir/config/$1.sh"
  if [ ! -f $config_file ]
  then
    echo "I was expecting to see a config file '$config_file'... but it ain't there!"
    exit 2
  fi
  source $config_file
  unset config_file
}

