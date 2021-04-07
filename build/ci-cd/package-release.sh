#!/bin/bash

if [ -z ${OSCAL_SCRIPT_INIT+x} ]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)/include/init-oscal.sh"
fi

if [ -z "$1" ]; then
  working_dir="$OSCALDIR"
else
  working_dir=$(readlink -f "$1")
fi
echo -e "${P_INFO}Working in '${P_END}${working_dir}${P_INFO}'.${P_END}"


release_version=${RELEASE_VERSION}
release_name="oscal-${release_version}"

archive_dir="${working_dir}/archive/${release_name}"
mkdir -p "$archive_dir"

set -e

shopt -s nullglob
shopt -s globstar
while IFS="|" read path dest_path || [[ -n "$path" ]]; do
  shopt -s extglob
  [[ "$path" =~ ^[[:space:]]*# ]] && continue
  # remove leading space
  path="${path##+([[:space:]])}"
  # remove trailing space
  dest_path="${dest_path%%+([[:space:]])}"
  shopt -u extglob

  if [[ ! -z "$path" ]]; then
    files_to_process="$OSCALDIR"/"$path"
    IFS= # disable word splitting
    for file in $files_to_process
    do
      src="$OSCALDIR/$file"
      if [ -z "$dest_path" ]; then
        dest="${archive_dir}/${file/$OSCALDIR\//}"
      else
        dest="${archive_dir}${dest_path}"
      fi
      dest_dir=${dest%/*} # remove filename

      echo -e "${P_INFO}Copying '$file' to '$dest'.${P_END}"
      mkdir -p "$dest_dir"
      cp "$file" "$dest"
    done
  fi
done < "$OSCALDIR/build/ci-cd/config/release-content"
shopt -u nullglob
shopt -u globstar

set +e
