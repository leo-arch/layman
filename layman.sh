#!/bin/sh

# A command-line X11 keyboard layout manager

##PROGRAM DATA##
PROGRAM_NAME="layman"
VERSION="0.1-1"
DATE="Apr, 2018"
AUTHOR="L.M. Abramovich"

##COLORS##
white="\033[1;37m"
blue="\033[1;34m"
green="\033[1;32m"
red="\033[1;31m"
yellow='\033[1;33m'
nc="\033[0m"

##FUNCTIONS##
function help
{
	echo "A commnad-line X11 keyboard layout manager"
	echo "Usage: $PROGRAM_NAME 
	[-a, --add] [layout]	Add a new keyboard layout
	[-c, --current]		Show currrent layouts
	[-h, --help]		Print this help and exit
	[-i, --info]		Print information about the current keyboard layout
	[-s, --set] [layout]	Set keyboard layout
	[-v, --version]		Print version information and exit"
}

function get_layouts
{
	layout_ok=0
	while read line; do
		[[ $line == "! variant" ]] && break
		[[ layout_ok -eq 1 && $line != "" ]] && layouts[${#layouts[@]}]=$line
		[[ $line == "! layout" ]] && layout_ok=1 && continue
	done <<<"$(cat /usr/share/X11/xkb/rules/base.lst)"
}

function perm_set_layout
{
	sel_layout=$1
	msg=$(echo -e "${blue}::$nc Permanently set this layout? [y/N] ")
	read -p "$msg" answer
	case $answer in
		Y|y)
			# Get declared layouts in Xorg conf file
			cur_layouts=$(cat $xorg_kb_tmp | grep XkbLayout | awk '{print $3}' | sed 's/"//g')
			# Check whether the new layout is already declared
			if [[ $(echo "$cur_layouts" | grep "$sel_layout") ]]; then
				# If layout is already default, do nothing
				[[ $(cat $xorg_kb_tmp | grep XkbLayout | grep "\"$sel_layout") ]] && echo -e "${white}${sel_layout}$nc is already the default layout" && exit 0
				# Else, remove the old position of the layout and set it first
				new_layout_str=$(echo $cur_layouts | sed "s/,$sel_layout//g")
				new_layout_str=$(echo "\"${sel_layout},$new_layout_str\"")
			else # If not declared, make it default (first position)
				new_layout_str=$(echo "\"${sel_layout},${cur_layouts}\"")
			fi
			sed -i "/XkbLayout/c\\\tOption \"XkbLayout\" \"$new_layout_str\"" $xorg_kb_tmp
			sudo mv $xorg_kb_tmp $xorg_kb_file
			[[ $? -eq 0 ]] && echo -e "${white}$sel_layout$nc permanently set as default keyboard layout" 
		;;
		""|N|n) ;;
		q|quit|"exit") exit 0 ;;
		*) echo "Invalid answer" ;;
	esac
}

function add_new_layout
{
	# Find the layout line in Xorg conf file and replace it by the new one (containing the new 
	#+ layout)
	sel_layout=$1t
	while read line; do
		if [[ $line == *"XkbLayout"* ]]; then
			line_b=$(echo $line | rev | cut -d'"' -f2-10 | rev)
			sed -i "/${line}/c\\\t\\${line_b},${sel_layout}\"" $xorg_kb_tmp
		fi
	done <<<"$(cat $xorg_kb_tmp)"
	sudo mv $xorg_kb_tmp $xorg_kb_file
	[[ $(cat $xorg_kb_file | grep XkbLayout | grep $sel_layout) ]] && echo -e "Layout ${white}$sel_layout$nc successfully added"
}

