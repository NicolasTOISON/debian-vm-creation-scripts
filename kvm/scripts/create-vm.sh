#!/bin/bash
#script to create a debian 10.6.0 vm without to type the virt install command

echo "Name of the VM :"
read name
echo "Amount of ram :"
read ram
echo "Number of CPU :"
read proc

sudo virt-install --name ${name} \
		--vcpus ${proc} \
			--memory ${ram} \
				--os-type linux \
					--os-variant debian10 \
						--network network=default \
							--location=/kvm/iso/debian-10.6.0 \
								--graphics none \
									--extra-args "console=tty0 console=ttyS0,115200n8" \
										--disk path=/kvm/disk/${name}.img,size=10,format=qcow2 \
											--noautoconsole \
												--virt-type kvm \
													-v
