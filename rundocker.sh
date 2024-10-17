docker run --rm -it --privileged --sysctl net.ipv6.conf.lo.disable_ipv6=0 \
  -v $(pwd):/vyos -v /dev:/dev -v /etc/fstab:/etc/fstab \
  -w /vyos \
  vyos/vyos-build:current-arm64v8 bash -c "sudo sed -i 's|Defaults\s\+secure_path=\"\(.*\)\"|Defaults secure_path=\"\1:/opt/go/bin\"|' /etc/sudoers && /bin/bash"
