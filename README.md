# Fan management script for HP Microserver Gen 8

Provides an automated fan speed control of the only one fan in
HP Microserver Gen8 based on operating temperature of HDD and CPU.

You must run a modified ILO 4 with accessible `fan` command in order to use this script.
(see [Acknowledgements](#acknowledgements) section)

## Prerequisites

### Create a separate user in iLO

Login to iLO > Administration (tab) > User Administration.
Create a new user.  
Remove the following (all) 5 permissions. They are not needed:

- Administer User Accounts
- Remote Console Access
- Virtual Power and Reset
- Virtual Media
- Configure iLO Settings

### Authentication

#### Key

You must need an RSA key. Be aware that this command will overwrite your current key, if exists

```shell
ssh-keygen -t rsa -b 2048
```

Make sure it's called `id_rsa` and located in `$HOME/.ssh` of the user used to run the service

In iLO web interface go to Administration->Security choose a user, click Authorize new Key and paste your public key

You can usually obtain it like this

```shell
cat .ssh/id_rsa.pub
```

#### Password

If you are going to use password-based auth, then you must have sshpass installed.  
For deb-based distributions run

```shell
apt install sshpass
```

## Setup

Download repository

```shell
git clone https://github.com/fed1337/ilo4_fan_management.git
cd ilo4_fan_management
```

Consult comments in the config file for a setup

```shell
nano ilo4_fan_manager.conf
```

Open systemd service file and make sure to set `Environment` variables.

```shell
nano ilo4_fan_manager.service
```

You can install it as a systemd service via an installation script

```shell
chmod +x install.sh
sudo ./install.sh
```

or manually

## Troubleshooting

### It seems like fan speed ignoring temperature sensors

Please inspect the script code, specifically how temperatures are grep'ed. Your sensors may be called differently.
Those are `HDD*` and `CPU*` variables

Another idea is that you may want a more/less aggressive fan curve. Study how `HDD_PERC` and `CPU_PERC` variables are
set.

### iLO shell does not provide output

i.e. `fan info` does not provide any output

**"Solution"**  
Only the first login can see any responses.
Reset iLO (iLO > Info > Diagnostics) each time in order to see the responses.  
This is a firmware bug

## Acknowledgements

It couldn't be possible to sleep at nights with this server in the same room without these talented people

- [Original post with modified firmware](https://www.reddit.com/r/homelab/comments/hix44v/silence_of_the_fans_pt_2_hp_ilo_4_273_now_with/)
- [An updated firmware & documented research](https://github.com/kendallgoto/ilo4_unlock/tree/main)
- [Forum topic with an example script](https://forums.unraid.net/topic/141249-how-to-control-hpe-ilo-fan-speed-ilo-4-gen-8~9/)
