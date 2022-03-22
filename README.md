# gls-tools  💻
Bash scripted command line tools for updating, installing, uninstalling and testing [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
#### Note: _Bash 4.0 or higher is required._ If you are using a mac you will need to [update your version of bash](https://clubmate.fi/upgrade-to-bash-4-in-mac-os-x)
<hr>

<br />

## The tools and how to use them

<br />

### 📜`tools/update.sh`


> Update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter). Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/update.sh ) 
 ```
<br />

### 📜`tools/internal/blackbox.sh`
> List all [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) versions 
```bash
 bash \
 <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/internal/blackbox.sh ) \
 gls version-list
 ```
 > Install the latest version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/blackbox.sh ) gls install-latest
 ```
> Install any version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
```bash
 bash <( curl -fsSL https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/blackbox.sh ) gls install 1.4.0
 ```