# 💻 gls-tools
## Bash scripted command line tools for updating, installing, uninstalling and testing [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)

NONE OF THESE TOOLS ARE READY FOR PRODUCION USE. THIS LINE WILL BE REMOVED PRIOR TO THE FIRST STABLE RELEASE.

#### Note: _Bash 4.0 or higher is required. If you run these scripts outside of Gitpod and you are using a mac you will need to [update your version of bash](https://clubmate.fi/upgrade-to-bash-4-in-mac-os-x)_
<hr>

<br />

## ⚡ Install `gls`
You can install `gls` to `/usr/local/bin` which is a tool that runs all the non internal `gls-tools` scripts locally on the filesystem and is complete with `--help`, `--version` and command information. 
`gls` must be installed as root since it installs to your `/usr/local/bin`. This is safe as any installer and perhaps more safe than binary installers since all the code in this repository encapsualtes it's code into functions and is transparent open source. Please feel free to inspect all the code in this repository. Contributions and suggestions are always welcome.
```bash
curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/setup/install-gls.sh | sudo bash
```
## Using `gls-tools` individually
Most of the operations these scripts perform are one time tasks they are best done remotely using `curl` `wget` or `fetch` however these tool scripts can also be put into your `/usr/loca/bin` if you find yourself using them often.

If you would like to use `wget` or `fetch` to execute `gls-tools` tool scripts you can but the implemenation for that is for that is left up to you. `curl` commands are provided in the section for each script.

<br />

### 📜`tools/install.sh`
_Only use `tools/install.sh` on an empty project or an existing project built with Laravel._

> Interactively install the latest version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). If you have a Laravel project already built then this script will essentially 'Gitpodify` your current project.
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/install.sh ) 
 ```

 > Force install the latest version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). This is a good option when you want to install [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) into an empty project.
```bash
 yes | bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

### 📜`tools/update.sh`
_Only use `tools/update.sh` with an existing project built on a previous version `gitpod-laravel-starter`._

> Interactively update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

 > Force update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) with minimal interactivity. Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`
```bash
 yes | bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

  > Force update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) to overwrite all files by skipping all recommended backups. Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`
```bash
 yes n | bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

### 📜`tools/manifest.sh`

  > Generate a manifest for the latest version of  [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). A manifest can be used to control which files are kept and recommended for backup . This is currently only semi-functional.
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/manifest.sh ) 
 ```
<br />

## Internal tools
These scripts are generally used for internal purposes and testing but you are welcome to use them.

<br />

### 📜`tools/internal/blackbox.sh`
> List all [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) release versions 
```bash
 bash \
 <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/internal/blackbox.sh ) \
 gls version-list
 ```

 > Install the latest release version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
```bash
 bash \
 <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/internal/blackbox.sh ) \
 gls install-latest
 ```

> Install any release version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
```bash
 bash \
 <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/internal/blackbox.sh ) \
 gls install 1.4.0
 ```

 > Create a sandbox to test with by installing any release version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) into a directory called `sandbox`.
```bash
 bash \
 <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/internal/blackbox.sh ) \
 gls new sandbox 1.4.0
 ```
 
 > Create a 'double sandbox' to test with by installing any release version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) into a directory named `sandbox` and any release version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) into a directory called `control_sandbox_vX.X.X` where `X.X.X` is the second version number argument.
```bash
 bash \
 <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/internal/blackbox.sh ) \
 gls new double-sandbox 1.4.0 1.5.0
 ```