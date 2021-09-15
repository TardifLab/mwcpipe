#apt-get install -y apt-transport-https software-properties-common build-essential 
#sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list'
#gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
#gpg -a --export E084DAB9 | apt-key add -
#add-apt-repository -r 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' -y
#apt-get install -y apt-transport-https software-properties-common build-essential 
# apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
# add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/'
# apt-get update -y
# apt-get -y install r-base libapparmor1 libcurl4-gnutls-dev libxml2-dev libssl-dev gdebi-core libcairo2-dev libxt-dev

su - -c "R -e \"install.packages('versions')\""
su - -c "R -e \"require(versions) | install.versions('plotly', '4.9.2.1')\""
su - -c "R -e \"require(versions) | install.versions('viridis', '0.5.1')\""
su - -c "R -e \"require(versions) | install.versions('viridisLite', '0.3.0')\""
su - -c "R -e \"require(versions) | install.versions('tidyr', '1.1.2')\""
su - -c "R -e \"require(versions) | install.versions('ggplot2', '3.3.2')\""
su - -c "R -e \"require(versions) | install.versions('scales', '1.1.1')\""
su - -c "R -e \"require(versions) | install.versions('randomForest', '4.6-14')\""
su - -c "R -e \"require(versions) | install.versions('e1071', '1.7-4')\""
su - -c "R -e \"require(versions) | install.versions('party', '1.3-5')\""
su - -c "R -e \"require(versions) | install.versions('strucchange', '1.5-2')\""
su - -c "R -e \"require(versions) | install.versions('sandwich', '2.5-1')\""
su - -c "R -e \"require(versions) | install.versions('zoo', '1.8-7')\""
su - -c "R -e \"require(versions) | install.versions('modeltools', '0.2-23')\""
su - -c "R -e \"require(versions) | install.versions('mvtnorm', '1.1-1')\""
su - -c "R -e \"require(versions) | install.versions('class', '7.3-17')\""
su - -c "R -e \"require(versions) | install.versions('ROCR', '1.0-11')\""
su - -c "R -e \"require(versions) | install.versions('kernlab', '0.9-29')\""
su - -c "R -e \"require(versions) | install.versions('tidyselect', '1.1.0')\""
su - -c "R -e \"require(versions) | install.versions('coin', '1.3-1')\""
su - -c "R -e \"require(versions) | install.versions('purrr', '0.3.4')\""
su - -c "R -e \"require(versions) | install.versions('splines', '3.6.3')\""
su - -c "R -e \"require(versions) | install.versions('lattice', '0.20-41')\""
su - -c "R -e \"require(versions) | install.versions('colorspace', '1.4-1')\""
su - -c "R -e \"require(versions) | install.versions('vctrs', '0.3.5')\""
su - -c "R -e \"require(versions) | install.versions('generics', '0.0.2')\""
su - -c "R -e \"require(versions) | install.versions('htmltools', '0.4.0')\""
su - -c "R -e \"require(versions) | install.versions('survival', '3.1-12')\""
su - -c "R -e \"require(versions) | install.versions('rlang', '0.4.9')\""
su - -c "R -e \"require(versions) | install.versions('pillar', '1.4.3')\""
su - -c "R -e \"require(versions) | install.versions('glue', '1.4.2')\""
su - -c "R -e \"require(versions) | install.versions('withr', '2.3.0')\""
su - -c "R -e \"require(versions) | install.versions('matrixStats', '0.56.0')\""
su - -c "R -e \"require(versions) | install.versions('multcomp', '1.4-13')\""
su - -c "R -e \"require(versions) | install.versions('lifecycle', '0.2.0')\""
su - -c "R -e \"require(versions) | install.versions('munsell', '0.5.0')\""
su - -c "R -e \"require(versions) | install.versions('gtable', '0.3.0')\""
su - -c "R -e \"require(versions) | install.versions('htmlwidgets', '1.5.1')\""
su - -c "R -e \"require(versions) | install.versions('codetools', '0.2-16')\""
su - -c "R -e \"require(versions) | install.versions('parallel', '3.6.3')\""
su - -c "R -e \"require(versions) | install.versions('TH.data', '1.0-10')\""
su - -c "R -e \"require(versions) | install.versions('Rcpp', '1.0.5')\""
su - -c "R -e \"require(versions) | install.versions('jsonlite', '1.6.1')\""
su - -c "R -e \"require(versions) | install.versions('gridExtra', '2.3')\""
su - -c "R -e \"require(versions) | install.versions('digest', '0.6.27')\""
su - -c "R -e \"require(versions) | install.versions('dplyr', '1.0.2')\""
su - -c "R -e \"require(versions) | install.versions('tools', '3.6.3')\""
su - -c "R -e \"require(versions) | install.versions('magrittr', '2.0.1')\""
su - -c "R -e \"require(versions) | install.versions('lazyeval', '0.2.2')\""
su - -c "R -e \"require(versions) | install.versions('tibble', '3.0.4')\""
su - -c "R -e \"require(versions) | install.versions('crayon', '1.3.4')\""
su - -c "R -e \"require(versions) | install.versions('pkgconfig', '2.0.3')\""
su - -c "R -e \"require(versions) | install.versions('MASS', '7.3-51.5')\""
su - -c "R -e \"require(versions) | install.versions('ellipsis', '0.3.0')\""
su - -c "R -e \"require(versions) | install.versions('libcoin', 'libcoin')\""
su - -c "R -e \"require(versions) | install.versions('Matrix', '1.2-18')\""
su - -c "R -e \"require(versions) | install.versions('data.table', '1.12.8')\""
su - -c "R -e \"require(versions) | install.versions('httr', '1.4.1')\""
su - -c "R -e \"require(versions) | install.versions('R6', '2.4.1')\""
su - -c "R -e \"require(versions) | install.versions('networkD3', '0.4')\""