#! /usr/bin/bash
function get_latest_version() {
	local REPO="$1" VERSION="" i
	for ((i = 0; i < 5; ++i)); do
		VERSION="$(
			curl --silent --connect-timeout 10 "https://api.github.com/repos/${REPO}/releases/latest" |
				grep '"tag_name":' |
				sed -E 's/^.*:\s*"([^"]+)",?$/\1/'
		)"
		if [[ -n "${VERSION}" ]]; then
			break
		fi
	done
	echo "${VERSION}"
}

echo " " >&2
echo -e "${BOLD}${UNDERLINE}${CYAN}Install fd${RESET}" >&2
# if [[ -z "$(apt-cache search '^fd-find$' --names-only)" ]]; then
LATEST_FD_VERSION="$(get_latest_version "sharkdp/fd")"
# if [[ -n "${LATEST_FD_VERSION}" ]] && ! check_binary fd "${LATEST_FD_VERSION}" && ! check_binary fdfind "${LATEST_FD_VERSION}"; then
eval "wget -N -P . https://github.com/sharkdp/fd/releases/download/${LATEST_FD_VERSION}/fd_${LATEST_FD_VERSION#v}_amd64.deb"
eval "sudo dpkg -i ./fd_${LATEST_FD_VERSION#v}_amd64.deb"
# eval "sudo rm -rf \"${TMP_DIR}/fd_${LATEST_FD_VERSION#v}_amd64.deb\""
# fi
# fi

# * bat
echo " " >&2
echo -e "${BOLD}${UNDERLINE}${CYAN}Install bat${RESET}" >&2
# if [[ -z "$(apt-cache search '^bat$' --names-only)" ]]; then
LATEST_FD_VERSION="$(get_latest_version "sharkdp/bat")"
# if [[ -n "${LATEST_FD_VERSION}" ]] && ! check_binary bat "${LATEST_FD_VERSION}" && ! check_binary batcat "${LATEST_FD_VERSION}"; then
eval "wget -N -P . https://github.com/sharkdp/bat/releases/download/${LATEST_FD_VERSION}/bat_${LATEST_FD_VERSION#v}_amd64.deb"
eval "sudo dpkg -i ./bat_${LATEST_FD_VERSION#v}_amd64.deb"
# eval "sudo rm -rf \"${TMP_DIR}/bat_${LATEST_FD_VERSION#v}_amd64.deb\""
# fi
# fi

# * exa
echo " " >&2
echo -e "${BOLD}${UNDERLINE}${CYAN}Install exa${RESET}" >&2
# if [[ -z "$(apt-cache search '^exa$' --names-only)" ]]; then
LATEST_FD_VERSION="$(get_latest_version "ogham/exa")"
# if [[ -n "${LATEST_FD_VERSION}" ]] && ! check_binary exa "${LATEST_FD_VERSION}"; then
eval "wget -N -P . https://github.com/ogham/exa/releases/download/${LATEST_FD_VERSION}/exa-linux-x86_64-${LATEST_FD_VERSION}.zip"
eval "sudo unzip -q ./exa-linux-x86_64-${LATEST_FD_VERSION}.zip bin/exa -d /usr/lcoal"
# eval "sudo rm -rf ./exa-linux-x86_64-${LATEST_FD_VERSION}.zip"
# fi
# fi

# * duf
echo " " >&2
echo -e "${BOLD}${UNDERLINE}${CYAN}Install duf${RESET}" >&2
# if [[ -z "$(apt-cache search '^exa$' --names-only)" ]]; then
LATEST_FD_VERSION="$(get_latest_version "ogham/exa")"
# if [[ -n "${LATEST_FD_VERSION}" ]] && ! check_binary exa "${LATEST_FD_VERSION}"; then
eval "wget -N -P . https://github.com/ogham/exa/releases/download/${LATEST_FD_VERSION}/exa-linux-x86_64-${LATEST_FD_VERSION}.zip"
# eval "sudo unzip -q exa-linux-x86_64-${LATEST_FD_VERSION}.zip bin/exa -d /usr/lcoal"
# eval "sudo rm -rf ./exa-linux-x86_64-${LATEST_FD_VERSION}.zip"
# fi
# fi
