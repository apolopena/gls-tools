# gls-tools  💻
Bash scripted command line tools for updating, installing, uninstalling and testing [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)

<hr>

<br />

## The tools and how to use them

<br />

### 📜`tools/update.sh`


> Update a project built with [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)

> Supports all versions of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) >= `0.0.4`

<br />

### 📜`tools/blackbox.sh`
> List all [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter) versions 
```bash
 bash <( curl -Ls https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/blackbox.sh ) gls version-list
 ```
 > Install the latest version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
```bash
 bash <( curl -Ls https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/blackbox.sh ) gls install-latest
 ```
> Install any version of [`gitpod-laravel-starter`](https://github.com/apolopena/gitpod-laravel-starter)
```bash
 bash <( curl -Ls https://raw.githubusercontent.com/apolopena/gls-updater/main/tools/blackbox.sh ) gls install 1.4.0
 ```