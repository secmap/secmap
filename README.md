# SECMAP

## Installation

1. Install docker on your system.

2. Add your account to docker group.

3. Run the install script install.sh.

  ```bash
  $ ./install.sh
  ```

4. Copy and modified configuration file to fit your environment. Please read the comments for further helps.

  ```bash
  $ cp conf/secmap_conf.example.rb conf/secmap_conf.rb

  $ vim conf/secmap_conf.rb
  ```

5. Build redia/cassandra container.

  ```bash
  $ ./secmap.rb service RedisDocker pull
  $ ./secmap.rb service RedisDocker create

  $ ./secmap.rb service CassandraDocker pull
  $ ./secmap.rb service CassandraDocker create
  ```

## How to use

You can use the following commands to control secmap services on the nodes.

1. Start/stop/status the redia/cassandra service for the nodes.

  ```bash
  $ ./secmap.rb service RedisDocker start/stop/status

  $ ./secmap.rb service CassandraDocker start/stop/status
  ```

2. See more commands of redia/cassandra service.

  ```bash
  $ ./secmap.rb service RedisDocker list

  $ ./secmap.rb service CassandraDocker list
  ```

3. Set analyzer docker number.

  ```bash
  $ ./secmap.rb service Analyzer set <analyzer docker image name> <number>
  ```

4. Get existed analyzers.

  ```bash
  $ ./secmap.rb service Analyzer exist
  ```


5. See more command about redis/cassandra/pushtask client.

  ```bash
  $ ./secmap.rb client RedisCli/PushTask/CassandraCli list  
  ```

## Using ansible

Using ansible to control those services are also recommended.

You can use the following command to control secmap services.

```bash
$ ansible -i inventory <hosts> -m raw -a "cd <secmap home> && ./secmap.rb service <service name> <action>"
```

Hosts can be any group of following (see inventory file below for more details):

```conf
# inventory
[redis]
192.168.100.1  ansible_port=22  ansible_user=dsns
[noredis]
192.168.100.2  ansible_port=22  ansible_user=dsns
192.168.100.3  ansible_port=22  ansible_user=dsns
192.168.100.4  ansible_port=22  ansible_user=dsns
192.168.100.5  ansible_port=22  ansible_user=dsns
192.168.100.6  ansible_port=22  ansible_user=dsns
[seed]
192.168.100.1  ansible_port=22  ansible_user=dsns
192.168.100.3  ansible_port=22  ansible_user=dsns
[notseed]
192.168.100.2  ansible_port=22  ansible_user=dsns
192.168.100.4  ansible_port=22  ansible_user=dsns
192.168.100.5  ansible_port=22  ansible_user=dsns
192.168.100.6  ansible_port=22  ansible_user=dsns
```

Examples:

```bash
# Check the redis status
$ ansible -i inventory redis -m raw -a "cd secmap && ./secmap.rb service RedisDocker status"

# Pull the redis docker from docker hub
$ ansible -i inventory redis -m raw -a "cd secmap && ./secmap.rb service RedisDocker pull"

# Create the docker instance
$ ansible -i inventory redis -m raw -a "cd secmap && ./secmap.rb service RedisDocker create"

# Get the existed analyzer
$ ansible -i inventory all -m raw -a "cd secmap && ./secmap.rb service Analyzer exist"

# Check the Analyzer status of specific ip/nodes
$ ansible all -i 192.168.100.1, -m raw -a "cd secmap && ./secmap.rb service Analyzer exist"
$ ansible all -i 192.168.100.2,192.168.100.3 -m raw -a "cd secmap && ./secmap.rb service Analyzer exist"
```

See the [How to use](#how-to-use) for more details.

## Setup glusterfs for new environment

In the following example, we assume there are 3 nodes. (node1, node2, and node3)

1. Install glusterfs with ppa.
  ```bash
  $ sudo add-apt-repository ppa:semiosis/ubuntu-glusterfs-3.8
  $ sudo apt update
  $ sudo apt install glusterfs
  ```

2. Peer other nodes on one host. (Construct a cluster pool.)
  ```bash
  $ sudo gluster peer probe <hostname>
  ```

  Example:
  On __node1__:
  ```bash
  $ sudo gluster peer probe node2
  $ sudo gluster peer probe node3
  ```

3. Partition, format and mount the bricks.

  Example:
  On each nodes:
  ```bash
  $ sudo parted /dev/sdc
  $ sudo mkfs.xfs -i size=512 /dev/sdc1
  $ sudo mkdir -p /var/lib/brick1
  $ sudo echo '/dev/sdc1 /var/lib/brick1 xfs defaults 1 2' >> /etc/fstab
  $ sudo mount -a
  ```

4. Create volume folder.

  Example:
  On each nodes:
  ```bash
  $ sudo mkdir -p /var/lib/brick1/gv0
  ```

5. Create storage volume. (Refer official documents for details.)

  We use distributed stripe mode here.

  ```bash
  $ sudo gluster volume create <volume_name> <striped_count> transport tcp <hostname>:/path/to/data/directory
  ```

  Example:
  On __node1__:
  ```bash
  $ sudo gluster volume create test_vol stripe 3 transport tcp node2:/var/lib/brick1/gv0 node3:/var/lib/brick1/gv0
  ```

6. Start the volume.

  ```bash
  $ sudo gluster volume start <volume_name>
  ```

  Example:
  On __node1__:
  ```bash
  $ sudo gluster volume start test_vol
  ```

7. Mount the volume.

  Example:
  On any node:
  ```bash
  $ sudo mount -t glusterfs node1:/test_vol /mnt
  ```
