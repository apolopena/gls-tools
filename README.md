# gls-tools  💻
Bash scripted command line tools for updating, installing, uninstalling and testing [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)

All `gls-tools` scripts should be executed through bash via a `curl` process substitution.

NONE OF THESE TOOLS ARE READY FOR PUBLIC USE. THIS LINE WILL BE REMOVED PRIOR TO THE INITIAL RELEASE.

If you would like to use `wget` or `fetch` to execute `gls-tools` scripts you can but the implemenation for that is for that is left up to you.
#### Note: _Bash 4.0 or higher is required._ If you run these scripts outside of Gitpod and you are using a mac you will need to [update your version of bash](https://clubmate.fi/upgrade-to-bash-4-in-mac-os-x)
<hr>

<br />

## Public tools
These scripts are for anyone to use. 

<br />

### 📜`tools/update.sh`
_Only use `tools/update.sh` on an empty project or a project built with Laravel._

<br />

> Interactively install the latest version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). If you have a Laravel project already built then this script will essentially 'Gitpodify` your current project.
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/install.sh ) 
 ```

 > Force install the latest version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). This is a good option when you want to install [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) into an empty project.
```bash
 yes | bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

> Interactively update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

 > Force update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) with minimal interactivity. Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`
```bash
 yes | bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-tools/main/tools/update.sh ) 
 ```

  > Generate a manifest for the latest version of  [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) for `install.sh` and `update.sh`
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