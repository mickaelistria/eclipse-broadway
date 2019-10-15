FROM fedora:31
RUN dnf -y update && dnf -y install \
      dbus dbus-daemon dbus-glib \
      xorg-x11-server-utils \
      webkit2gtk3 webkit2gtk3-devel \
      mesa-libGL \
      adobe-source-code-pro-fonts abattis-cantarell-fonts \
      gnome-settings-daemon \
      wget tar \
      java-11-openjdk \
      && dnf clean all

# Build gtk from source to get patch for https://gitlab.gnome.org/GNOME/gtk/issues/2119 (not yet in Fedora 31)
# Once recent enough version of GTK is available in Fedora, replace all that by just adding `gtk3` to above dnf command
RUN dnf -y update && dnf -y install \
      gtk-doc cairo-gobject-devel libepoxy-devel atk-devel at-spi2-atk-devel gobject-introspection-devel \
      gettext-devel pango-devel fribidi-devel gdk-pixbuf2-devel file make diffutils patch xz \
      && dnf clean all
COPY gtk_broadway_selection.issue1630.patch /root
RUN cd /root && \
	wget -O- https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.12.tar.xz | xz -d | tar -x  && \
	cd gtk+-3.24.12/ && \
	patch -p1 -i /root/gtk_broadway_selection.issue1630.patch && \
	echo pwd=$(pwd) && \
	echo shell=$SHELL && \
	ls . && \
	echo "configure..." && \
	$(pwd)/configure --enable-broadway-backend --enable-x11-backend --enable-introspection --disable-gtk-doc --disable-cups --disable-papi --disable-xinerama --disable-xkb --prefix=/opt/gtk && \
	make && \
	make install && \
	cp -rf /opt/gtk/share/glib-2.0/schemas/* /usr/share/glib-2.0/schemas/ && \
	cd .. && \
	rm -r gtk+-3.24.12 
RUN dnf -y remove \
      gtk-doc cairo-gobject-devel libepoxy-devel atk-devel at-spi2-atk-devel gobject-introspection-devel \
      gettext-devel pango-devel fribidi-devel gdk-pixbuf2-devel file make diffutils xz \
      && dnf clean all
ENV LD_LIBRARY_PATH=/opt/gtk/lib
ENV PATH="/opt/gtk/bin:$PATH"

# Configure broadway
ENV BROADWAY_DISPLAY=:5
ENV BROADWAY_PORT=5000
EXPOSE 5000
ENV GDK_BACKEND=broadway

# Get Eclipse IDE
RUN echo "Downloading Eclipse" && \
    cd /root && \
    wget -O- "http://ftp.osuosl.org/pub/eclipse/technology/epp/downloads/release/2019-09/R/eclipse-java-2019-09-R-linux-gtk-x86_64.tar.gz" | tar xz && \
    cd eclipse/ && \
    echo $'name=Eclipse IDE\n\
id=org.eclipse.ui.ide.workbench\n\
version=4.13.0' > .eclipseproduct

# Prepare project area
RUN mkdir /projects
VOLUME /projects

RUN for f in "/etc" "/var/run" "/projects" "/root"; do \
    	chgrp -R 0 ${f} && \
    	chmod -R g+rwX ${f}; \
    done

COPY .fonts.conf /root/
COPY .fonts.conf /

#Useful for debug
#RUN dnf -y install gdb gdb-gdbserver java-11-openjdk-devel

COPY ./init.sh /
ENTRYPOINT [ "/init.sh" ]
