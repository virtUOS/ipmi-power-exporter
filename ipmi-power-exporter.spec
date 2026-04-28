Name:           ipmi-power-exporter
Version:        %{exporter_version}
Release:        1%{?dist}
Summary:        IPMI Power Metrics Exporter for S3 Storage

License:        MIT
URL:            https://github.com/virtUOS/ipmi-power-exporter
Source0:        %{url}/archive/refs/tags/%{version}.tar.gz

BuildArch:      noarch

# Runtime dependencies
Requires:       ipmitool
Requires:       openssl
Requires:       curl

BuildRequires:  tar
BuildRequires:  gzip

BuildRequires:     systemd
Requires(post):    systemd
Requires(preun):   systemd
Requires(postun):  systemd


%description
IPMI Power Exporter is a bash script that collects power metrics from IPMI
and uploads them to an S3-compatible storage endpoint. It uses ipmitool to
read FRU data and power readings, then uploads the metrics in Prometheus
format to a configured S3 bucket.

%prep
%autosetup -n %{version}

%build
# No build required for bash script

%install
# Create directories
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_sysconfdir}
mkdir -p %{buildroot}%{_unitdir}

# Install the main script
install -m 0755 %{name} %{buildroot}%{_bindir}/%{name}

# Install configuration file (example as .conf)
install -m 0644 %{name}.conf.example %{buildroot}%{_sysconfdir}/%{name}.conf

# Install systemd unit files
install -m 0644 %{name}.service %{buildroot}%{_unitdir}/%{name}.service
install -m 0644 %{name}.timer %{buildroot}%{_unitdir}/%{name}.timer

# Install license
mkdir -p %{buildroot}%{_datadir}/licenses/%{name}
install -m 0644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/LICENSE

%post
%systemd_post %{name}.service
%systemd_post %{name}.timer

%postun
%systemd_postun_with_restart %{name}.service
%systemd_postun_with_restart %{name}.timer

%preun
%systemd_preun %{name}.service
%systemd_preun %{name}.timer

%files
%{_bindir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}.conf
%{_unitdir}/%{name}.service
%{_unitdir}/%{name}.timer
%{_datadir}/licenses/%{name}/LICENSE

%changelog
* Mon Apr 28 2026 Lars Kiesow <lkiesow@uos.de> - 0.1-1
- Initial RPM package release
- Collects IPMI power metrics and uploads to S3 storage
- Includes systemd service and timer units
