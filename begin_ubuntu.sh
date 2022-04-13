#! /usr/bin/bash

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
# TMP_DIR="$(mktemp -d -t dev-begin.XXXXXX)"
TMP_DIR="${HOME}/.tmp/dev-begin/"

if [[ ! -d "${TMP_DIR}" ]]; then
	mkdir "${TMP_DIR}"
fi

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
function wget() {
	command wget --no-verbose --timeout=10 --show-progress --progress=bar:force:noscroll "$@"
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

# NOTE Begin of the script
if have_sudo_access; then
	# NOTE add User to visudo
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}NOPASSWD for ${RED}${USER}${CYAN}...${RESET}" >&2
	if (sudo grep -qiF ${USER} /etc/sudoers); then
		echo -e "${BOLD}${YELLOW}User ${RED}${USER}${YELLOW} is already in sudoers.${RESET}" >&2
	else
		echo -e "${BOLD}${YELLOW}User ${RED}${USER}${YELLOW} is not in sudoers." >&2
		echo -e "${BOLD}${CYAN}Adding user ${RED}${USER}${CYAN} to sudoers..." >&2
		sudo bash -c "echo '${USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
	fi

	# NOTE change apt sources
	if ${SET_MIRRORS}; then

		APT_SOURCE_LIST="/etc/apt/sources.list"

		echo " " >&2
		echo -e "${BLOD}${UNDERLINE}${CYAN}Setting APT Sources...${RESET}" >&2
		echo -e "${BLOD}${RED}Choose APT source from Aliyun, Huawei or Tuna.(Recommend Huawei)${RESET}" >&2
		PS3="Select apt source:) "

		select apt in Aliyun Huawei Tuna; do
			case $apt in
			Aliyun)
				exec_cmd "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
				echo -e "${BOLD}${BLUE}Change apt sources to Aliyun:${RESET}" >&2
				cat <<-'EOF' | sudo tee ${APT_SOURCE_LIST}
					deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
					deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
				EOF
				echo -e "${BOLD}${YELLOW}Change apt sources success${RESET}" >&2
				break
				;;
			Huawei)
				exec_cmd "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
				echo -e "${BOLD}${BLUE}Change apt sources to Huawei:${RESET}" >&2
				cat <<-'EOF' | sudo tee ${APT_SOURCE_LIST}
					deb http://repo.huaweicloud.com/ubuntu/ focal main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-security main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-security main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-updates main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-updates main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-proposed main restricted universe multiverse
					deb http://repo.huaweicloud.com/ubuntu/ focal-backports main restricted universe multiverse
					deb-src http://repo.huaweicloud.com/ubuntu/ focal-backports main restricted universe multiverse
				EOF
				echo -e "${BOLD}${YELLOW}Change apt sources success${RESET}" >&2
				break
				;;
			Tuna)
				exec_cmd "sudo cp -f ${APT_SOURCE_LIST} ${APT_SOURCE_LIST}.bp"
				echo -e "${BOLD}${BLUE}Change apt sources to Tuna:${RESET}" >&2
				cat <<-'EOF' | sudo tee ${APT_SOURCE_LIST}
					# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal main restricted universe multiverse
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-updates main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-updates main restricted universe multiverse
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-backports main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-backports main restricted universe multiverse
					deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-security main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-security main restricted universe multiverse

					# 预发布软件源，不建议启用
					# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-proposed main restricted universe multiverse
					# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-proposed main restricted universe multiverse
				EOF
				echo -e "${BOLD}${YELLOW}Change apt sources success${RESET}" >&2
				break
				;;
			*)
				echo -e "${BOLD}${RED}invalid option $REPLY${RESET}" >&2
				echo -e "${BOLD}${RED}Please choose again ${RESET}" >&2
				;;
			esac
		done
	fi

	# NOTE install packages

	# * Add PPA
	echo " " >&2
	echo -e "${BOLD}${BLUE}Add PPA:${RESET}" >&2
	# gdu
	exec_cmd 'sudo add-apt-repositiory ppa:daniel-milde/gdu --yes'
	# neovim
	exec_cmd 'sudo add-apt-repositiory ppa:neovim-ppa/unstable'
	# vscode

	# * Update && Upgrade
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Update && Upgrade Packages${RESET}" >&2
	exec_cmd 'sudo apt-get update --yes'
	exec_cmd 'sudo apt-get upgrade --yes'

	# * APT tools
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install APT tools${RESET}" >&2
	exec_cmd 'sudo apt-get install software-properties-common, apt-transport-https --yes'

	# * shell
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Shell Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install zsh --yes'

	if ! grep -qF '/usr/bin/zsh' /etc/shells; then
		exec_cmd "echo '/usr/bin/zsh' | sudo tee -a /etc/shells"
	fi

	# * Git
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Git Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install git git-lfs git-extras --yes'

	# * Compress
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Compress Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install tar gzip --yes'

	# * File && Net
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install File and Net Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install curl wget httpie rsync tree colordiff xclip net-tools --yes'

	# * Searching
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Searching Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install fzf gawk ripgrep autojump --yes'

	# * tmux
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install tmux Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install tmux --yes'

	# * Query
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install query Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install tldr thefuck --yes'

	# * DevTools
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install DevTools Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install build-essential libboost-all-dev make camke automake autoconf gcc g++ gdb --yes'

	# * Top
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install Top Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install htop gpustat --yes'
	# TODO

	# * SSH && fail2ban
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install SSH Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install ssh openssh-server fail2ban --yes'
	# TODO

	# * NVME
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install NVME Packages${RESET}" >&2
	exec_cmd 'sudo apt-get install smartmontools --yes'

	# * du
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install gdu & ncdu ${RESET}" >&2
	exec_cmd 'sudo apt-get install gdu ncdu --yes'

	# * neovim
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install neovim${RESET}" >&2
	exec_cmd 'sudo apt-get install neovim --yes'

	# * fd
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install fd${RESET}" >&2
	LATEST_FD_VERSION="$(get_latest_version "sharkdp/fd")"
	if [[ -n "${LATEST_FD_VERSION}" ]] && ! check_binary fd "${LATEST_FD_VERSION}" && ! check_binary fdfind "${LATEST_FD_VERSION}"; then
		exec_cmd "wget -t 3 -T 15 -N -P \"${TMP_DIR}\" https://github.com/sharkdp/fd/releases/download/${LATEST_FD_VERSION}/fd_${LATEST_FD_VERSION#v}_amd64.deb"
		exec_cmd "sudo dpkg -i \"${TMP_DIR}/fd_${LATEST_FD_VERSION#v}_amd64.deb\""
		exec_cmd "sudo rm -rf \"${TMP_DIR}/fd_${LATEST_FD_VERSION#v}_amd64.deb\""
		echo -e "${BOLD}${YELLOW}fd installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}fd is already installed${RESET}" >&2
	fi

	# * bat
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install bat${RESET}" >&2
	LATEST_BAT_VERSION="$(get_latest_version "sharkdp/bat")"
	if [[ -n "${LATEST_BAT_VERSION}" ]] && ! check_binary bat "${LATEST_BAT_VERSION}" && ! check_binary batcat "${LATEST_BAT_VERSION}"; then
		exec_cmd "wget -t 3 -T 15 -N -P \"${TMP_DIR}\" https://github.com/sharkdp/bat/releases/download/${LATEST_BAT_VERSION}/bat_${LATEST_BAT_VERSION#v}_amd64.deb"
		exec_cmd "sudo dpkg -i \"${TMP_DIR}/bat_${LATEST_BAT_VERSION#v}_amd64.deb\""
		exec_cmd "sudo rm -rf \"${TMP_DIR}/bat_${LATEST_BAT_VERSION#v}_amd64.deb\""
		echo -e "${BOLD}${YELLOW}bat installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}bat is already installed${RESET}" >&2
	fi

	# * exa
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install exa${RESET}" >&2
	LATEST_EXA_VERSION="$(get_latest_version "ogham/exa")"
	if [[ -n "${LATEST_EXA_VERSION}" ]] && ! check_binary exa "${LATEST_EXA_VERSION}"; then
		exec_cmd "wget -t 3 -T 15 -N -P \"${TMP_DIR}\" https://github.com/ogham/exa/releases/download/${LATEST_EXA_VERSION}/exa-linux-x86_64-${LATEST_EXA_VERSION}.zip"
		exec_cmd "sudo unzip -q \"${TMP_DIR}/exa-linux-x86_64-${LATEST_EXA_VERSION}.zip\" bin/exa -d /usr/lcoal"
		exec_cmd "sudo rm -rf \"${TMP_DIR}/exa-linux-x86_64-${LATEST_EXA_VERSION}.zip\""
		echo -e "${BOLD}${YELLOW}exa installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}exa is already installed${RESET}" >&2
	fi

	# * duf
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Install duf${RESET}" >&2
	LATEST_DUF_VERSION="$(get_latest_version "muesli/duf")"
	echo ${LATEST_DUF_VERSION}
	if [[ -n "${LATEST_DUF_VERSION}" ]] && ! check_binary duf "${LATEST_DUF_VERSION}"; then
		exec_cmd "wget -t 3 -T 15 -N -P \"${TMP_DIR}\" https://github.com/muesli/duf/releases/download/${LATEST_DUF_VERSION}/duf_${LATEST_DUF_VERSION#v}_linux_amd64.deb"
		exec_cmd "sudo dpkg -i \"${TMP_DIR}/duf_${LATEST_DUF_VERSION#v}_linux_amd64.deb\""
		exec_cmd "sudo rm -rf \"${TMP_DIR}/duf_${LATEST_DUF_VERSION#v}_linux_amd64.deb\""
		echo -e "${BOLD}${YELLOW}duf installed${RESET}" >&2
	else
		echo -e "${BOLD}${RED}duf is already installed${RESET}" >&2
	fi

	# * btop


	# * install Nvidia Driver

	# * install CUDA

	# * install CUDNN

	# * python
	# * install Anaconda3

	# * npm

	# * service
	# * frpc

	# * BIT LOGIN


	# * install xrdp


	# * Enabel Service
	# * 1. ssh

	# * 2. fail2ban

	# * 3. xrdp


	# * autoremove && autoclean
	echo " " >&2
	echo -e "${BOLD}${UNDERLINE}${CYAN}Autoremove & Autoclean${RESET}" >&2
	exec_cmd 'sudo apt-get autoremove --purge --yes && sudo apt-get autoclean --yes'

fi


# NOTE Change the login shell to zsh
if [[ "$(basename "${SHELL}")" != "zsh" ]]; then
	CHSH="chsh"
	if have_sudo_access; then
		CHSH="sudo chsh"
	fi
	if grep -qF '/usr/bin/zsh' /etc/shells; then
		exec_cmd "${CHSH} --shell /usr/bin/zsh ${USER}"
	elif grep -qF '/bin/zsh' /etc/shells; then
		exec_cmd "${CHSH} --shell /bin/zsh ${USER}"
	fi
fi

# TODO Add utility script file
