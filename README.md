# Fan management script for HP Microserver Gen 8

## Prerequisites

### Create a separate user in iLO
Login to iLO > Administration (tab) > User Administration.
Create a new user. **Remember this password!**  
Remove all 5 permissions. They are not needed, so uncheck the following:
- Administer User Accounts
- Remote Console Access
- Virtual Power and Reset
- Virtual Media
- Configure iLO Settings

### Authentication
There are two methods:

#### Keys
You can find guides all over. I ran into countless issues and threw my hands up in frustration, but it is the proper option.

#### Password in config file
This is the dummy method, and it's what I went with. Since we disabled all permissions for our new iLO user anyway, it was an acceptable risk.  
Install sshpass with `apt install sshpass` (for deb based distributions)


## Setup the script

### Download
```shell
git clone 
```

### Make sure that the script is executable and config is writable. Make changes if necessary
```shell
ls -lh fanmgmt
chmod 777 %repo_dir%/fanmgmt.sh
chmod 666 %repo_dir%/fanmgmt.conf
```

### Adjusting the config
```shell
nano %repo_dir%/fanmgmt.conf
```
adjust user, pass and host to match your iLO setup, then save. **Ensure to keep the quotes!**

### Setting up the cron task
```shell
crontab -e
```
Add a line (**change the script path**) and save (ctrl+w for nano)
```shell
* * * * * * /home/fed/fanmgmt/fanmgmt.sh
```
This task is scheduled every minute

## Editing the script & config
It's my first bash script, so I want to believe that it's pretty much self-explanatory. 

The script checks CPU and HDD temperatures (ones that are most accurate and the most I personally care about) and decides which `mode` to use. `mode` adjusts the speed of the only fan in this little server.

Modes from coldest to hottest:
- cold
- cool
- okay
- warm (not yet implemented)
- hot
- boil

You can adjust threshold temperatures for each `mode` separate for HDD and CPU (both cores and package) in the config file.

## Troubleshooting

### Temperature sensors are named differently
You can check that by looking at the log file (fanmgmt.log in the same directory with the script). You can run the script manually or wait a couple of minutes for cron to run the script in order for logs to appear

In this case you'll see lines like this, but with some values missing
```shell
2024-01-05 01:14:07 | CPU0: 32 | CPU1: 29 | CPU2: 37 | CPU3: 30 | CPU Package: 37 | HDD2: 35 | HDD3: 35 | HDD4: 34 | PREV_MODE: okay | CUR_MODE: okay
2024-01-05 01:15:06 | CPU0: 34 | CPU1: 32 | CPU2: 38 | CPU3: 30 | CPU Package: 38 | HDD2: 35 | HDD3: 35 | HDD4: 34 | PREV_MODE: okay | CUR_MODE: okay
```
In order to fix that you to change commands in the script (lines 13-21) accordingly. Just run them in your terminal and tweak as needed

### iLO shell does not give any output
i.e. `fan info` does not provide any output

**"Solution"**  
Only first login can see any responses.
Reset iLO (iLO > Info > Diagnostics) each time to view

## Thanks