##MAIN##
[[ $# -eq 0 ]] && help && exit 0

xorg_kb_file=$(ls /etc/X11/xorg.conf.d/*-keyboard.conf)
tmp_dir="/tmp/layouts"
xorg_kb_tmp="${tmp_dir}/00-keyboard.conf"
! [[ -d $tmp_dir ]] && mkdir -p $tmp_dir

# If no Xorg keyboard config file, create one
if [[ -z $xorg_kb_file ]]; then
	xorg_kb_file="/etc/X11/xorg.conf.d/00-keyboard.conf"
	echo -e "Section \"InputClass\"
	Identifier \"system-keyboard\"
	MatchIsKeyboard \"on\"
	Option \"XkbLayout\" \"us\"
	Option \"XkbModel\" \"pc105\"
	Option \"XkbVariant\" \"deadtilde,dvorak\"
	Option \"XkbOptions\" \"grp:alt_shift_toggle\"
EndSection" > $xorg_kb_tmp
else # Else copy the file to /tmp
	xorg_kb_file=$(ls /etc/X11/xorg.conf.d/*-keyboard.conf)
	cp $xorg_kb_file $xorg_kb_tmp
fi

option=$1
case $option in
	-h|--help) help	;;
	-v|--version) echo "$PROGRAM_NAME v$VERSION (${DATE}, by $AUTHOR)" ;;
	-a|--add)
		get_layouts
		if [[ ! -z $2 ]]; then # Layout provided as second arg
			sel_layout=$2
			#validate entered layout
			for (( i=0;i<${#layouts[@]};i++ )); do
				if [[ $sel_layout == "$(echo "${layouts[$i]}" | awk '{print $1}')" ]]; then
					# Check wheter this layout is set as default
					if [[ $(cat $xorg_kb_tmp | grep "XkbLayout" | grep "$sel_layout") ]]; then
						echo -e "${white}$sel_layout$nc layout already set"
					else #if not
						add_new_layout $sel_layout
					fi
					exit 0
				fi
			done 
		fi
		# No layout provided as second arg
		# List available layouts
		for (( i=0;i<${#layouts[@]};i++ )); do
			echo -e "${yellow}$((i+1))$nc ${layouts[$i]}"
		done
		echo; [[ ! -z $sel_layout ]] && echo "${sel_layout}: not a valid layout"
		msg=$(echo -e "${blue}::$nc Choose a layout: ")
		read -p "$msg" selection
		# Validate user input
		[[ $selection == "q" || $selection == "quit" || $selection == "exit" ]] && exit 0
		[[ $selection -le 0 || $selection -gt ${#layouts[@]} ]] && echo "Invalid layout" && exit 1
		sel_layout=$(echo "${layouts[$((selection-1))]}" | awk '{print $1}')
		if [[ $(cat $xorg_kb_tmp | grep "XkbLayout" | grep "$sel_layout") ]]; then
			echo -e "${white}$sel_layout$nc layout already set"
		else
			add_new_layout $sel_layout
		fi
	;;
	-c|--current) 		
		cur_layouts=( $(cat $xorg_kb_tmp | grep XkbLayout | awk '{print $3}' | sed 's/"//g' | sed 's/,/ /g') )
		echo "Current layouts: ${cur_layouts[@]}"
	;;
	-i|--info) setxkbmap -print -verbose 10 ;;
	-r|--remove) 
		echo "Current layouts: "
		# Get currently declared layouts from Xorg config file
		cur_layouts=( $(cat $xorg_kb_tmp | grep XkbLayout | awk '{print $3}' | sed 's/"//g' | sed 's/,/ /g') )
		# List layouts
		for (( i=0;i<${#cur_layouts[@]};i++ )); do
			echo -e "${yellow}$((i+1))$nc ${cur_layouts[$i]}"
		done
		msg=$(echo -e "${blue}::$nc Choose layout to be removed: ")
		echo; read -p "$msg" rem_layout
		# Validate user input
		[[ $rem_layout == "q" || $rem_layout == "quit" || $rem_layout == "exit" ]] && exit 0
		[[ $rem_layout -le 0 || $rem_layout -gt ${#cur_layouts[@]} ]] && echo "Invalid layout" && exit 1
		# Create a list of layouts (new_layout_str) excluding the removed one
		for (( i=0;i<${#cur_layouts[@]};i++ )); do
			if [[ ${cur_layouts[$i]} != "${cur_layouts[$((rem_layout-1))]}" ]]; then
				if [[ $i -eq 0 ]]; then
					new_layout_str=${cur_layouts[$i]}
				else
					new_layout_str=$(echo "${new_layout_str},${cur_layouts[$i]}")
				fi
			fi
		done
		# Replace the old layout line with the new one in Xorg tmp config file
		sed -i "/XkbLayout/c\\\tOption \"XkbLayout\" \"$new_layout_str\"" $xorg_kb_tmp
		# Replace Xorg file by the Xorg tmp file
		sudo mv $xorg_kb_tmp $xorg_kb_file
		[[ $? -eq 0 ]] && echo -e "Layout ${white}${cur_layouts[$((rem_layout-1))]}$nc successfully removed"
	;;
	-s|--set)
		# Get all available layouts
		get_layouts
		# Get currently working layout
		cur_set_layout=$(setxkbmap -print -verbose 10 | grep layout: | awk '{print $2}')
		if [[ ! -z $2 ]]; then # If a layout was passed as second arg
			sel_layout=$2
			# Check whether passed layout is a valid layout
			for (( i=0;i<${#layouts[@]};i++ )); do
				if [[ $(echo ${layouts[$i]} | awk '{print $1}') == $sel_layout ]]; then
					if [[ $cur_set_layout == "$sel_layout" ]]; then
						echo -e "${white}${sel_layout}${nc} layout is already set"
					else #if selected layout is not already set
						echo "setxkbmap $sel_layout"
						[[ $? -eq 0 ]] && echo -e "Layout successfully changed to ${white}${sel_layout}$nc"
					fi
					# if selected layout is already the deault layout, exit
					[[ $(cat $xorg_kb_tmp | grep XkbLayout | grep "\"$sel_layout") ]] && exit 0
					# else
					perm_set_layout $sel_layout
					exit 0
				fi
			done
		fi
		#if no layout has been passed as second arg or if it's not a valid layout, list 
		#+ available layouts
		for (( i=0;i<${#layouts[@]};i++ )); do
			echo -e "${yellow}$((i+1))$nc ${layouts[$i]}"
		done
		echo; [[ ! -z $sel_layout ]] && echo "${sel_layout}: not a valid layout"
		msg=$(echo -e "${blue}::$nc Choose a layout: ")
		read -p "$msg" selection
		# Validate user selection
		[[ $selection == "q" || $selection == "quit" || $selection == "exit" ]] && exit 0
		[[ $selection -le 0 || $selection -gt ${#layouts[@]} ]] && echo "Invalid layout" && exit 1
		sel_layout=$(echo "${layouts[$((selection-1))]}" | awk '{print $1}')
		if [[ $cur_set_layout == "$sel_layout" ]]; then
			echo -e "${white}${sel_layout}${nc} layout is already set"
		else #if selected layout is not already set
			echo "setxkbmap $sel_layout"
			[[ $? -eq 0 ]] && echo -e "Layout successfully changed to ${white}${sel_layout}$nc"
		fi
		[[ $(cat $xorg_kb_tmp | grep XkbLayout | grep "\"$sel_layout") ]] && exit 0
		# Ask whether to permanently set the new layout
		perm_set_layout $sel_layout
	;;
esac

exit 0
