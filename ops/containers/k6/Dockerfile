FROM grafana/k6

# https://github.com/grafana/k6/issues/5120
# RUN dnf install -y \
#     golang \
#     git
# RUN dnf install -y https://dl.k6.io/rpm/repo.rpm
# RUN dnf install -y --nogpgcheck k6
# RUN dnf install -y https://github.com/grafana/k6/releases/download/v2.3.0/k6-v2.3.0-linux-amd64.rpm

COPY scripts /scripts

CMD [ "k6", "run", "10k.js" ]