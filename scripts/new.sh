#!/bin/bash
echo -n "Group name > "
read group_name
svn_paths=()
i=0

read_project()
{
  echo "Enter a project's svn root path (ie. without the /trunk or /branches)... or just hit enter to stop"
  echo -n "> "
  read svn_path
}

read_project
while [ $svn_path ]
do
  svn_paths[$i]=$svn_path
  read_project
  let "i += 1"
done

config_file="$root_dir/config/$group_name.sh"
echo "projects=( ${svn_paths[@]} )" >> $config_file
echo "You're config has been stored in \"$config_file\"."

