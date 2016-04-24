#!/bin/bash
need_py2=0
need_py3=0
messages=()

tempfiles=$(mktemp -t "nvim_doctor.XXXXXXXX")
cleanup_temp() {
  xargs rm -f < "$tempfiles"
  rm -f "$tempfiles"

  if [[ ${#messages} -gt 0 ]]; then
    echo
    section "## Messages or Suggestions"
    echo

    for msg in "${messages[@]}"; do
      echo "$msg"
    done
  fi
}

mktempfile() {
  mktemp -t "nvim_doctor.XXXXXXXX" | tee -a "$tempfiles"
}

trap cleanup_temp EXIT

success() {
  if [ -t 1 ]; then
    echo -e "\e[32m$@\e[m"
  else
    echo "$@"
  fi
}

info() {
  if [ -t 1 ]; then
    echo -e "\e[36m$@\e[m"
  else
    echo "$@"
  fi
}

warn() {
  if [ -t 1 ]; then
    echo -e "\e[33m$@\e[m"
  else
    echo "$@"
  fi
}

err() {
  if [ -t 1 ]; then
    echo -e "\e[31m$@\e[m"
  else
    echo "$@"
  fi
}

section() {
  if [ -t 1 ]; then
    echo -e "\e[1;37m$@\e[m"
  else
    echo "$@"
  fi
}

echo "Include the output below this line in your Github issues." 1>&2
echo 1>&2
echo 1>&2

section "## Neovim Python Diagnostic"
echo

nvim=$(which nvim)
if [[ ! -e "$nvim" ]]; then
  err "- nvim not found.  Maybe that's your problem?"
  exit 1
fi

echo -n "- Neovim Version: "
info "$($nvim --version | head -n 1)"

python_client_latest=$(curl -fsS https://pypi.python.org/pypi/neovim/json | awk -F\" '/^\s+"version":/ { print $4 }')


WHICH_CMD="which"
if type pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
  WHICH_CMD="pyenv which"
  echo "- \`pyenv\` is available"
  old_IFS="$IFS"
  IFS=$'\n'
  for v in $(pyenv version); do
    echo "  - $v"
  done
  IFS="$old_IFS"
fi

if [[ -n "$VIRTUAL_ENV" ]]; then
  venv_python="${VIRTUAL_ENV}/bin/python"
  echo "- \`virtualenv\` active: $(${VIRTUAL_ENV}/bin/python -V 2>&1)"
  echo "  - Path: $VIRTUAL_ENV"
fi


test_nvim() {
  exe="$1"
  echo
  section "### '$exe' info from $nvim"
  echo
  nvim_var="${exe}_host_prog"
  tempfile="$(mktempfile)"

  $nvim --headless \
        +"redir! > $tempfile" \
        +"silent echo get(g:, '$nvim_var', '')" \
        +"redir END" \
        +"qa!" 2> /dev/null
  python_path=$(grep -e . $tempfile)
  if [[ -z "$python_path" ]]; then
    echo "WARN: 'g:${nvim_var}' is not set."
    python_path=$($WHICH_CMD $exe 2>&1)
    if [[ $? -ne 0 || -z "$python_path" ]]; then
      messages+=("ERR: \`$exe\` could not be found in \$PATH.  If it does exist, you will need to use \`g:$nvim_var\` to point to it.")
      err "\`$WHICH_CMD $exe\` returned nothing."
      return 1
    else
      echo "WARN: Fallback to '$python_path'"
    fi
  else
    echo "**Config**: \`let g:$nvim_var = '$python_path'\`"
  fi

  python_version="$($python_path -V 2>&1 | awk -F ' ' '{ print $2 }')"
  echo "**Python Version**: \`$python_version\`"

  echo -n "**Neovim Package Version**: "
  nvim_package=$($python_path -m pip list 2>&1)
  local no_pip=0
  if [[ "$nvim_package" =~ "No module named pip" ]]; then
    no_pip=1
    messages+=("ERR: $nvim_package")
  fi

  nvim_package=$(echo "$nvim_package" | grep -E '^neovim\s' | sed -e 's/.\+(\(.\+\))/\1/g')
  if [[ -z "$nvim_package" ]]; then
    if [[ $no_pip -eq 1 ]]; then
      messages+=("ERR: neovim package is not installed for \`$exe\`")
    else
      messages+=("WARN: Install the neovim package with: \`pip${python_version%%.*} install --user neovim\`")
    fi
    err "not installed"
  else
    echo "\`$nvim_package\` (latest: \`$python_client_latest\`)"
  fi

  if [[ "$nvim_package" != "$python_client_latest" ]]; then
    messages+=("WARN: Upgrade the neovim package with: \`pip${python_version%%.*} install -U --user neovim\`")
  fi
}


check_remote_plugins() {
  tempfile="$(mktempfile)"
  rtp_tempfile="$(mktempfile)"
  $nvim --headless \
        +"redir! > $tempfile" \
        +"silent echo \$MYVIMRC" \
        +"redir END" \
        +"redir! > $rtp_tempfile" \
        +"silent echo join(split(&rtp, ','), \"\\n\")" \
        +"redir END" \
        +"qa!" 2> /dev/null

  init_file=$(grep -e . $tempfile)
  init_base=${init_file##*/}
  init_dir=${init_file%%/$init_base}
  manifest_file="$init_dir/.${init_base}-rplugin~"

  echo "**Manifest File**: \`${manifest_file:-MISSING}\`"

  rplugins=()
  unregistered=()

  for rtp in $(<$rtp_tempfile); do
    rtp="${rtp%%/}"
    check=""
    if [[ -d "$rtp/rplugin/python" ]]; then
      (( need_py2++ ))
      check="$rtp/rplugin/python"
    elif [[ -d "$rtp/rplugin/python3" ]]; then
      (( need_py3++ ))
      check="$rtp/rplugin/python3"
    fi

    if [[ -n "$check" ]]; then
      for p in $check/{*.py,*/__init__.py}; do
        if [[ -f "$p" ]]; then
          if grep -E '^(from|import)\s+neovim' "$p" >/dev/null 2>&1; then
            p="${p%%/__init__.py}"
            rplugins+=("$p")
          fi
        fi
      done
    fi
  done

  local need_update=0

  for rplugin in ${rplugins[@]}; do
    echo "**Plugin**: $rplugin"
    echo -n "  - Registered: "
    if grep -F "'$rplugin'" $manifest_file >/dev/null 2>&1; then
      success "Yes"
    else
      need_update=1
      err "No"
    fi
  done

  if [[ $need_update -eq 1 ]]; then
    err '**Manifest is not up to date**'
    messages+=('ERR: You need to run `:UpdateRemotePlugins` in Neovim to enable plugins')
  else
    info '**Manifest is up to date**'
  fi
}


echo
section "## Remote plugins"
echo

check_remote_plugins

test_nvim "python"
test_nvim "python3"

echo
section "## Python versions visible in the current shell"
echo

tests=("python" "python3")
for py in ${tests[@]}; do
  cmd=$($WHICH_CMD $py 2>/dev/null)
  if [[ $? -eq 0 && -e "$cmd" ]]; then
    echo "- **${py}** version: \`$($cmd -V 2>&1 | head -n 1)\`"
    nvim_package=$($py -m pip list 2>/dev/null | grep -E '^neovim\s')
    if [[ -z "$nvim_package" ]]; then
      nvim_package="Not installed"
    fi
    echo "  - **neovim** version: \`$nvim_package\`"
  else
    echo "- **${py}**: not found"
  fi
done
