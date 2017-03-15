#!/bin/bash

sed -i "/^FROM/ a\
RUN echo 'Acquire::http::Proxy \"http://172.17.0.1:8118\";' >> /etc/apt/apt.conf " Dockerfile
sed -i "/^ENV LVM2_VERSION/ i\
RUN git config --global http.proxy \"http://172.17.0.1:8118\"" Dockerfile

sed -i "/^ENV LVM2_VERSION/ i\
RUN git config --global https.proxy \"http://172.17.0.1:8118\"" Dockerfile

sed -i "/^ENV LVM2_VERSION/,$ s+curl+curl --proxy http://172.17.0.1:8118/+" Dockerfile

sed -i "/^usage()/,$ s+curl+curl --proxy http://172.17.0.1:8118/+" contrib/download-frozen-image-v2.sh
