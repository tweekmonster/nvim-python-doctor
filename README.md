# Neovim Python Doctor

Display diagnostic information about your Python installations and how they are
viewed by Neovim.

## Usage

**Note**: `nvim` will be executed using your current configurations

Download and run `nvim-python-doctor.sh`

or run via curl:

```shell
curl -fsSL https://raw.githubusercontent.com/tweekmonster/nvim-python-doctor/master/nvim-python-doctor.sh | bash
```

## Example Output:

```shell
Include the output below this line in your Github issues.


## Neovim Python Diagnostic

- Neovim Version: NVIM 0.1.4-dev
- `pyenv` is available
  - system (set by /home/tallen/.pyenv/version)

## Python versions visible to Neovim

### 'python' info from /usr/bin/nvim

**Config**: `let g:python_host_prog = '/home/tallen/.pyenv/versions/neovim2/bin/python'`
**Python Version**: `Python 2.7.11`
**Neovim Package Version**: `neovim (0.1.7)`

### 'python3' info from /usr/bin/nvim

**Config**: `let g:python3_host_prog = '/home/tallen/.pyenv/versions/neovim3/bin/python'`
**Python Version**: `Python 3.4.4`
**Neovim Package Version**: `neovim (0.1.7)`

## Python versions visible in the current shell

- **python** version: `Python 2.7.6`
  - **neovim** version: `Not installed`
- **python3** version: `Python 3.4.3`
  - **neovim** version: `Not installed`
```
