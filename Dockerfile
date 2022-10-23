# stable/Containerfile
#
# Build a Podman container image from the latest
# stable version of Podman on the Fedoras Updates System.
# https://bodhi.fedoraproject.org/updates/?search=podman
# This image can be used to create a secured container
# that runs safely with privileges within the container.
#
FROM registry.fedoraproject.org/fedora:latest

# Don't include container-selinux and remove
# directories used by dnf that are just taking
# up space.
# TODO: rpm --setcaps... needed due to Fedora (base) image builds
#       being (maybe still?) affected by
#       https://bugzilla.redhat.com/show_bug.cgi?id=1995337#c3
RUN dnf -y update && \
    rpm --setcaps shadow-utils 2>/dev/null && \
    dnf -y install podman git maven java-11-openjdk-devel.x86_64 buildah fuse-overlayfs \
        --exclude container-selinux && \
    dnf clean all && \
    rm -rf /var/cache /var/log/dnf* /var/log/yum.*
RUN export IMG_SHA256="cc9bf08794353ef57b400d32cd1065765253166b0a09fba360d927cfbd158088" && curl -fSL "https://github.com/genuinetools/img/releases/download/v0.5.11/img-linux-amd64" -o "/usr/local/bin/img" \
	&& echo "${IMG_SHA256}  /usr/local/bin/img" | sha256sum -c - \
	&& chmod a+x "/usr/local/bin/img"
RUN img -h
RUN useradd podman; \
echo -e "podman:1:999\npodman:1001:64535" > /etc/subuid; \
echo -e "podman:1:999\npodman:1001:64535" > /etc/subgid;

ARG _REPO_URL="https://raw.githubusercontent.com/containers/podman/main/contrib/podmanimage/stable"
ADD $_REPO_URL/containers.conf /etc/containers/containers.conf
ADD $_REPO_URL/podman-containers.conf /home/podman/.config/containers/containers.conf

RUN mkdir -p /home/podman/.local/share/containers && \
    chown podman:podman -R /home/podman && \
    usermod -G root podman && \
    chmod 644 /etc/containers/containers.conf

# Copy & modify the defaults to provide reference if runtime changes needed.
# Changes here are required for running with fuse-overlay storage inside container.
RUN sed -e 's|^#mount_program|mount_program|g' \
           -e '/additionalimage.*/a "/var/lib/shared",' \
           -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' \
           /usr/share/containers/storage.conf \
           > /etc/containers/storage.conf

# Note VOLUME options must always happen after the chown call above
# RUN commands can not modify existing volumes
VOLUME /var/lib/containers
VOLUME /home/podman/.local/share/containers

RUN mkdir -p /var/lib/shared/overlay-images \
             /var/lib/shared/overlay-layers \
             /var/lib/shared/vfs-images \
             /var/lib/shared/vfs-layers && \
    touch /var/lib/shared/overlay-images/images.lock && \
    touch /var/lib/shared/overlay-layers/layers.lock && \
    touch /var/lib/shared/vfs-images/images.lock && \
    touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

COPY /script.sh /home/podman/
RUN chmod +x /home/podman/script.sh && chgrp podman /home/podman/script.sh
RUN ln -s /usr/bin/buildah /usr/bin/docker
RUN chown podman:podman -R /home/podman/
USER podman
RUN mkdir /home/podman/.docker/
RUN echo -e "unqualified-search-registries = ['docker.io']" > /home/podman/.config/containers/registries.conf
#RUN mkdir $HOME/.docker/
RUN /home/podman/script.sh
COPY entrypoint.sh /entrypoint.sh
RUN echo -e '$REGISTRY_AUTH' > $HOME/.docker/config.json
WORKDIR /home/podman
ENTRYPOINT ["/entrypoint.sh"]
