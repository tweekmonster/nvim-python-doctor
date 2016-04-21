#!/bin/bash
echo "Include the output below this line in your Github issues." 1>&2
echo 1>&2
echo 1>&2

echo "## Neovim Python Diagnostic"
echo

nvim=$(which nvim)
if [[ ! -e "$nvim" ]]; then
  echo "- nvim not found.  Maybe that's your problem?"
  exit 1
fi

echo "- Neovim Version: $($nvim --version | head -n 1)"

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

echo

function test_nvim {
  exe="$1"
  echo
  echo "### '$exe' info from $nvim"
  echo
  nvim_var="${exe}_host_prog"
  tempfile=$(mktemp -t nvim_doctor.XXXXXXXX)

  $nvim --headless \
        +"redir! > $tempfile" \
        +"silent echo get(g:, '$nvim_var', '')" \
        +"redir END" \
        +"qa!"
  python_path=$(grep -e . $tempfile)
  if [[ -z "$python_path" ]]; then
    echo "WARN: 'g:${nvim_var}' is not set"
    python_path=$($WHICH_CMD $exe 2>&1)
    if [[ $? -ne 0 || -z "$python_path" ]]; then
      echo "ERR: '$WHICH_CMD $exe' returned nothing"
      rm $tempfile
      return 1
    else
      echo "WARN: Fallback to '$python_path'"
    fi
  else
    echo "**Config**: \`let g:$nvim_var = '$python_path'\`"
  fi

  echo -n "**Python Version**: "
  if [[ -e "$python_path" ]]; then
    echo "\`$($python_path -V 2>&1)\`"
  else
    echo "not found"
  fi

  nvim_package=$($python_path -m pip list 2>&1)
  if [[ $? -ne 0 ]]; then
    echo "ERR: \`${nvim_package}\`"
  else
    echo -n "**Neovim Package Version**: "
    nvim_package=$(echo "$nvim_package" | grep neovim)
    if [[ -z "$nvim_package" ]]; then
      echo "neovim package is not installed"
    else
      echo "\`$nvim_package\`"
    fi
  fi

  rm $tempfile
}

echo "## Python versions visible to Neovim"

test_nvim "python"
test_nvim "python3"

echo
echo "## Python versions visible in the current shell"
echo

tests=("python" "python3")
for py in ${tests[@]}; do
  cmd=$($WHICH_CMD $py 2>/dev/null)
  if [[ $? -eq 0 && -e "$cmd" ]]; then
    echo "- **${py}** version: \`$($cmd -V 2>&1 | head -n 1)\`"
    nvim_package=$($py -m pip list 2>/dev/null | grep neovim)
    if [[ -z "$nvim_package" ]]; then
      nvim_package="Not installed"
    fi
    echo "  - **neovim** version: \`$nvim_package\`"
  else
    echo "- **${py}**: not found"
  fi
done
