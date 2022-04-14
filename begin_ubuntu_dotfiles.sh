#! /usr/bin/bash

# sudo ln -s /lib/x86_64-linux-gnu/libtic.so.6.2 /lib/x86_64-linux-gnu/libtinfow.so.6

# Reset
RESET="\033[0m"

# Format
BOLD="\033[1m"
UNDERLINE="\033[4m"
UNDERLINEOFF="\033[24m"

# Regular Colors foreground
BLACK="\033[0;30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# * Options
export SET_MIRRORS="${SET_MIRRORS:-false}"

# * Set USER
export USER="${USER:-"$(whoami)"}"

# * Set configuration backup directory

# * dotfile directory
DATETIME="$(date +"%Y-%m-%d-%T")"
BACKUP_DIR="${HOME}/.dotfiles/backups/${DATETIME}"
mkdir -p "${BACKUP_DIR}/.dotfiles"
ln -sfn "${DATETIME}" "${HOME}/.dotfiles/backups/latest"
chmod 755 "${HOME}/.dotfiles"

# * Set temporary directory
TMP_DIR="$(mktemp -d -t dev-begin.XXXXXX)"
# TMP_DIR="/tmp/dev-begin.NZ4Gs6"
# # TMP_DIR="${HOME}/.tmp/dev-begin/"

# if [[ ! -d "${TMP_DIR}" ]]; then
# 	mkdir "${TMP_DIR}"
# fi

# NOTE Common Functions
function exec_cmd() {
	printf "%s" "$@" | awk \
		'BEGIN {
			RESET = "\033[0m";
			BOLD = "\033[1m";
			UNDERLINE = "\033[4m";
			UNDERLINEOFF = "\033[24m";
			RED = "\033[31m";
			GREEN = "\033[32m";
			YELLOW = "\033[33m";
			WHITE = "\033[37m";
			GRAY = "\033[90m";
			IDENTIFIER = "[_a-zA-Z][_a-zA-Z0-9]*";
			idx = 0;
			in_string = 0;
			double_quoted = 1;
			printf("%s$", BOLD WHITE);
		}
		{
			for (i = 1; i <= NF; ++i) {
				style = WHITE;
				post_style = WHITE;
				if (!in_string) {
					if ($i ~ /^-/)
						style = YELLOW;
					else if ($i == "sudo" && idx == 0) {
						style = UNDERLINE GREEN;
						post_style = UNDERLINEOFF WHITE;
					}
					else if ($i ~ "^" IDENTIFIER "=" && idx == 0) {
						style = GRAY;
						'"if (\$i ~ \"^\" IDENTIFIER \"=[\\\"']\") {"'
							in_string = 1;
							double_quoted = ($i ~ "^" IDENTIFIER "=\"");
						}
					}
					else if ($i ~ /^[12&]?>>?/ || $i == "\\")
						style = RED;
					else {
						++idx;
						'"if (\$i ~ /^[\"']/) {"'
							in_string = 1;
							double_quoted = ($i ~ /^"/);
						}
						if (idx == 1)
							style = GREEN;
					}
				}
				if (in_string) {
					if (style == WHITE)
						style = "";
					post_style = "";
					'"if ((double_quoted && \$i ~ /\";?\$/ && \$i !~ /\\\\\";?\$/) || (!double_quoted && \$i ~ /';?\$/))"'
						in_string = 0;
				}
				if (($i ~ /;$/ && $i !~ /\\;$/) || $i == "|" || $i == "||" || $i == "&&") {
					if (!in_string) {
						idx = 0;
						if ($i !~ /;$/)
							style = RED;
					}
				}
				if ($i ~ /;$/ && $i !~ /\\;$/)
					printf(" %s%s%s;%s", style, substr($i, 1, length($i) - 1), (in_string ? WHITE : RED), post_style);
				else
					printf(" %s%s%s", style, $i, post_style);
				if ($i == "\\")
					printf("\n\t");
			}
		}
		END {
			printf("%s\n", RESET);
		}' >&2
	eval "$@"
}

unset HAVE_SUDO_ACCESS

function have_sudo_access() {
	# UID: user ID, 0 is root
	if [[ "${EUID:-"${UID}"}" == "0" ]]; then
		return 0
	fi

	if [[ ! -x "/usr/bin/sudo" ]]; then
		return 1
	fi

	local -a SUDO=("/usr/bin/sudo")
	if [[ -n "${SUDO_ASKPASS-}" ]]; then
		SUDO+=("-A")
	fi

	if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
		echo -e "${BOLD}${UNDERLINE}${CYAN}Checking sudo access (press ${YELLOW}Ctrl+C${CYAN} to run as normal user).${UNDERLINEOFF}${RESET}" >&2
		# [*] 取全部字段
		exec_cmd "${SUDO[*]} -v && ${SUDO[*]} -l mkdir &>/dev/null"
		HAVE_SUDO_ACCESS="$?"
	fi

	if [[ "${HAVE_SUDO_ACCESS}" == "0" ]]; then
		echo -e "${BOLD}${YELLOW}sudo access available.${RESET}" >&2
	else
		echo -e "${BOLD}${MAGENTA}sudo access unavailable.${RESET}" >&2
	fi

	return "${HAVE_SUDO_ACCESS}"
}

