# Installation Guide

This document provides step-by-step instructions for installing and running Open DQA.

---

## System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| Operating System | Windows 10, macOS 12, Ubuntu 20.04 | Ubuntu 22.04 LTS |
| RAM | 4 GB | 16 GB+ |
| CPU | 2-core, 1.8 GHz | 4-core, 2.5 GHz+ |
| Disk Space | 500 MB | 2 GB+ |
| Internet (install) | Required | Required |
| Internet (runtime) | Not required | Not required |

Open DQA operates entirely offline at runtime. Internet connectivity is required only during initial package installation and for optional FHIR server or SQL database connections to remote endpoints.

---

## Software Requirements

- **R** ≥ 4.2.0
- **RStudio** ≥ 2022.07 *(recommended)* or any R-compatible IDE

Open DQA does **not** require Pandoc, TinyTeX, or LaTeX. Reports are generated as Word (.docx) via the `officer` package.

---

## Installing R and RStudio

### Windows

1. Download R from [https://cran.r-project.org/bin/windows/base/](https://cran.r-project.org/bin/windows/base/).
2. Run the installer with default settings.
3. Download RStudio Desktop from [https://posit.co/download/rstudio-desktop/](https://posit.co/download/rstudio-desktop/).
4. Install RStudio.

### macOS

```bash
brew install --cask r
brew install --cask rstudio
```

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran42/"
sudo apt-get update
sudo apt-get install -y r-base r-base-dev

# System libraries required by R packages
sudo apt-get install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev
```

---

## Cloning the Repository

```bash
git clone https://github.com/gkamdje/OpenDQA.git
cd OpenDQA
```

Or download as ZIP from the GitHub page.

---

## Installing R Package Dependencies

### Automatic Installation (Recommended)

```bash
Rscript install_dependencies.R
```

This installs all 16 core packages and 5 optional packages. Estimated time: 5–15 minutes on first run.

### Manual Installation

```r
pkgs <- c(
  "shiny", "bs4Dash", "DT", "readxl", "jsonlite", "stringr", "dplyr",
  "lubridate", "rlang", "data.table", "shinyjs", "shinyWidgets", "waiter",
  "officer", "flextable", "plogr", "cluster", "emayili", "DBI", "RPostgres"
)
install.packages(pkgs, dependencies = TRUE)
```

---

## Launching the Application

### From RStudio

1. Open `app.R` in RStudio.
2. Click the **Run App** button.

### From R Console

```r
shiny::runApp("app.R", launch.browser = TRUE)
```

### From Terminal

```bash
Rscript -e "shiny::runApp('app.R', host='127.0.0.1', port=3838, launch.browser=TRUE)"
```

---

## Configuration

Review and edit `config/settings.yml` before first use. See [README.md](../README.md#configuration) for details.

---

## Verifying the Installation

Upload the included test dataset `data/Test_Data.csv` through the application and verify that all 77 checks execute correctly.

---

## Server Deployment (Shiny Server)

```bash
# Install Shiny Server
sudo apt-get install -y gdebi-core
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb
sudo gdebi shiny-server-1.5.21.1012-amd64.deb

# Deploy OpenDQA
sudo cp -r /path/to/OpenDQA /srv/shiny-server/opendqa
sudo chown -R shiny:shiny /srv/shiny-server/opendqa

# Install dependencies as shiny user
sudo su - shiny -s /bin/bash -c "Rscript /srv/shiny-server/opendqa/install_dependencies.R"

# Start Shiny Server
sudo systemctl start shiny-server
sudo systemctl enable shiny-server
```

Application accessible at `http://your-server-ip:3838/opendqa`.

---

## Troubleshooting

### Package Installation Failures

```r
install.packages("problematic_package", type = "source")
update.packages(ask = FALSE)
```

### Application Loads but Shows Blank Screen

- Clear browser cache and reload (`Ctrl+Shift+R`).
- Try a different browser (Chrome or Firefox recommended).
- Check the R console for error messages.

### Memory Issues with Large Datasets

Open DQA supports files up to 2 GB. For very large datasets, ensure at least 16 GB of RAM is available.
