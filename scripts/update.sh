this_url=`svn info $root_dir | grep URL:`
this_url=${this_url/URL: /}
latest_tag=(`svn ls svn://digital-source.bfb1.services.ipcdigital.co.uk/symfony/taxon/tags/releases`)
latest_tag=svn://digital-source.bfb1.services.ipcdigital.co.uk/symfony/taxon/tags/releases/${latest_tag[${#latest_tag[@]}-1]}
if [ $latest_tag != $this_url ]
then
  echo "There's an update available. Download it?"
  echo -n "  [y/n] : "
  read do_update
  while [ $do_update != "y" ] && [ $do_update != "n" ]
  do
    echo -n "  [y/n] : "
    read do_update
  done
  if [ $do_update = "y" ]
  then
    svn switch $latest_tag $root_dir
    exit
  fi
fi
unset this_info
unset latest_tag

