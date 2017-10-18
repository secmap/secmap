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

5. Build redia container.

  ```bash
  $ ./secmap.rb service RedisDocker pull
  $ ./secmap.rb service RedisDocker create
  ```

## How to use

You can use the following commands to control secmap services on the nodes.

1. Start/stop/status the redia service for the nodes.

  ```bash
  $ ./secmap.rb service RedisDocker start/stop/status
  ```

2. See more commands of redia service.

  ```bash
  $ ./secmap.rb service RedisDocker list
  ```

3. Set analyzer docker number.

  ```bash
  $ ./secmap.rb service Analyzer set <analyzer docker image name> <number>
  ```

4. Get existed analyzers.

  ```bash
  $ ./secmap.rb service Analyzer exist
  ```


5. See more command about redis/pushtask client.

  ```bash
  $ ./secmap.rb client RedisCli/PushTask list  
  ```

