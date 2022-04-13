#! /usr/bin/bash
if (ubuntu-drivers devices | grep -q nvidia); then
	VERSIONS=$(ubuntu-drivers devices | grep -Eo 'nvidia-driver-[0-9]*(-server)?' | sort -r)
	OLD_IFS="$IFS"
	IFS='\n'
	array=("$VERSIONS")
	IFS="$OLD_IFS"

	select var in ${array[@]}; do
		if [[ "${array[@]/${var}/}" != "${array[@]}" ]]; then
			echo "Your choose driver is: $var"
			break
		else
			echo "Your choose is not exist!"
		fi
	done
fi
