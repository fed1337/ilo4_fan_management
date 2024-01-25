# Fan management script for HP Microserver Gen 8

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
#### Keys
You must need an RSA key. Be aware that this command will overwrite your current key, if exists
```shell
ssh-keygen -t rsa -b 2048
```

In iLO web interface go to Administration->Security choose a user, click Authorize new Key and paste your public key

You can usually obtain it like this
```shell
cat .ssh/id_rsa.pub
```

#### Password in config file
If you are going to use password-based auth, then you must have sshpass installed
For deb based distributions
```shell
`apt install sshpass
```


## Setup
Download repository
```shell
git clone https://github.com/fed1337/ilo4_fan_management.git
```

Make sure that the script is executable and config is readable. Make changes if necessary
```shell
ls -lh ilo4_fan_management
chmod 777 ilo4_fan_management/fanmgmt.sh
chmod 444 ilo4_fan_management/fanmgmt.conf
```
Consult comments in the config file for a setup
```shell
nano ilo4_fan_management/fanmgmt.conf
```


## Running the script

### Cron
```shell
crontab -e
```
Add a line (**change the script path**) and save (ctrl+w for nano)
```shell
* * * * * * /home/fed/ilo4_fan_management/fanmgmt.sh
```
This task is scheduled every minute

### Systemd service
Adjust path in fanmgmt.service then copy it to systemd
```shell
sudo cp ilo4_fan_management/fanmgmt.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl start fanmgmt
sudo systemctl status fanmgmt
```

## Troubleshooting
### Seems like fan speed ignoring temperature sensors
Please inspect the script code, specifically how temperatures are grep'ed. Your sensors may be called differently.
Those are `HDD*` and `CPU*` variables

Another idea is that you may want a more/less aggressive fan curve. Study how `HDD_PERC` and `CPU_PERC` variables are set.


### iLO shell does not provide output
i.e. `fan info` does not provide any output

**"Solution"**  
Only first login can see any responses.
Reset iLO (iLO > Info > Diagnostics) each time in order to see the responses.  
This is a firmware bug


## Acknowledgements
It couldn't be possible to sleep at nights with this server in the same room without these talented people
- [Original post with modified firmware](https://www.reddit.com/r/homelab/comments/hix44v/silence_of_the_fans_pt_2_hp_ilo_4_273_now_with/)
- [An updated firmware & documented research](https://github.com/kendallgoto/ilo4_unlock/tree/main)
- [Forum topic with an example script](https://forums.unraid.net/topic/141249-how-to-control-hpe-ilo-fan-speed-ilo-4-gen-8~9/)