# cp -rf 强行递归复制
function backup_dotfiles() {
	local file original_file
	for file in "$@"; do
		if [[ -f "${file}" || -d "${file}" ]]; then
			# -L 符号链接
			# realpath 将符号链接转换为绝对路径
			if [[ -L "${file}" ]]; then
				original_file="$(realpath "${file}")"
				rm -f "${file}"
				cp -rf "${original_file}" "${file}"
			fi
			cp -rf "${file}" "${BACKUP_DIR}/${file}"
		fi
	done
}

# --no-verbose 关闭长信息，静默执行； --timeout=10 可以设置超时时间; --show-progress 显示进度条, --progress 进度条格式
# command, 调用并执行命令
function new_wget() {
	command wget --no-verbose --timeout=10 -t=10 --no-check-certificate --show-progress --progress=bar:force:noscroll "$@"
}

# github releases info api
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

function check_binary() {
	local CMD="$1" OPT REQUIRED="${2#v}" VERSION
	for OPT in "--version" "-v" "-V"; do
		VERSION="$("${CMD}" "${OPT}" 2>&1)"
		if [[ $? -eq 0 && "${VERSION}" == *"${REQUIRED}"* ]]; then
			return 0
		fi
	done
	return 1
}

# TODO Add utility script file

# TODO dotfiles

if [[ ! -d ${HOME}/.dotfiles ]]; then
	eval "mkdir ${HOME}/.dotfiles"
fi

echo " " >&2
echo -e "${BOLD}${UNDERLINE}${CYAN}Download haohaolalahao/dotfile${RESET}" >&2
LATEST_DOTFILE_VERSION="$(get_latest_version "haohaolalahao/dotfile")"
exec_cmd "new_wget -N -P \"${TMP_DIR}\" https://github.com/haohaolalahao/dotfile/releases/download/${LATEST_DOTFILE_VERSION}/dotfiles_${LATEST_DOTFILE_VERSION}.zip"
exec_cmd "unzip -o \"${TMP_DIR}/dotfiles_${LATEST_DOTFILE_VERSION}.zip\" -d ${HOME}/.dotfiles/"
echo -e "${BOLD}${YELLO}Download success${RESEST}" >&2


# NOTE ZSH
if [ -t 0 ] && [ -t 1 ]; then
	while true; do
		read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to configure zsh? ${RED}[y/N]: ${RESET}")" answer
		if [[ -n "${answer}" ]]; then
			echo
		else
			echo
		fi
		if [[ "${answer}" == [Yy] ]]; then
			echo -e "${BOLD}${YELLOW}Begin configure zsh${RESET}" >&2
			if have_sudo_access; then
				exec_cmd "sudo snap install starship --edge"
				exec_cmd "sudo snap refresh starship"
			else
				exec_cmd "curl -sS https://starship.rs/install.sh | sh"
			fi
			exec_cmd "curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh"
			exec_cmd "cp ${HOME}/.dotfiles/.zshrc ${HOME}/"
			exec_cmd "cp -f ${HOME}/.dotfiles/starship.toml ${HOME}/.config/"
			break
		elif [[ "${answer}" == [Nn] ]]; then
			echo -e "${BOLD}${RED}will not configure zsh${RESET}" >&2
			break
		fi
	done
fi

# NOTE TMUX
if [ -t 0 ] && [ -t 1 ]; then
	while true; do
		read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to configure tmux? ${RED}[y/N]: ${RESET}")" answer
		if [[ -n "${answer}" ]]; then
			echo
		else
			echo
		fi
		if [[ "${answer}" == [Yy] ]]; then
			echo -e "${BOLD}${YELLOW}Begin configure tmux${RESET}" >&2

			exec_cmd "cp ${HOME}/.dotfiles/.tmux.conf ${HOME}/"

			break
		elif [[ "${answer}" == [Nn] ]]; then
			echo -e "${BOLD}${RED}will not configure tmux${RESET}" >&2
			break
		fi
	done
fi

# NOTE NEOVIM
if [ -t 0 ] && [ -t 1 ]; then
	while true; do
		read -n 1 -p "$(echo -e "${BOLD}${BLUE}Do you wish to configure neovim? ${RED}[y/N]: ${RESET}")" answer
		if [[ -n "${answer}" ]]; then
			echo
		else
			echo
		fi
		if [[ "${answer}" == [Yy] ]]; then
			echo -e "${BOLD}${YELLOW}Begin configure neovim${RESET}" >&2

			exec_cmd "cp -rf ${HOME}/.dotfiles/nvim ${HOME}/.config/"

			break
		elif [[ "${answer}" == [Nn] ]]; then
			echo -e "${BOLD}${RED}will not configure neovim${RESET}" >&2
			break
		fi
	done
fi
